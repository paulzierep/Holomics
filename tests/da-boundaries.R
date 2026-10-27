library(Holomics)
env <- new.env(parent = asNamespace("Holomics"))
for (file in list.files("/opt/Holomics/R", full.names = TRUE, pattern = "\\.R$")) sys.source(file, env)
root <- "/opt/Holomics/inst/extdata/three-omics"
metadata <- env$galaxy_read_table(file.path(root, "metadata.tsv"))
X <- env$galaxy_read_table(file.path(root, "transcriptomics.tsv"))
base <- list(method = "Linear model", type = "continuous", formula = "~ Group + age + sex + batch",
  reference = list(Group = "Control"), coefficient = "GroupTreatment_A", min_prevalence = 0.1, alpha = 0.05)
for (prevalence in c(0, 1)) for (alpha in c(0.001, 1)) {
  settings <- modifyList(base, list(min_prevalence = prevalence, alpha = alpha))
  fit <- env$da_run(X, metadata, settings)
  stopifnot(nrow(fit$tables$results) == ncol(X), all(is.finite(fit$tables$results$effect)))
  cat("PASS numeric boundary", prevalence, alpha, "\n")
}
for (key in c("alpha", "min_prevalence")) for (value in c(-1, 2, NA, Inf)) {
  settings <- base; settings[[key]] <- value
  error <- tryCatch({env$da_run(X, metadata, settings); ""}, error = conditionMessage)
  stopifnot(grepl(if (key == "alpha") "FDR threshold" else "Prevalence", error))
  cat("PASS invalid boundary", key, value, "\n")
}
# Genuine repeated measures: 12 subjects, each measured three times. Add a
# deterministic subject effect so the random intercept is identifiable.
set.seed(72)
metadata$subject_id <- factor(rep(seq_len(12), each = 3))
subject_effect <- matrix(rnorm(12 * ncol(X), sd = 3), nrow = 12)
repeated <- X + subject_effect[as.integer(metadata$subject_id), ]
settings <- modifyList(base, list(method = "Mixed model", formula = "~ Group + age + sex + batch + (1 | subject_id)"))
fit <- env$da_run(repeated, metadata, settings)
stopifnot(nrow(fit$tables$results) == ncol(X), all(is.finite(fit$tables$results$effect)))
stopifnot(is.null(fit$tables$failures))
cat("PASS mixed model: 12 subjects x 3 observations, populated effects\n")
# Changing the reference must change the tested effect, not just its label.
a <- env$da_run(X, metadata, base)$tables$results
settings <- modifyList(base, list(reference = list(Group = "Treatment_A"), coefficient = "GroupControl"))
b <- env$da_run(X, metadata, settings)$tables$results
stopifnot(isTRUE(all.equal(a$effect, -b$effect, tolerance = 1e-8)))
cat("PASS reference inversion preserves effect semantics\n")
