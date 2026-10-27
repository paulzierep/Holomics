"""Headless real-click smoke/matrix runner. Never opens a desktop browser."""
import json
import time
import os
from pathlib import Path
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait

ROOT = Path(__file__).resolve().parent
OUT = ROOT / os.getenv("BROWSER_EVIDENCE", "browser-evidence")
OUT.mkdir(exist_ok=True)
options = webdriver.ChromeOptions()
for arg in ("--headless", "--no-sandbox", "--disable-dev-shm-usage", "--window-size=1600,1200"):
    options.add_argument(arg)
options.set_capability("goog:loggingPrefs", {"browser": "ALL"})
downloads = OUT / "downloads"
downloads.mkdir(exist_ok=True)
options.add_experimental_option("prefs", {"download.default_directory": str(downloads), "download.prompt_for_download": False})
driver = webdriver.Chrome(options=options)
wait = WebDriverWait(driver, 600)
results = []
frames = OUT / "frames"
frames.mkdir(exist_ok=True)
frame_index = 0

def frame():
    global frame_index
    driver.save_screenshot(str(frames / f"{frame_index:06d}.png"))
    frame_index += 1

def idle():
    wait.until(lambda d: d.execute_script("return !!window.Shiny && !!Shiny.shinyapp && !!Shiny.shinyapp.$socket && Shiny.shinyapp.$socket.readyState===1"))
    time.sleep(0.8)
    wait.until(lambda d: "shiny-busy" not in d.find_element(By.TAG_NAME, "html").get_attribute("class"))
    frame()

def click(selector):
    elements = driver.find_elements(By.CSS_SELECTOR, selector)
    element = next(e for e in elements if e.is_displayed())
    driver.execute_script("arguments[0].scrollIntoView({block:'center'})", element)
    frame()
    element.click()
    idle()

def tab(name):
    # Expand the real sidebar menu where necessary.
    if name in ("PCA", "PLSDA"):
        anchor = driver.find_element(By.CSS_SELECTOR, 'a[data-value="singleOmics"]')
        if not driver.find_element(By.CSS_SELECTOR, f'a[data-value="{name}"]').is_displayed():
            anchor.click()
            time.sleep(0.5)
    click(f'a[data-value="{name}"]')

def select(id_, values):
    # Selectize's public UI API emits the same change events as a selection.
    driver.execute_script("""const e=document.getElementById(arguments[0]);
      if(e.selectize) e.selectize.setValue(arguments[1]);
      else {$(e).val(arguments[1]).trigger('change');}""", id_, values)
    idle()

def download(id_):
    before = {p: p.stat().st_mtime_ns for p in downloads.iterdir()}
    click(f'[id="{id_}"]')
    paths = wait.until(lambda d: [p for p in downloads.iterdir() if p.suffix != '.crdownload' and p.stat().st_mtime_ns != before.get(p)])
    assert all(p.stat().st_size > 100 for p in paths), "Empty download"

def plot_tab(route, title):
    anchor = next(e for e in driver.find_elements(By.CSS_SELECTOR, f'#shiny-tab-{route} a[data-toggle="tab"]') if e.is_displayed() and e.text == title)
    driver.execute_script("arguments[0].scrollIntoView({block:'center'})", anchor)
    anchor.click()
    idle()
    images = wait.until(lambda d: [e for e in d.find_elements(By.CSS_SELECTOR, f'#shiny-tab-{route} .shiny-plot-output img') if e.is_displayed()])
    assert all(driver.execute_script("return arguments[0].naturalWidth", e) > 0 for e in images)

def errors():
    return [e.text for e in driver.find_elements(By.CSS_SELECTOR, '.shiny-output-error, .shiny-notification-error') if e.is_displayed() and e.text.strip()]

def check(name, action):
    try:
        action()
        failure = errors()
        if failure:
            raise AssertionError("; ".join(failure))
        status, message = "PASS", ""
    except Exception as exc:
        status, message = "FAIL", str(exc)
    driver.save_screenshot(str(OUT / f"{len(results):03d}.png"))
    results.append(dict(case=name, status=status, error=message))
    (OUT / "results.json").write_text(json.dumps(results, indent=2))
    print(status, name, message, flush=True)

