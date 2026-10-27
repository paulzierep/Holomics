/* Enlarge the original bound output so Shiny redraws, rather than stretching
 * a copy of its PNG. Moving it back preserves all existing plot/download IDs. */
(function () {
  "use strict";
  let active = null;

  function resized() {
    if (window.jQuery) window.jQuery(window).trigger("resize");
  }

  function closePlot() {
    if (!active) return;
    const { plot, marker, overlay, style, button, overflow } = active;
    marker.replaceWith(plot);
    if (style === null) plot.removeAttribute("style");
    else plot.setAttribute("style", style);
    overlay.remove();
    document.body.style.overflow = overflow;
    active = null;
    resized();
    button.focus();
  }

  function expandPlot(plot, button) {
    closePlot();
    const marker = document.createElement("span");
    plot.before(marker);
    const overlay = document.createElement("section");
    overlay.className = "holomics-plot-overlay";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.setAttribute("aria-label", "Expanded plot");
    overlay.innerHTML = '<div class="holomics-plot-toolbar">' +
      '<strong>Expanded plot</strong>' +
      '<label>Width <select class="holomics-plot-width">' +
      '<option value="100%">Fit window</option>' +
      '<option value="1000px">1000 px</option>' +
      '<option value="1400px">1400 px</option>' +
      '<option value="1800px">1800 px</option></select></label>' +
      '<label>Height <input class="holomics-plot-height" type="range" min="400" max="1600" step="100" value="800"> ' +
      '<output class="holomics-plot-height-value">800 px</output></label>' +
      '<button type="button" class="btn btn-secondary holomics-plot-close">Close (Esc)</button>' +
      '</div><div class="holomics-plot-canvas"></div>';
    active = { plot, marker, overlay, button, style: plot.getAttribute("style"),
      overflow: document.body.style.overflow };
    document.body.append(overlay);
    document.body.style.overflow = "hidden";
    overlay.querySelector(".holomics-plot-canvas").append(plot);
    const height = overlay.querySelector(".holomics-plot-height");
    const width = overlay.querySelector(".holomics-plot-width");
    function sizePlot() {
      plot.style.width = width.value;
      plot.style.height = height.value + "px";
      overlay.querySelector("output").textContent = height.value + " px";
      resized();
    }
    height.addEventListener("input", sizePlot);
    width.addEventListener("change", sizePlot);
    overlay.querySelector(".holomics-plot-close").addEventListener("click", closePlot);
    sizePlot();
    width.focus();
  }

  function addButtons() {
    document.querySelectorAll(".shiny-plot-output").forEach(function (plot) {
      if (plot.dataset.holomicsExpandable) return;
      plot.dataset.holomicsExpandable = "true";
      const button = document.createElement("button");
      button.type = "button";
      button.className = "btn btn-default btn-sm holomics-expand-plot";
      button.textContent = "Expand plot";
      button.setAttribute("aria-label", "Expand plot " + plot.id);
      button.addEventListener("click", function () { expandPlot(plot, button); });
      plot.before(button);
    });
  }

  document.addEventListener("keydown", function (event) {
    if (!active) return;
    if (event.key === "Escape") { event.preventDefault(); closePlot(); }
    if (event.key === "Tab") {
      const controls = active.overlay.querySelectorAll("select, input, button");
      const first = controls[0], last = controls[controls.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault(); last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault(); first.focus();
      }
    }
  });
  function start() {
    addButtons();
    new MutationObserver(addButtons).observe(document.body, { childList: true, subtree: true });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
