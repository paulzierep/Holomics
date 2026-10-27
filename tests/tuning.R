library(Holomics)
library(shiny)
env <- new.env(parent = asNamespace("Holomics"))
for (file in list.files("/opt/Holomics/R", full.names = TRUE, pattern = "\\.R$")) sys.source(file, env)
root <- "/opt/Holomics/inst/extdata/three-omics"
X <- lapply(c("transcriptomics", "proteomics"), function(n) as.matrix(env$galaxy_read_table(file.path(root, paste0(n, ".tsv")))))
names(X) <- c("transcripts", "proteins")
md <- env$galaxy_read_table(file.path(root, "metadata.tsv"))
classes <- data.frame(sample = rownames(md), Group = md$Group)
method <- Sys.getenv("TEST_METHOD", "DIABLO")
shiny::testServer(function(input, output, session) {
  data <- reactiveValues(data = lapply(names(X), function(n) list(omicsData = X[[n]], name = n)))
  names(data$data) <- names(X)
  labels <- reactiveValues(data = list(labels = classes))
  tables <- reactiveValues(data = env$initDataMatrix())
  switch(method,
    DIABLO = env$mod_DIABLO_server("model", data, labels),
    sPLS = env$mod_sPLS_server("model", data, labels),
    PLSDA = env$mod_PLSDA_server("model", data, labels, data, tables),
    PCA = env$mod_PCA_server("model", data, labels, data, tables))
}, {
  # These are the actual module input IDs, not invented run buttons.
  session$setInputs(`model-dataSelection` = if (method %in% c("PCA", "PLSDA")) names(X)[1] else names(X), `model-classSelection` = "labels",
    `model-ncomp` = 2, `model-scale` = TRUE, `model-matrix` = 0.1,
    `model-mode` = "regression", `model-dataSelection1` = names(X)[1], `model-dataSelection2` = names(X)[2])
  session$setInputs(`model-tune` = 1)
  session$flushReact()
  value <- output$`model-ncomp.tuned`
  stopifnot(length(value) == 1, grepl("[1-9]", value))
  if (method %in% c("DIABLO", "sPLS")) {
    session$setInputs(`model-img.comp.tuned` = 1, `model-xmargin.tuned` = 5, `model-ymargin.tuned` = 5,
      `model-heatmap.rows.tuned` = FALSE, `model-heatmap.columns.tuned` = FALSE, `model-heatmap.transpose.tuned` = FALSE)
    image <- output$`model-Img.tuned`
    stopifnot(is.list(image), nzchar(image$src))
    cat("PASS actual tuned CIM render", method, "\n")
  }
  cat("TUNING RESULT", method, value, "\n")
})