try:
    driver.get("http://localhost:8083")
    idle()
    # Inventory includes hidden controls and the active route, for explicit coverage.
    (OUT / "controls.json").write_text(json.dumps(driver.execute_script("""return Array.from(document.querySelectorAll('button,input,select,a.shiny-download-link')).map(e=>({id:e.id,text:e.innerText,type:e.type,route:e.closest('.tab-pane')?.id}));"""), indent=2))
    for type_, button in (("continuous", "all"), ("counts", "counts"), ("relative", "relative")):
        tab("upload")
        check(f"load {type_}", lambda: click(f"#upload-load_example_{button}"))
        check(f"reload {type_}", lambda: click(f"#upload-load_example_{button}"))
        tab("da")
        select("da-type", type_)
        select("da-block", f"Example_{type_}_transcriptomics")
        select("da-group", "Group")
        select("da-reference", "Control")
        select("da-covariates", ["age", "sex", "batch"])
        methods = {"continuous": ["Linear model", "limma"], "counts": ["DESeq2", "edgeR", "ANCOM-BC2"], "relative": ["MaAsLin3"]}[type_]
        for method in methods:
            select("da-method", method)
            def run():
                click("#da-run")
                text = driver.find_element(By.ID, "da-status").text
                assert "Completed" in text, text
                assert driver.find_element(By.ID, "da-results").text.strip(), "No result table"
            check(f"DA button {type_} {method}", run)
            check(f"DA download {type_} {method}", lambda: download("da-download"))
    tab("DIABLO")
    select("DIABLO-dataSelection", [f"Example_continuous_{b}" for b in ("transcriptomics", "proteomics", "metabolomics")])
    select("DIABLO-classSelection", "Metadata labels")
    for title in ("Sample plot", "Correlation circle plot", "CIM", "Loading plot", "Arrow plot", "Circos plot"):
        def plot_route(title=title):
            anchors = [e for e in driver.find_elements(By.CSS_SELECTOR, '#shiny-tab-DIABLO a[data-toggle="tab"]') if e.is_displayed() and title == e.text]
            assert anchors, f"No tab matching {title}"
            anchors[0].click()
            idle()
            visible = wait.until(lambda d: [e for e in d.find_elements(By.CSS_SELECTOR, '#shiny-tab-DIABLO .shiny-plot-output img') if e.is_displayed()])
            assert all(driver.execute_script("return arguments[0].naturalWidth", e) > 0 for e in visible)
        check(f"DIABLO {title}", plot_route)
    for route in ("PCA", "PLSDA", "sPLS", "DIABLO"):
        tab(route)
        if route in ("PCA", "PLSDA"):
            select(f"{route}-dataSelection", "Example_continuous_transcriptomics")
        elif route == "sPLS":
            select("sPLS-dataSelection1", "Example_continuous_transcriptomics")
            select("sPLS-dataSelection2", "Example_continuous_proteomics")
        select(f"{route}-classSelection", "Metadata labels")
        titles = ["Sample plot", "Correlation circle plot", "Loading plot"]
        if route in ("sPLS", "DIABLO"):
            titles.append("CIM")
        for title in titles:
            check(f"{route} original {title}", lambda r=route, t=title: plot_tab(r, t))
        if route in ("sPLS", "DIABLO"):
            for id_ in ("Img.download", "Img.table.download"):
                check(f"{route} {id_}", lambda r=route, i=id_: download(f"{r}-{i}"))
        check(f"{route} tune button", lambda r=route: click(f"#{r}-tune"))
        def tuned(r=route):
            text = driver.find_element(By.ID, f"{r}-ncomp.tuned").text
            assert any(c.isdigit() and c != "0" for c in text), text
        check(f"{route} tuned parameter", tuned)
        if route in ("sPLS", "DIABLO"):
            check(f"{route} tuning to CIM", lambda r=route: plot_tab(r, "CIM"))
            for id_ in ("Img.download.tuned", "Img.table.download.tuned"):
                check(f"{route} {id_}", lambda r=route, i=id_: download(f"{r}-{i}"))
    # Keep a snapshot of all currently rendered controls/errors for the next phase.
    (OUT / "browser-log.json").write_text(json.dumps(driver.get_log("browser"), indent=2))
finally:
    driver.quit()
if any(result["status"] == "FAIL" for result in results):
    raise SystemExit(1)
