# Model formulas are parsed, never evaluated as arbitrary user R code.
da_formula <- function(text, metadata, random = FALSE) {
  expression <- str2lang(text)
  allowed <- c("~", "+", "-", "*", ":", "^", "(", "log", "log2", "scale", "I")
  if (random) allowed <- c(allowed, "|")
  walk <- function(x) {
    if (is.call(x)) {
      if (!is.symbol(x[[1]]) || !as.character(x[[1]]) %in% allowed)
        stop("Unsupported formula operation; use metadata names, interactions, log(), scale(), I(), and supported random effects")
      lapply(as.list(x)[-1], walk)
    } else if (is.symbol(x)) {
      if (!as.character(x) %in% names(metadata)) stop("Unknown metadata column: ", as.character(x))
    } else if (!is.numeric(x)) stop("Unsupported formula value")
    invisible(NULL)
  }
  walk(expression)
  if (!is.call(expression) || as.character(expression[[1]]) != "~" || length(expression) != 2L)
    stop("Provide a one-sided formula, e.g. ~ Group + age + batch")
  stats::as.formula(expression, env = asNamespace("stats"))
}

da_prepare <- function(X, metadata, formula, type, reference = list(), random = FALSE) {
  X <- as.matrix(X)
  if (!is.numeric(X) || any(!is.finite(X))) stop("Measurements must be finite and numeric; missing values require explicit preprocessing")
  ids <- rownames(X)
  if (is.null(ids) || anyDuplicated(ids) || anyDuplicated(rownames(metadata)) || !setequal(ids, rownames(metadata)))
    stop("Metadata and measurements need exactly matching unique sample IDs")
  if (is.null(colnames(X)) || anyDuplicated(colnames(X))) stop("Unique feature IDs required")
  if (type == "counts" && (any(X < 0) || any(X != floor(X)) || any(X > .Machine$integer.max)))
    stop("Count methods require untransformed non-negative integer counts; no rounding is performed")
  if (type == "relative" && (any(X < 0 | X > 1) || any(abs(rowSums(X) - 1) > 0.01)))
    stop("Relative abundances must be fractions summing to one per sample (tolerance 0.01)")
  metadata <- metadata[match(ids, rownames(metadata)), , drop = FALSE]
  for (name in names(metadata)) if (is.character(metadata[[name]])) metadata[[name]] <- factor(metadata[[name]])
  for (name in names(reference)) {
    if (!name %in% names(metadata) || !is.factor(metadata[[name]]) || !reference[[name]] %in% levels(metadata[[name]]))
      stop("Invalid reference level for ", name)
    metadata[[name]] <- stats::relevel(metadata[[name]], ref = reference[[name]])
  }
  f <- da_formula(formula, metadata, random)
  if (anyNA(metadata[all.vars(f)])) stop("Missing model metadata; samples are not silently dropped")
  fixed <- if (random) { if (!requireNamespace("lme4", quietly = TRUE)) stop("lme4 required"); lme4::nobars(f) } else f
  design <- stats::model.matrix(fixed, metadata)
  if (any(!is.finite(design)) || qr(design)$rank < ncol(design) || nrow(design) <= ncol(design))
    stop("Design is non-finite, confounded/rank-deficient, or has no residual degrees of freedom")
  if (random && anyNA(stats::model.frame(lme4::subbars(f), metadata, na.action = stats::na.pass))) stop("Missing random-effect metadata")
  list(X = X, metadata = metadata, formula = f, design = design)
}

da_require <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Backend not installed: ", package, ". Rebuild the DA-enabled image before using this method.")
}

