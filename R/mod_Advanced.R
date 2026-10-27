# Explicit public method catalog for mixOmics 6.30; no arbitrary R evaluation.
advanced_methods <- function() c("pca", "spca", "ipca", "sipca", "pls", "spls",
  "plsda", "splsda", "rcc", "block.pls", "block.spls", "block.plsda", "block.splsda",
  "mint.pls", "mint.spls", "mint.plsda", "mint.splsda", "mint.block.pls",
  "mint.block.spls", "mint.block.plsda", "mint.block.splsda")

advanced_counts <- function(text, ncomp, p) {
  values <- suppressWarnings(as.numeric(trimws(strsplit(text, ",", fixed = TRUE)[[1]])))
  if (length(values) == 1L) values <- rep(values, ncomp)
  if (length(values) != ncomp || anyNA(values) || any(values != floor(values)) ||
      any(values < 1 | values > p)) stop("keepX/keepY must be positive integers, one per component (or a single repeated value), no greater than the block's feature count")
  as.integer(values)
}

advanced_data <- function(blocks, labels = NULL, study = NULL) {
  if (!length(blocks)) stop("Select at least one block")
  ids <- rownames(blocks[[1]])
  if (is.null(ids) || anyDuplicated(ids) || anyNA(ids)) stop("Unique sample IDs are required")
  blocks <- lapply(blocks, function(x) {
    if (!setequal(rownames(x), ids)) stop("Selected blocks must have matching sample IDs; no implicit intersection")
    x <- as.matrix(x[match(ids, rownames(x)), , drop = FALSE])
    if (!is.numeric(x) || any(!is.finite(x))) stop("All blocks must contain finite numeric measurements")
    if (is.null(colnames(x)) || anyDuplicated(colnames(x))) stop("Unique feature names required within each block")
    x
  })
  align <- function(table, description) {
    if (is.null(table)) return(NULL)
    if (ncol(table) < 2 || anyDuplicated(table[[1]]) || !setequal(as.character(table[[1]]), ids))
      stop(description, " must have exactly matching, unique sample IDs")
    value <- table[match(ids, table[[1]]), 2]
    if (anyNA(value) || any(!nzchar(as.character(value)))) stop(description, " contains missing values")
    factor(value)
  }
  list(X = blocks, labels = align(labels, "Labels"), study = align(study, "Study table"), ids = ids)
}

