library(Holomics)
library(shiny)
env <- new.env(parent = asNamespace("Holomics"))
for (file in list.files("/opt/Holomics/R", full.names = TRUE, pattern = "\\.R$")) sys.source(file, env)
root <- "/opt/Holomics/inst/extdata/three-omics"
X <- as.matrix(env$galaxy_read_table(file.path(root, "transcriptomics.tsv")))
metadata <- env$galaxy_read_table(file.path(root, "metadata.tsv"))
labels <- data.frame(sample = rownames(metadata), Group = metadata$Group)
for (method in c("PCA", "PLSDA", "sPLS", "DIABLO")) {
  shiny::testServer(function(input, output, session) {
    data <- reactiveValues(data = list(X = list(omicsData = X, name = "X")))
    classes <- reactiveValues(data = list(labels = labels))
    selection <- reactiveValues(data = if (method == "DIABLO") list(X = X, Y = X + 1) else list(omicsData = X), dataX = X, dataY = X)
    class_selection <- reactiveValues(data = labels)
    active <- reactiveVal(FALSE)
    tuned <- reactiveValues(ncomp = 2)
    tables <- reactiveValues(data = env$initDataMatrix())
    switch(method,
      PCA = env$observe_pca_ui_components(session$ns, input, output, data, selection, classes, class_selection, reactive(NULL), active, tuned, data, tables),
      PLSDA = env$observe_plsda_ui_components(session$ns, input, output, data, selection, classes, class_selection, reactive(NULL), active, tuned, data, tables),
      sPLS = env$observe_spls_ui_components(session$ns, input, output, data, selection, classes, class_selection, reactive(NULL), active, tuned),
      DIABLO = env$observe_diablo_ui_components(session$ns, session, input, output, data, selection, classes, class_selection, reactive(NULL), active, tuned))
  }, {
    session$setInputs(ncomp = 2, scale = TRUE, matrix = 0.1, mode = "regression")
    active(TRUE)
    session$setInputs(scale = FALSE)
    stopifnot(!active())
    active(TRUE)
    class_selection$data <- transform(labels, Group = rev(Group))
    session$flushReact()
    stopifnot(!active())
    cat("PASS tuned-state invalidation", method, "scale and labels\n")
    active(TRUE)
    session$setInputs(ncomp = 1)
    stopifnot(!active())
    if (method == "sPLS") {
      active(TRUE)
      session$setInputs(mode = "canonical")
      stopifnot(!active())
    }
    if (method == "DIABLO") {
      active(TRUE)
      session$setInputs(matrix = 0.5)
      stopifnot(!active())
    }
    active(TRUE)
    if (method == "sPLS") selection$dataX <- X + 2
    else if (method == "DIABLO") selection$data <- list(X = X + 2, Y = X + 1)
    else selection$data <- list(omicsData = X + 2)
    session$flushReact()
    stopifnot(!active())
    cat("PASS tuned-state invalidation", method, "components, data and method settings\n")
  })
}
