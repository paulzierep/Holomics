"""Headless real-click smoke/matrix runner. Never opens a desktop browser."""
import json
import time
import os
import csv
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

def dismiss_notifications():
    for button in driver.find_elements(By.CSS_SELECTOR, '.shiny-notification-close'):
        if button.is_displayed():
            button.click()
    idle()

def tab(name):
    # Expand the real sidebar menu where necessary.
    if name in ("PCA", "PLSDA"):
        child = driver.find_element(By.CSS_SELECTOR, f'a[data-value="{name}"]')
        anchor = child.find_element(By.XPATH, './ancestor::ul[1]/preceding-sibling::a')
        if not child.is_displayed():
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
    dismiss_notifications()
    before = {p: p.stat().st_mtime_ns for p in downloads.iterdir()}
    click(f'[id="{id_}"]')
    paths = wait.until(lambda d: [p for p in downloads.iterdir() if p.suffix != '.crdownload' and p.stat().st_mtime_ns != before.get(p)])
    assert all(p.stat().st_size > 100 for p in paths), "Empty download"
    for path in paths:
        if path.suffix.lower() == '.png':
            assert path.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'), f"Invalid PNG: {path}"
        elif path.suffix.lower() == '.csv':
            with path.open() as stream:
                rows = list(csv.reader(stream, delimiter=';'))
            assert len(rows) > 1 and len(rows[0]) > 1, f"Invalid CSV: {path}"

def plot_tab(route, title, tuned=False):
    output_name = {"Sample plot": "Indiv", "Correlation circle plot": "Var", "Loading plot": "Load", "CIM": "Img", "Arrow plot": "Arrow", "Circos plot": "Circos"}[title]
    output_id = f"{route}-{output_name}" + (".tuned" if tuned else "")
    plot = driver.find_element(By.ID, output_id)
    pane = plot.find_element(By.XPATH, './ancestor::div[contains(concat(" ",normalize-space(@class)," ")," tab-pane ")][1]')
    anchor = next(e for e in driver.find_elements(By.CSS_SELECTOR, f'a[href="#{pane.get_attribute("id")}"]') if e.is_displayed())
    driver.execute_script("arguments[0].scrollIntoView({block:'center'})", anchor)
    anchor.click()
    idle()
    images = wait.until(lambda d: [e for e in d.find_element(By.ID, output_id).find_elements(By.TAG_NAME, 'img') if e.is_displayed() and d.execute_script("return arguments[0].naturalWidth > 0", e)])
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
        status, message = "FAIL", f"{type(exc).__name__}: {exc}"
        (OUT / f"{len(results):03d}-failure.html").write_text(driver.page_source)
    driver.save_screenshot(str(OUT / f"{len(results):03d}.png"))
    results.append(dict(case=name, status=status, error=message))
    (OUT / "results.json").write_text(json.dumps(results, indent=2))
    print(status, name, message, flush=True)

def advanced_campaign():
    driver.get("http://localhost:8083")
    idle()
    tab("upload")
    check("Advanced load continuous", lambda: click("#upload-load_example_all"))
    tab("advanced")
    methods = ("pca", "spca", "ipca", "sipca", "pls", "spls", "plsda", "splsda", "rcc",
               "block.pls", "block.spls", "block.plsda", "block.splsda")
    for method in methods:
        def fit(m=method):
            select("advanced-method", m)
            pair = m in ("pls", "spls", "rcc") or "block" in m
            blocks = ["Example_continuous_transcriptomics"]
            if pair:
                blocks.append("Example_continuous_proteomics")
            select("advanced-blocks", blocks)
            select("advanced-labels", "Metadata labels")
            click("#advanced-fit")
            text = driver.find_element(By.ID, "advanced-status").text
            assert f"Fitted {m} on" in text, text
        check(f"Advanced fit {method}", fit)
        plots = ["Scores", "Loadings", "Correlation circle"]
        if method in ("pls", "spls", "block.splsda"):
            plots.append("CIM heatmap")
        if method == "block.splsda":
            plots.extend(("DIABLO", "Circos"))
        for plot in plots:
            def render(p=plot):
                select("advanced-plot", p)
                wait.until(lambda d: any(e.is_displayed() and d.execute_script("return arguments[0].naturalWidth>0", e)
                    for e in d.find_element(By.ID, "advanced-figure").find_elements(By.TAG_NAME, "img")))
            check(f"Advanced {method} {plot}", render)
            check(f"Advanced {method} {plot} PDF", lambda: download("advanced-plot_pdf"))
        for id_ in ("feature_tsv", "model_rds"):
            check(f"Advanced {method} {id_}", lambda i=id_: download(f"advanced-{i}"))