advanced_fit <- function(method, data, settings) {
  if (!method %in% advanced_methods()) stop("Unsupported method")
  is_block <- grepl("block", method, fixed = TRUE)
  is_da <- grepl("da$", method)
  is_pair <- method %in% c("pls", "spls", "rcc", "mint.pls", "mint.spls")
  is_mint <- startsWith(method, "mint.")
  X <- data$X
  ncomp <- as.integer(settings$ncomp)
  if (length(ncomp) != 1 || is.na(ncomp) || ncomp < 1) stop("Invalid component count")
  if ((is_pair && length(X) != 2L) || (is_block && length(X) < 2L) ||
      (!is_pair && !is_block && length(X) != 1L))
    stop("Select exactly one block for single-block methods, two for pairwise methods, or at least two for block methods")
  if (any(vapply(X, function(x) ncomp >= min(dim(x)), logical(1))))
    stop("Use fewer components than both samples and features in every block")
  if (is_da && (is.null(data$labels) || nlevels(data$labels) < 2L || min(table(data$labels)) < 2L))
    stop("Discriminant methods need labels with at least two classes and two samples per class")
  if (is_mint) {
    if (is.null(data$study) || nlevels(data$study) < 2L || min(table(data$study)) < 3L)
      stop("MINT needs a study table with at least two studies and three samples per study")
    if (is_da && any(table(data$study, data$labels) < 2L))
      stop("Each MINT study must contain at least two samples from every class")
  }
  fun <- getExportedValue("mixOmics", method)
  formal_names <- names(formals(fun))
  args <- list(X = if (is_block) X else X[[1]], ncomp = ncomp)
  if (is_da) args$Y <- data$labels
  if (is_pair) args$Y <- X[[2]]
  if (is_mint) args$study <- data$study
  if (is_block) {
    # Continuous block models require an explicit response block. Keep it in
    # X and identify it with indY so design/keepX retain selected-block order.
    if (!is_da) args$indY <- length(X)
    design <- matrix(settings$coupling, length(X), length(X), dimnames = list(names(X), names(X)))
    diag(design) <- 0
    if (nzchar(trimws(settings$design_json))) {
      custom <- jsonlite::fromJSON(settings$design_json)
      design <- as.matrix(custom)
      if (!identical(dim(design), c(length(X), length(X))) || !is.numeric(design) ||
          anyNA(design) || any(design < 0 | design > 1) || !isTRUE(all.equal(design, t(design))) || any(diag(design) != 0))
        stop("Design must be a symmetric JSON square matrix in selected block order, diagonal zero and values 0–1")
      dimnames(design) <- list(names(X), names(X))
    }
    args$design <- design
    args$scheme <- settings$scheme
    args$init <- settings$init
  }
  for (key in c("center", "scale", "max.iter", "tol", "near.zero.var", "logratio", "ilr.offset"))
    if (key %in% formal_names) args[[key]] <- settings[[key]]
  if ("mode" %in% formal_names) args$mode <- if (method %in% c("ipca", "sipca")) settings$ica_mode else settings$mode
  if ("fun" %in% formal_names) args$fun <- settings$ica_fun
  if (method == "rcc") {
    args$method <- settings$rcc_method
    args$lambda1 <- settings$lambda1; args$lambda2 <- settings$lambda2
  }
  if ("keepX" %in% formal_names) {
    args$keepX <- if (is_block) lapply(X, function(x) advanced_counts(settings$keepX, ncomp, ncol(x))) else advanced_counts(settings$keepX, ncomp, ncol(X[[1]]))
    if (is_block && nzchar(trimws(settings$keep_json))) {
      custom <- jsonlite::fromJSON(settings$keep_json, simplifyVector = FALSE)
      if (!setequal(names(custom), names(X))) stop("Per-block keepX JSON keys must match selected block names")
      args$keepX <- lapply(names(X), function(name) advanced_counts(paste(unlist(custom[[name]]), collapse = ","), ncomp, ncol(X[[name]])))
      names(args$keepX) <- names(X)
    }
  }
  if (is_pair && "keepY" %in% formal_names) args$keepY <- advanced_counts(settings$keepY, ncomp, ncol(X[[2]]))
  # Ignore only controls that do not apply to this method, never user-specified unknown arguments.
  args <- args[names(args) %in% formal_names]
  if (settings$logratio != "none" && "logratio" %in% names(args) && any(vapply(X, function(x) any(x <= 0), logical(1))))
    stop("Log-ratio transformations require strictly positive measurements; prepare compositional inputs explicitly")
  set.seed(as.integer(settings$seed))
  fit <- do.call(fun, args)
  list(model = fit, method = method, parameters = args[setdiff(names(args), c("X", "Y", "study"))],
       data = data, seed = settings$seed, mixOmics = as.character(utils::packageVersion("mixOmics")),
       session = utils::capture.output(sessionInfo()))
}

advanced_loadings <- function(fit) {
  values <- fit$model$loadings
  if (is.matrix(values)) values <- list(X = values)
  rows <- lapply(names(values), function(block) {
    x <- values[[block]]
    if (!is.matrix(x)) return(NULL)
    do.call(rbind, lapply(seq_len(ncol(x)), function(k) data.frame(block = block,
      feature = rownames(x), component = k, loading = x[, k], selected = x[, k] != 0)))
  })
  do.call(rbind, rows)
}

