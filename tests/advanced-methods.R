# Catalog-wide backend smoke coverage; not exhaustive UI/option acceptance.
library(Holomics)
env <- new.env(parent = asNamespace("Holomics"))
for (file in list.files("/opt/Holomics/R", full.names = TRUE, pattern = "\\.R$")) sys.source(file, env)
root <- "/opt/Holomics/inst/extdata/three-omics"
blocks <- lapply(c("transcriptomics", "proteomics"), function(name)
  as.matrix(env$galaxy_read_table(file.path(root, paste0(name, ".tsv")))))
names(blocks) <- c("transcripts", "proteins")
md <- env$galaxy_read_table(file.path(root, "metadata.tsv"))
labels <- data.frame(sample = rownames(md), group = md$Group)
# Synthetic stratified study membership tests API shape, NOT independent-cohort validity.
study <- data.frame(sample = rownames(md), study = ave(seq_len(nrow(md)), md$Group,
  FUN = function(x) rep(c("study1", "study2"), length.out = length(x))))
settings <- list(ncomp = 2, coupling = 0.1, design_json = "", keep_json = "",
  scheme = "horst", init = "svd", center = TRUE, scale = TRUE, max.iter = 500,
  tol = 1e-6, near.zero.var = FALSE, logratio = "none", ilr.offset = 0.001,
  mode = "regression", ica_mode = "deflation", ica_fun = "logcosh",
  rcc_method = "ridge", lambda1 = 0.1, lambda2 = 0.1, keepX = "5", keepY = "5", seed = 123)
results <- list()
for (method in env$advanced_methods()) {
  warnings <- character()
  error <- tryCatch(withCallingHandlers({
    pair <- method %in% c("pls", "spls", "rcc", "mint.pls", "mint.spls")
    selected <- if (pair || grepl("block", method)) blocks else blocks[1]
    data <- env$advanced_data(selected, labels, study)
    fit <- env$advanced_fit(method, data, settings)
    if (grepl("block", method) && !grepl("da$", method))
      stopifnot(identical(fit$parameters$indY, length(selected)))
    loadings <- env$advanced_loadings(fit)
    stopifnot(nrow(loadings) > 0, all(is.finite(loadings$loading)),
      max(loadings$component) >= 2, any(loadings$selected))
    path <- tempfile(fileext = ".rds")
    saveRDS(fit, path)
    stopifnot(identical(readRDS(path)$method, method))
    ""
  }, warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }),
    error = conditionMessage)
  results[[method]] <- data.frame(method = method, status = if (nzchar(error)) "FAIL" else "PASS",
    warnings = paste(unique(warnings), collapse = "; "), error = error)
  cat(results[[method]]$status, method, error, "\n")
}
table <- do.call(rbind, results)
write.table(table, "/opt/Holomics/tests/advanced-results.tsv", sep = "\t", row.names = FALSE)
if (any(table$status == "FAIL")) quit(status = 1)