da_run <- function(X, metadata, settings) {
  method <- settings$method
  count_methods <- c("DESeq2", "edgeR", "ANCOM-BC2", "ComBat-seq")
  if (method %in% count_methods && settings$type != "counts") stop(method, " requires declared raw counts")
  if (method %in% c("limma", "Linear model", "Mixed model", "ComBat") && settings$type != "continuous")
    stop(method, " requires continuous/pre-transformed measurements; transform explicitly, not implicitly")
  if (method == "MaAsLin3" && settings$type == "continuous") stop("Use limma or linear/mixed models for continuous data in this workspace")
  random <- method %in% c("Mixed model", "MaAsLin3", "ANCOM-BC2") && grepl("|", settings$formula, fixed = TRUE)
  prepared <- da_prepare(X, metadata, settings$formula, settings$type, settings$reference, random)
  X <- prepared$X; metadata <- prepared$metadata; design <- prepared$design
  if (settings$min_prevalence < 0 || settings$min_prevalence > 1) stop("Invalid prevalence")
  keep <- colMeans(X != 0) >= settings$min_prevalence & apply(X, 2, stats::var) > 0
  X <- X[, keep, drop = FALSE]
  if (ncol(X) < 2) stop("Fewer than two nonconstant features pass filtering")
  coefficient <- settings$coefficient
  needs_coef <- method %in% c("limma", "Linear model", "Mixed model", "DESeq2", "edgeR")
  if (needs_coef && !coefficient %in% colnames(design)) stop("Select a coefficient from the design preview")
  tables <- list(); corrected <- NULL; native <- NULL
  warnings <- character()
  withCallingHandlers({
    if (method == "limma") {
      da_require("limma")
      native <- limma::eBayes(limma::lmFit(t(X), design), trend = settings$trend, robust = settings$robust)
      result <- limma::topTable(native, coef = match(coefficient, colnames(design)), number = Inf, sort.by = "none")
      tables$results <- data.frame(feature = rownames(result), coefficient = coefficient, effect = result$logFC,
        p_value = result$P.Value, q_value = result$adj.P.Val, result, check.names = FALSE)
    } else if (method %in% c("Linear model", "Mixed model")) {
      f <- prepared$formula
      f <- stats::as.formula(call("~", as.name(".response"), f[[2]]), env = environment(f))
      if (".response" %in% names(metadata)) stop("Reserved metadata name: .response")
      if (method == "Mixed model") da_require("lmerTest")
      failures <- list()
      rows <- lapply(seq_len(ncol(X)), function(j) {
        tryCatch({
          data <- metadata; data$.response <- X[, j]
          fit <- if (method == "Mixed model") lmerTest::lmer(f, data = data, REML = TRUE) else stats::lm(f, data = data)
          coef <- summary(fit)$coefficients
          if (!coefficient %in% rownames(coef)) stop("Coefficient not estimable")
          data.frame(feature = colnames(X)[j], coefficient = coefficient, effect = coef[coefficient, 1],
            standard_error = coef[coefficient, 2], p_value = coef[coefficient, ncol(coef)],
            singular = if (method == "Mixed model") lme4::isSingular(fit) else FALSE)
        }, error = function(e) { failures[[length(failures) + 1L]] <<- data.frame(feature = colnames(X)[j], error = conditionMessage(e)); NULL })
      })
      result <- do.call(rbind, rows)
      if (is.null(result)) stop("All feature models failed")
      result$q_value <- stats::p.adjust(result$p_value, "BH", n = ncol(X))
      tables$results <- result
      if (length(failures)) tables$failures <- do.call(rbind, failures)
    } else if (method == "DESeq2") {
      da_require("DESeq2")
      native <- DESeq2::DESeqDataSetFromMatrix(t(X), metadata, prepared$formula)
      native <- DESeq2::DESeq(native, quiet = TRUE, sfType = settings$size_factors)
      index <- match(coefficient, colnames(design))
      result <- as.data.frame(DESeq2::results(native, name = DESeq2::resultsNames(native)[index], alpha = settings$alpha))
      tables$results <- data.frame(feature = rownames(result), coefficient = coefficient, effect = result$log2FoldChange,
        p_value = result$pvalue, q_value = result$padj, result, check.names = FALSE)
    } else if (method == "edgeR") {
      da_require("edgeR")
      y <- edgeR::calcNormFactors(edgeR::DGEList(t(X)), method = settings$normalization)
      y <- edgeR::estimateDisp(y, design, robust = settings$robust)
      native <- edgeR::glmQLFit(y, design, robust = settings$robust)
      test <- edgeR::glmQLFTest(native, coef = match(coefficient, colnames(design)))
      result <- edgeR::topTags(test, n = Inf, sort.by = "none")$table
      tables$results <- data.frame(feature = rownames(result), coefficient = coefficient, effect = result$logFC,
        p_value = result$PValue, q_value = result$FDR, result, check.names = FALSE)
    } else if (method == "MaAsLin3") {
      da_require("maaslin3")
      directory <- tempfile("maaslin3-"); dir.create(directory)
      native <- maaslin3::maaslin3(input_data = as.data.frame(X), input_metadata = metadata,
        output = directory, formula = prepared$formula, normalization = settings$maaslin_norm,
        transform = settings$maaslin_transform, min_prevalence = 0, standardize = settings$standardize,
        warn_prevalence = settings$maaslin_norm == "TSS" && settings$maaslin_transform == "LOG",
        median_comparison_abundance = settings$median_comparison, max_significance = settings$alpha,
        cores = 1, plot_summary_plot = FALSE, plot_associations = FALSE)
      files <- list.files(directory, pattern = "results.*\\.tsv$", recursive = TRUE, full.names = TRUE)
      for (file in files) tables[[basename(file)]] <- utils::read.delim(file, check.names = FALSE)
      if (!length(tables)) stop("MaAsLin3 did not produce result tables; inspect its native output")
    } else if (method == "ANCOM-BC2") {
      da_require("ANCOMBC")
      fixed <- if (random) lme4::nobars(prepared$formula) else prepared$formula
      random_formula <- if (random) paste(vapply(lme4::findbars(prepared$formula), function(x) paste0("(", paste(deparse(x), collapse = ""), ")"), character(1)), collapse = "+") else NULL
      native <- ANCOMBC::ancombc2(data = X, taxa_are_rows = FALSE, meta_data = metadata,
        fix_formula = paste(deparse(fixed[[2]]), collapse = ""), rand_formula = random_formula,
        prv_cut = 0, lib_cut = 0, p_adj_method = "BH", pseudo_sens = settings$pseudo_sens,
        alpha = settings$alpha, n_cl = 1, verbose = FALSE)
      tables$results <- native$res
      if (!is.null(native$zero_ind)) tables$structural_zeros <- native$zero_ind
    } else if (method %in% c("ComBat", "ComBat-seq")) {
      da_require("sva")
      if (!settings$batch %in% names(metadata)) stop("Choose a batch column")
      batch <- factor(metadata[[settings$batch]])
      if (anyNA(batch) || nlevels(batch) < 2 || min(table(batch)) < 2) stop("Need at least two batches with two samples each")
      if (settings$batch %in% all.vars(prepared$formula)) stop("Preservation formula must exclude batch")
      combined <- cbind(stats::model.matrix(~ batch)[, -1, drop = FALSE], design)
      if (qr(combined)$rank < ncol(combined)) stop("Batch is confounded with preservation covariates")
      corrected <- if (method == "ComBat") t(sva::ComBat(t(X), batch, mod = design,
        par.prior = settings$parametric, mean.only = settings$mean_only, prior.plots = FALSE)) else
        t(sva::ComBat_seq(t(X), batch, covar_mod = design[, colnames(design) != "(Intercept)", drop = FALSE],
          full_mod = TRUE, shrink = FALSE))
      tables$corrected <- data.frame(sample_id = rownames(corrected), corrected, check.names = FALSE)
    } else stop("Unknown DA method")
  }, warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") })
  list(tables = tables, corrected = corrected, model = native, settings = settings,
    sample_ids = rownames(X), tested_features = colnames(X), excluded_features = colnames(prepared$X)[!keep],
    design = design, metadata = metadata, warnings = unique(warnings), session = utils::capture.output(sessionInfo()))
}