# Separate descriptive, unadjusted group comparison; NOT model-derived significance.
advanced_univariate <- function(data, method = "wilcox") {
  if (is.null(data$labels)) stop("Labels required for group comparisons")
  if (method == "wilcox" && nlevels(data$labels) != 2L) stop("Wilcoxon needs exactly two classes; choose Kruskal–Wallis for more")
  result <- do.call(rbind, lapply(names(data$X), function(block) {
    X <- data$X[[block]]
    p <- vapply(seq_len(ncol(X)), function(j) {
      if (stats::var(X[, j]) == 0) return(1)
      if (method == "wilcox") stats::wilcox.test(X[, j] ~ data$labels, exact = FALSE)$p.value
      else stats::kruskal.test(X[, j] ~ data$labels)$p.value
    }, numeric(1))
    data.frame(block = block, feature = colnames(X), p_value = p)
  }))
  result$FDR_BH_all_blocks <- stats::p.adjust(result$p_value, "BH")
  result[order(result$p_value), ]
}

mod_Advanced_ui <- function(id) {
  ns <- NS(id)
  tagList(
    h2("Advanced mixOmics workbench"),
    helpText("Explicit fits on aligned, preprocessed data. Methods run only when Fit is clicked. These are exploratory fits, not independent predictive validation. Existing tuned workflows remain in the original tabs."),
    fluidRow(column(4, selectInput(ns("method"), "Method", advanced_methods()),
      selectInput(ns("blocks"), "Blocks (selection order defines X, Y and design order)", NULL, multiple = TRUE),
      helpText("Pairwise methods use the first block as X and the second as Y. Continuous block methods (including MINT) use the last selected block as response Y; all preceding blocks are predictors. Discriminant methods use class labels as Y. Design and per-block keepX follow selected-block order."),
      selectInput(ns("labels"), "Class labels / plot groups", NULL),
      conditionalPanel(sprintf("input['%s'] && input['%s'].startsWith('mint.')", ns("method"), ns("method")),
        fileInput(ns("study"), "Study membership (TSV: sample ID, study)", accept = c(".tsv", ".txt")),
        helpText("Use genuine independent cohorts/studies, not omics layers or treatment groups."))),
      column(8, uiOutput(ns("parameters")))),
    actionButton(ns("fit"), "Fit selected method", class = "btn-primary"),
    verbatimTextOutput(ns("status")),
    bs4Dash::box(title = "Plot parameters", width = 12, collapsed = FALSE,
      fluidRow(column(3, selectInput(ns("plot"), "Plot", c("Scores", "Loadings", "Correlation circle", "CIM heatmap", "DIABLO", "Circos"))),
        column(2, numericInput(ns("comp1"), "Component X / single", 1, min = 1)),
        column(2, conditionalPanel(sprintf("['Scores','Correlation circle'].includes(input['%s'])", ns("plot")), numericInput(ns("comp2"), "Component Y", 2, min = 1))),
        column(2, selectInput(ns("plot_block"), "Block", NULL)),
        column(3, checkboxInput(ns("names"), "Show names", FALSE), conditionalPanel(sprintf("input['%s'] === 'Scores'", ns("plot")), checkboxInput(ns("ellipse"), "Group ellipses (descriptive)", FALSE)))),
      fluidRow(column(3, conditionalPanel(sprintf("['Correlation circle','Circos'].includes(input['%s'])", ns("plot")), numericInput(ns("cutoff"), "Association / circle cutoff", 0.5, min = 0, max = 1, step = 0.05))),
        column(3, numericInput(ns("size"), "Label / point size", 1, min = 0.1, max = 4, step = 0.1)),
        column(3, conditionalPanel(sprintf("input['%s'] === 'Loadings'", ns("plot")), numericInput(ns("top"), "Top loading features", 20, min = 1, max = 500))),
        column(3, conditionalPanel(sprintf("input['%s'] === 'Circos'", ns("plot")), checkboxInput(ns("intra"), "Circos within-block links", FALSE), checkboxInput(ns("line"), "Circos expression line", TRUE)))),
      conditionalPanel(sprintf("input['%s'] === 'CIM heatmap'", ns("plot")), fluidRow(column(3, checkboxInput(ns("row_names"), "Heatmap row names", TRUE)),
        column(3, checkboxInput(ns("col_names"), "Heatmap column names", TRUE)),
        column(3, checkboxInput(ns("transpose"), "Transpose heatmap", FALSE)),
        column(3, numericInput(ns("margin"), "Heatmap margin", 5, min = 1, max = 30)))),
      plotOutput(ns("figure"), height = "650px"),
      downloadButton(ns("plot_pdf"), "Download plot PDF")),
    bs4Dash::box(title = "Features and exports", width = 12,
      helpText("Non-zero loadings indicate model selection, not p-value significance. Optional group tests use unpaired independent-sample Wilcoxon / Kruskal–Wallis and BH across all features in all selected blocks. They do not adjust for study, subject, batch or other covariates, and must not be interpreted as validated biomarkers."),
      selectInput(ns("feature_method"), "Feature table", c("Model loadings" = "loadings", "Two-class Wilcoxon + BH FDR" = "wilcox", "Multi-class Kruskal–Wallis + BH FDR" = "kruskal")),
      DT::dataTableOutput(ns("features")), downloadButton(ns("feature_tsv"), "Download feature table"),
      downloadButton(ns("model_rds"), "Download fitted model and provenance")))
}