if os.getenv("ADVANCED_ONLY") == "1":
    try:
        advanced_campaign()
    finally:
        (OUT / "browser-log.json").write_text(json.dumps(driver.get_log("browser"), indent=2))
        driver.quit()
    raise SystemExit(int(any(r["status"] == "FAIL" for r in results)))

try:
    driver.get("http://localhost:8083")
    idle()
    # Inventory includes hidden controls and the active route, for explicit coverage.
    (OUT / "controls.json").write_text(json.dumps(driver.execute_script("""return Array.from(document.querySelectorAll('button,input,select,a.shiny-download-link')).map(e=>({id:e.id,text:e.innerText,type:e.type,route:e.closest('.tab-pane')?.id}));"""), indent=2))
    tuning_only = os.getenv("TUNING_ONLY") == "1"
    for type_, button in (("continuous", "all"), ("counts", "counts"), ("relative", "relative")):
        if tuning_only and type_ != "continuous":
            continue
        tab("upload")
        check(f"load {type_}", lambda: click(f"#upload-load_example_{button}"))
        check(f"reload {type_}", lambda: click(f"#upload-load_example_{button}"))
        if tuning_only:
            continue
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
    for title in (() if tuning_only else ("Sample plot", "Correlation circle plot", "CIM", "Loading plot", "Arrow plot", "Circos plot")):
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
        elif route == "DIABLO":
            select("DIABLO-dataSelection", [f"Example_continuous_{b}" for b in ("transcriptomics", "proteomics", "metabolomics")])
        select(f"{route}-classSelection", "Metadata labels")
        def set_component_budget(r=route):
            element = driver.find_element(By.ID, f"{r}-ncomp")
            if not element.is_displayed():
                card = element.find_element(By.XPATH, './ancestor::div[contains(concat(" ",normalize-space(@class)," ")," card ")][1]')
                card.find_element(By.CSS_SELECTOR, '[data-card-widget="collapse"]').click()
                wait.until(lambda d: element.is_displayed())
            element.clear()
            element.send_keys("2")
            element.send_keys("\t")
            idle()
            received = driver.execute_script("const v=Shiny.shinyapp.$inputValues; const k=Object.keys(v).find(k=>k.split(':')[0]===arguments[0]); return v[k]", f"{r}-ncomp")
            assert received == 2, f"Shiny component value: {received!r}"
        check(f"{route} component budget 2", set_component_budget)
        titles = ["Sample plot", "Correlation circle plot", "Loading plot"]
        if route in ("sPLS", "DIABLO"):
            titles.append("CIM")
        for title in titles:
            check(f"{route} original {title}", lambda r=route, t=title: plot_tab(r, t))
        if route in ("sPLS", "DIABLO"):
            for id_ in ("Img.download", "Img.table.download"):
                check(f"{route} {id_}", lambda r=route, i=id_: download(f"{r}-{i}"))
        if route == "DIABLO":
            select("DIABLO-dataSelection", [f"Example_continuous_{b}" for b in ("transcriptomics", "proteomics", "metabolomics")])
        check(f"{route} tune button", lambda r=route: click(f"#{r}-tune"))
        def tuned(r=route):
            element = driver.find_element(By.ID, f"{r}-ncomp.tuned")
            if not element.is_displayed():
                card = element.find_element(By.XPATH, './ancestor::div[contains(concat(" ",normalize-space(@class)," ")," card ")][1]')
                card.find_element(By.CSS_SELECTOR, '[data-card-widget="collapse"]').click()
            text = wait.until(lambda d: element.text.strip())
            assert any(c.isdigit() and c != "0" for c in text), text
        check(f"{route} tuned parameter", tuned)
        dismiss_notifications()
        if route in ("PCA", "PLSDA"):
            for title in ("Sample plot", "Correlation circle plot", "Loading plot"):
                check(f"{route} tuned {title}", lambda r=route, t=title: plot_tab(r, t, tuned=True))
        if route in ("sPLS", "DIABLO"):
            check(f"{route} tuning to CIM", lambda r=route: plot_tab(r, "CIM", tuned=True))
            for id_ in ("Img.download.tuned", "Img.table.download.tuned"):
                check(f"{route} {id_}", lambda r=route, i=id_: download(f"{r}-{i}"))
    # Keep a snapshot of all currently rendered controls/errors for the next phase.
    (OUT / "browser-log.json").write_text(json.dumps(driver.get_log("browser"), indent=2))
finally:
    driver.quit()
if any(result["status"] == "FAIL" for result in results):
    raise SystemExit(1)
