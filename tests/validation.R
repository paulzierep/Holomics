library(Holomics)
library(shiny)
env <- new.env(parent = asNamespace("Holomics"))
for (file in list.files("/opt/Holomics/R", full.names = TRUE, pattern = "\\.R$")) sys.source(file, env)
root <- "/opt/Holomics/inst/extdata/three-omics"
metadata <- env$galaxy_read_table(file.path(root, "metadata.tsv"))
X <- env$galaxy_read_table(file.path(root, "transcriptomics.tsv"))
expect_error <- function(label, code, pattern) {
  error <- tryCatch({force(code); ""}, error = function(e) conditionMessage(e))
  stopifnot(nzchar(error), grepl(pattern, error))
  cat("PASS validation", label, error, "\n")
}
expect_error("continuous declared counts", env$da_prepare(X, metadata, "~ Group", "counts"), "integer")
expect_error("continuous declared relative", env$da_prepare(X, metadata, "~ Group", "relative"), "fractions")
expect_error("missing samples", env$da_prepare(X[-1, ], metadata, "~ Group", "continuous"), "sample IDs")
bad <- metadata; bad$age[1] <- NA
expect_error("missing covariate", env$da_prepare(X, bad, "~ Group + age", "continuous"), "Missing")
bad <- metadata; bad$duplicate <- bad$age
expect_error("confounded design", env$da_prepare(X, bad, "~ age + duplicate", "continuous"), "rank-deficient")
expect_error("invalid reference", env$da_prepare(X, metadata, "~ Group", "continuous", list(Group = "unknown")), "reference")
expect_error("unsafe formula", env$da_prepare(X, metadata, "~ system('id')", "continuous"), "Unsupported")
for (type in c("continuous", "counts", "relative")) {
  blocks <- lapply(c("transcriptomics", "proteomics", "metabolomics"), function(name) {
    path <- if (type == "continuous") file.path(root, paste0(name, ".tsv")) else file.path(root, type, paste0(name, ".tsv"))
    x <- env$galaxy_read_table(path)
    stopifnot(nrow(x) == 36, setequal(rownames(x), rownames(metadata)))
    env$da_prepare(x, metadata, "~ Group + age + sex + batch", type)
    x
  })
  stopifnot(!identical(blocks[[1]], blocks[[2]]), !identical(blocks[[2]], blocks[[3]]))
  cat("PASS fixtures", type, "\n")
}
shiny::testServer(function(input, output, session) {
  single <- reactiveValues(data = list()); multi <- reactiveValues(data = list())
  labels <- reactiveValues(data = list()); multilabels <- reactiveValues(data = list())
  tables <- reactiveValues(data = NULL, classes = NULL)
  md <- reactiveValues(data = NULL, references = list())
  env$mod_Upload_server("upload", single, labels, multi, multilabels, tables, md)
}, {
  session$flushReact()
  for (button in c("all", "counts", "relative")) for (counter in 1:2) {
    session$setInputs(.list = NULL)
    do.call(session$setInputs, setNames(list(counter), paste0("upload-load_example_", button)))
    stopifnot(length(single$data) == nrow(tables$data), nrow(tables$classes) == 1L,
      "Metadata labels" %in% names(labels$data), !is.null(md$data))
  }
  cat("PASS repeated loader buttons: no duplicate blocks/labels\n")
})