advanced_settings_ui <- function(ns, method) {
  formal_names <- names(formals(getExportedValue("mixOmics", method)))
  controls <- list(numericInput(ns("ncomp"), "Components", 2, min = 1, max = 20),
    numericInput(ns("seed"), "Random seed", 123, min = 0, max = 2147483646))
  if ("scale" %in% formal_names) controls <- c(controls, list(checkboxInput(ns("scale"), "Scale to unit variance", TRUE)))
  if ("center" %in% formal_names) controls <- c(controls, list(checkboxInput(ns("center"), "Center", TRUE)))
  if ("keepX" %in% formal_names) controls <- c(controls, list(textInput(ns("keepX"), "keepX: one count or comma-separated counts per component", "5")))
  if ("keepY" %in% formal_names && !grepl("block", method)) controls <- c(controls, list(textInput(ns("keepY"), "keepY per component", "5")))
  if (grepl("block", method)) {
    controls <- c(controls, list(numericInput(ns("coupling"), "Between-block design coupling", 0.1, min = 0, max = 1, step = 0.1),
      textAreaInput(ns("design_json"), "Optional full design JSON matrix", ""),
      selectInput(ns("scheme"), "Scheme", c("horst", "factorial", "centroid")),
      selectInput(ns("init"), "Initialisation", c("svd", "svd.single"))))
    if ("keepX" %in% formal_names) controls <- c(controls, list(textAreaInput(ns("keep_json"), 'Optional per-block keepX JSON, e.g. {"BlockA":[5,5],"BlockB":[3,3]}', "")))
  }
  if ("mode" %in% formal_names) controls <- c(controls, if (method %in% c("ipca", "sipca")) list(
    selectInput(ns("ica_mode"), "ICA mode", c("deflation", "parallel")),
    selectInput(ns("ica_fun"), "ICA nonlinearity", c("logcosh", "exp"))) else list(
      selectInput(ns("mode"), "PLS mode", c("regression", "canonical", "invariant", "classic"))))
  if (method == "rcc") controls <- c(controls, list(selectInput(ns("rcc_method"), "Regularisation", c("ridge", "shrinkage")),
    numericInput(ns("lambda1"), "X ridge penalty", 0.1, min = 0, max = 1, step = 0.05),
    numericInput(ns("lambda2"), "Y ridge penalty", 0.1, min = 0, max = 1, step = 0.05)))
  if ("max.iter" %in% formal_names) controls <- c(controls, list(numericInput(ns("max.iter"), "Maximum iterations", 500, min = 10, max = 10000)))
  if ("tol" %in% formal_names) controls <- c(controls, list(numericInput(ns("tol"), "Convergence tolerance", 1e-6, min = 1e-12, max = 0.1)))
  if ("near.zero.var" %in% formal_names) controls <- c(controls, list(checkboxInput(ns("near.zero.var"), "Remove near-zero-variance features within fit", FALSE)))
  if ("logratio" %in% formal_names) controls <- c(controls, list(selectInput(ns("logratio"), "Compositional transformation", if (method == "pca") c("none", "CLR", "ILR") else c("none", "CLR"))))
  if ("ilr.offset" %in% formal_names) controls <- c(controls, list(numericInput(ns("ilr.offset"), "ILR offset", 0.001, min = 0)))
  do.call(tagList, controls)
}

