library(Holomics)
library(shiny)
env <- new.env(parent = asNamespace("Holomics"))
for (file in list.files("/opt/Holomics/R", full.names = TRUE, pattern = "\\.R$")) sys.source(file, env)
Sys.unsetenv("HOLOMICS_INPUT_DIR")
root <- "/opt/Holomics/inst/extdata/three-omics"
metadata <- env$galaxy_read_table(file.path(root, "metadata.tsv"))
base <- list(method = "Linear model", type = "continuous", formula = "~ Group + age + sex + batch",
  reference = list(Group = "Control"), coefficient = "GroupTreatment_A", min_prevalence = 0.1,
  alpha = 0.05, robust = FALSE, trend = FALSE, normalization = "TMM", size_factors = "ratio",
  maaslin_norm = "TSS", maaslin_transform = "LOG", standardize = TRUE, median_comparison = TRUE,
  pseudo_sens = TRUE, batch = "batch", parametric = TRUE, mean_only = FALSE)
cases <- list()
add <- function(type, method, ...) {
  settings <- modifyList(base, c(list(type = type, method = method), list(...)))
  cases[[length(cases) + 1L]] <<- settings
}
add("continuous", "Linear model")
for (robust in c(FALSE, TRUE)) for (trend in c(FALSE, TRUE)) add("continuous", "limma", robust = robust, trend = trend)
for (parametric in c(FALSE, TRUE)) for (mean_only in c(FALSE, TRUE))
  add("continuous", "ComBat", formula = "~ Group + age + sex", parametric = parametric, mean_only = mean_only)
for (sf in c("ratio", "poscounts", "iterate")) add("counts", "DESeq2", size_factors = sf)
for (normalization in c("TMM", "TMMwsp", "RLE", "upperquartile", "none")) for (robust in c(FALSE, TRUE))
  add("counts", "edgeR", normalization = normalization, robust = robust)
for (pseudo in c(FALSE, TRUE)) add("counts", "ANCOM-BC2", pseudo_sens = pseudo)
add("counts", "ComBat-seq", formula = "~ Group + age + sex")
for (type in c("counts", "relative")) for (norm in c("TSS", "NONE", "CLR")) for (transform in c("LOG", "NONE"))
  for (standardize in c(FALSE, TRUE)) for (median in c(FALSE, TRUE))
    add(type, "MaAsLin3", maaslin_norm = norm, maaslin_transform = transform, standardize = standardize, median_comparison = median)
dir.create("/opt/Holomics/tests/evidence", showWarnings = FALSE)
rows <- list()
for (i in seq_along(cases)) {
  settings <- cases[[i]]
  path <- if (settings$type == "continuous") file.path(root, "transcriptomics.tsv") else file.path(root, settings$type, "transcriptomics.tsv")
  X <- env$galaxy_read_table(path)
  start <- Sys.time()
  message("CASE ", i, "/", length(cases), " ", settings$type, " ", settings$method)
  error <- ""
  expected_validation <- identical(settings$maaslin_norm, "CLR") && identical(settings$maaslin_transform, "LOG") && settings$method == "MaAsLin3"
  fit <- tryCatch(env$da_run(X, metadata, settings), error = function(e) { error <<- conditionMessage(e); NULL })
  if (!is.null(fit)) {
    if (!length(fit$tables) || !any(vapply(fit$tables, nrow, integer(1)) > 0)) error <- "Empty results"
    saveRDS(fit, sprintf("/opt/Holomics/tests/evidence/da-%03d.rds", i))
  }
  status <- if (expected_validation) {
    if (grepl("Choose MaAsLin3 transformation NONE with CLR", error, fixed = TRUE)) "EXPECTED_VALIDATION" else "FAIL"
  } else if (nzchar(error)) "FAIL" else "PASS"
  rows[[i]] <- data.frame(case = i, type = settings$type, method = settings$method,
    settings = jsonlite::toJSON(settings, auto_unbox = TRUE), status = status,
    seconds = as.numeric(difftime(Sys.time(), start, units = "secs")), error = error)
  write.table(do.call(rbind, rows), "/opt/Holomics/tests/da-results.tsv", sep = "\t", row.names = FALSE, quote = TRUE)
  cat(rows[[i]]$status, error, "\n")
}
if (any(vapply(rows, function(x) x$status == "FAIL", logical(1)))) quit(status = 1)