mod_Advanced_server <- function(id, single, multi, classes) {
  moduleServer(id, function(input, output, session) {
    stores <- reactive({ x <- single$data; for (name in setdiff(names(multi$data), names(x))) x[[name]] <- multi$data[[name]]; x })
    observe({ updateSelectInput(session, "blocks", choices = names(stores()), selected = isolate(input$blocks)) })
    observe({ updateSelectInput(session, "labels", choices = c("None" = "", names(classes$data)), selected = isolate(input$labels)) })
    output$parameters <- renderUI(advanced_settings_ui(session$ns, input$method))
    fitted <- reactiveVal(NULL)
    message <- reactiveVal("No model fitted")
    output$status <- renderText(message())
    observeEvent(input$fit, {
      tryCatch({
        blocks <- lapply(stores()[input$blocks], function(x) x$omicsData)
        labels <- if (nzchar(input$labels)) classes$data[[input$labels]] else NULL
        study <- NULL
        if (startsWith(input$method, "mint.") && !is.null(input$study)) {
          table <- galaxy_read_table(input$study$datapath, "tab")
          if (ncol(table) != 1L) stop("Study TSV must have two columns")
          study <- data.frame(sample = rownames(table), study = table[[1]])
        }
        data <- advanced_data(blocks, labels, study)
        settings <- reactiveValuesToList(input)
        for (key in c("design_json", "keep_json")) if (is.null(settings[[key]])) settings[[key]] <- ""
        if (is.null(settings$logratio)) settings$logratio <- "none"
        value <- advanced_fit(input$method, data, settings)
        fitted(value)
        updateSelectInput(session, "plot_block", choices = names(value$model$loadings), selected = names(value$model$loadings)[1])
        plots <- c("Scores", "Loadings", "Correlation circle")
        if (input$method %in% c("pls", "spls", "block.splsda")) plots <- c(plots, "CIM heatmap")
        if (input$method == "block.splsda") plots <- c(plots, "DIABLO", "Circos")
        updateSelectInput(session, "plot", choices = plots, selected = "Scores")
        message(paste("Fitted", value$method, "on", length(data$ids), "samples and", length(data$X), "block(s). Parameters are frozen until Fit is clicked again."))
      }, error = function(e) { fitted(NULL); message(paste("Fit failed:", conditionMessage(e))) })
    })
    draw <- function() {
      value <- fitted(); req(value)
      model <- value$model
      k <- as.integer(input$comp1); k2 <- as.integer(input$comp2)
      validate(need(k >= 1 && k <= min(unlist(model$ncomp)), "Component outside fitted range"))
      type <- input$plot
      if (type %in% c("Scores", "Correlation circle"))
        validate(need(k2 >= 1 && k2 <= min(unlist(model$ncomp)) && k != k2, "Choose two distinct fitted components"))
      if (type == "Scores") {
        scores <- model$variates
        if (is.matrix(scores)) scores <- list(X = scores)
        block <- input$plot_block
        if (!block %in% names(scores)) block <- names(scores)[1]
        s <- scores[[block]]
        group <- value$data$labels
        # plotIndiv dispatches on model classes, not a score matrix. Plot the
        # selected fitted block explicitly so this works across the catalog.
        frame <- data.frame(x = s[, k], y = s[, k2], sample = value$data$ids)
        if (!is.null(group)) frame$group <- group
        mapping <- if (is.null(group)) ggplot2::aes(x = x, y = y) else ggplot2::aes(x = x, y = y, colour = group)
        figure <- ggplot2::ggplot(frame, mapping) + ggplot2::geom_point(size = input$size) +
          ggplot2::labs(x = paste("Component", k), y = paste("Component", k2), title = paste(value$method, block)) +
          ggplot2::theme_minimal()
        if (isTRUE(input$names)) figure <- figure + ggplot2::geom_text(ggplot2::aes(label = sample), size = input$size, vjust = -0.5)
        if (isTRUE(input$ellipse) && !is.null(group)) {
          validate(need(all(table(group) >= 4), "Group ellipses require at least four samples per group"))
          figure <- figure + ggplot2::stat_ellipse()
        }
        print(figure)
      } else if (type == "Loadings") {
        x <- model$loadings[[input$plot_block]][, k]
        x <- x[order(abs(x), decreasing = TRUE)]
        x <- head(x, input$top)
        graphics::barplot(rev(x), names.arg = if (isTRUE(input$names)) rev(names(x)) else NULL,
          horiz = TRUE, las = 1, cex.names = input$size, main = paste(input$plot_block, "component", k), xlab = "Loading")
      } else if (type == "Correlation circle") {
        plotVar(model, c(k, k2), input$names, cutoff = input$cutoff, cex = input$size)
      } else if (type == "CIM heatmap") {
        f <- if (inherits(model, "block.splsda")) mixOmics::cimDiablo else mixOmics::cim
        f(model, comp = k, row.names = input$row_names, col.names = input$col_names,
          transpose = input$transpose, margins = rep(input$margin, 2))
      } else {
        validate(need(inherits(model, "block.splsda"), "DIABLO/Circos plots require block.splsda"))
        if (type == "DIABLO") mixOmics::plotDiablo(model, ncomp = k)
        else mixOmics::circosPlot(model, comp = k, cutoff = input$cutoff, size.variables = input$size,
          showIntraLinks = input$intra, line = input$line)
      }
    }
    output$figure <- renderPlot({ tryCatch(draw(), error = function(e) validate(need(FALSE, conditionMessage(e)))) })
    features <- reactive({
      value <- fitted(); req(value)
      if (input$feature_method == "loadings") advanced_loadings(value)
      else advanced_univariate(value$data, input$feature_method)
    })
    output$features <- DT::renderDataTable({ tryCatch(features(), error = function(e) validate(need(FALSE, conditionMessage(e)))) })
    output$model_rds <- downloadHandler(filename = "mixomics_model.rds", content = function(file) {
      req(fitted()); saveRDS(fitted(), file); galaxy_capture_download(file, "mixomics_model.rds")
    })
    output$feature_tsv <- downloadHandler(filename = "mixomics_features.tsv", content = function(file) {
      utils::write.table(features(), file, sep = "\t", row.names = FALSE, quote = FALSE)
      galaxy_capture_download(file, "mixomics_features.tsv")
    })
    output$plot_pdf <- downloadHandler(filename = "mixomics_plot.pdf", content = function(file) {
      grDevices::pdf(file, width = 12, height = 10); on.exit(grDevices::dev.off()); draw()
      # Close before staging so the exported PDF is complete.
      grDevices::dev.off(); on.exit(NULL)
      galaxy_capture_download(file, "mixomics_plot.pdf")
    })
  })
}
