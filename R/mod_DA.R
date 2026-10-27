mod_Metadata_ui <- function(id) {
  ns <- NS(id)
  bs4Dash::box(title = "Sample metadata / confounders", width = 12,
    helpText("First column: unique sample ID. Further columns: Group, age, sex, batch, subject_id, or other covariates. This is separate from the legacy class/color file. Nothing is silently intersected or imputed."),
    fileInput(ns("file"), "Upload sample metadata (TSV / CSV)", accept = c(".tsv", ".txt", ".csv")),
    selectInput(ns("separator"), "Separator", c("Tab" = "tab", "Comma" = "comma", "Semicolon" = "semicolon")),
    actionButton(ns("load"), "Load metadata"),
    actionButton(ns("example"), "Load example sample metadata"),
    actionButton(ns("example_from_upload"), "Load example sample metadata (3-omics demo)"),
    verbatimTextOutput(ns("status")),
    uiOutput(ns("editor")), actionButton(ns("apply_types"), "Apply metadata types and references"),
    selectInput(ns("class_column"), "Use this metadata column as class labels for PCA / PLS-DA / DIABLO", NULL),
    actionButton(ns("use_classes"), "Use as class labels"),
    DT::dataTableOutput(ns("preview")))
}

mod_Metadata_server <- function(id, metadata, single_classes = NULL, multi_classes = NULL, tables = NULL) {
  moduleServer(id, function(input, output, session) {
    status <- reactiveVal("")
    observeEvent(TRUE, {
      if (!galaxy_enabled()) return()
      path <- file.path(Sys.getenv("HOLOMICS_INPUT_DIR"), "manifest.json")
      if (!file.exists(path)) return()
      tryCatch({
        entry <- jsonlite::fromJSON(path, simplifyVector = FALSE)$metadata
        if (!is.null(entry)) {
          metadata$data <- galaxy_read_table(entry$path, entry$separator)
          status(paste("Loaded Galaxy sample metadata:", nrow(metadata$data), "samples"))
        }
      }, error = function(e) status(paste("Metadata import failed:", conditionMessage(e))))
    }, once = TRUE)
    observeEvent(input$load, {
      req(input$file)
      tryCatch({
        metadata$data <- galaxy_read_table(input$file$datapath, input$separator)
        metadata$references <- list()
        status(paste("Loaded", nrow(metadata$data), "samples and", ncol(metadata$data), "metadata columns"))
      }, error = function(e) status(conditionMessage(e)))
    })
    load_example_metadata <- function() {
      metadata$data <- galaxy_read_table(system.file("extdata", "three-omics", "metadata.tsv", package = "Holomics"))
      metadata$references <- list(Group = "Control")
      status("Example sample metadata loaded: Group, age, sex, batch, subject_id")
    }
    observeEvent(input$example, { load_example_metadata() })
    observeEvent(input$example_from_upload, { load_example_metadata() })
    output$editor <- renderUI({
      req(metadata$data)
      tagList(h4("Column types and reference levels"),
        helpText("Use categorical for group/batch/subject IDs, numeric for continuous covariates. Reference is the baseline for a categorical effect."),
        lapply(seq_along(metadata$data), function(i) {
          name <- names(metadata$data)[i]; x <- metadata$data[[i]]
          categorical <- is.factor(x) || is.character(x)
          values <- sort(unique(as.character(x[!is.na(x)])))
          reference <- metadata$references[[name]]
          if (is.null(reference)) reference <- if (is.factor(x)) levels(x)[1] else values[1]
          fluidRow(column(4, tags$strong(name)), column(4,
            selectInput(session$ns(paste0("type_", i)), paste(name, "type"), c("Categorical" = "categorical", "Numeric" = "numeric"), selected = if (categorical) "categorical" else "numeric")),
            column(4, conditionalPanel(sprintf("input['%s'] === 'categorical'", session$ns(paste0("type_", i))),
              selectInput(session$ns(paste0("ref_", i)), paste(name, "reference"), values, selected = reference))))
        }))
    })
    observeEvent(input$apply_types, {
      tryCatch({
        value <- metadata$data; req(value)
        references <- list()
        for (i in seq_along(value)) {
          name <- names(value)[i]
          if (identical(input[[paste0("type_", i)]], "numeric")) {
            converted <- suppressWarnings(as.numeric(as.character(value[[i]])))
            if (any(is.na(converted) & !is.na(value[[i]]))) stop("Cannot convert ", name, " to numeric")
            value[[i]] <- converted
          } else {
            ref <- input[[paste0("ref_", i)]]
            value[[i]] <- factor(value[[i]])
            if (!is.null(ref) && ref %in% levels(value[[i]])) {
              value[[i]] <- stats::relevel(value[[i]], ref)
              references[[name]] <- ref
            }
          }
        }
        metadata$data <- value; metadata$references <- references
        status("Metadata types and references applied. Preview the analysis design again before fitting.")
      }, error = function(e) status(conditionMessage(e)))
    })
    observe({ 
      req(metadata$data)
      choices <- names(metadata$data)
      if (!length(choices)) return()
      selected <- isolate(input$class_column)
      if (is.null(selected) || !selected %in% choices) selected <- if ("Group" %in% choices) "Group" else choices[1]
      updateSelectInput(session, "class_column", choices = choices, selected = selected) 
    })
    observeEvent(input$use_classes, {
      tryCatch({
        req(metadata$data, input$class_column)
        x <- metadata$data[[input$class_column]]
        if (anyNA(x) || length(unique(x)) < 2L) stop("Choose a column with at least two classes and no missing labels")
        classes <- data.frame(sample = rownames(metadata$data), value = as.character(x))
        names(classes)[2] <- input$class_column
        name <- paste("Metadata", input$class_column, sep = ": ")
        if (!is.null(single_classes)) single_classes$data[[name]] <- classes
        if (!is.null(multi_classes)) multi_classes$data[[name]] <- classes
        if (!is.null(tables)) tables$classes <- extendClassTable(tables$classes, name, "sample metadata", nrow(classes), FALSE)
        status(paste("Class labels available as", name, "— no second label-file upload needed."))
      }, error = function(e) status(conditionMessage(e)))
    })
    output$status <- renderText(status())
    output$preview <- DT::renderDataTable({ req(metadata$data); metadata$data }, options = list(scrollX = TRUE))
  })
}

mod_DA_ui <- function(id) {
  ns <- NS(id)
  tagList(h2("Differential abundance / association and batch correction"),
    helpText("Upload confounders in Upload data → Sample metadata. Fits use one selected block and a frozen copy of metadata/settings. Batch correction is not a significance test. Do not use outcome-preserving batch correction as input to predictive validation."),
    h3("1. Choose data and method"),
    fluidRow(column(4,
      selectInput(ns("block"), "Omics block", NULL),
      selectInput(ns("type"), "Input measurement type", c("Continuous / explicitly transformed" = "continuous", "Raw integer counts" = "counts", "Relative abundance (fractions)" = "relative")),
      selectInput(ns("method"), "Method", c("Linear model", "Mixed model", "limma", "MaAsLin3", "ANCOM-BC2", "DESeq2", "edgeR", "ComBat", "ComBat-seq")),
      uiOutput(ns("method_help")),
      h3("2. Define the comparison"),
      checkboxInput(ns("advanced_formula"), "Write an advanced formula", FALSE),
      conditionalPanel(sprintf("!input['%s']", ns("advanced_formula")),
        selectInput(ns("group"), "Variable of interest", NULL),
        selectInput(ns("covariates"), "Adjust for covariates / confounders", NULL, multiple = TRUE),
        uiOutput(ns("reference_control")),
        conditionalPanel(sprintf("['Mixed model','MaAsLin3','ANCOM-BC2'].includes(input['%s'])", ns("method")),
          selectInput(ns("subject"), "Repeated-measures subject", c("None" = "")))),
      conditionalPanel(sprintf("input['%s']", ns("advanced_formula")),
        textInput(ns("formula"), "Model / biological preservation formula", "~ Group + age + sex + batch"),
        helpText("Examples: ~ Group * time + age; ~ Group + age + (1 | subject_id). ComBat preservation formula must exclude batch.")),
      verbatimTextOutput(ns("formula_preview")),
      tags$div(style = "display:none;", checkboxInput(ns("override_types"), "Override shared metadata settings", FALSE),
      selectInput(ns("categorical"), "Treat metadata columns as categorical", NULL, multiple = TRUE),
      selectInput(ns("numeric"), "Treat metadata columns as numeric", NULL, multiple = TRUE),
      textAreaInput(ns("reference_json"), 'Additional reference levels (JSON), e.g. {"sex":"F"}', "{}")),
      actionButton(ns("preview"), "Preview design / coefficients"),
      selectInput(ns("coefficient"), "Coefficient to test (relative to reference)", NULL)),
      column(8, h3("3. Analysis options"),
        numericInput(ns("min_prevalence"), "Minimum non-zero sample fraction", 0.1, min = 0, max = 1, step = 0.05),
        numericInput(ns("alpha"), "FDR threshold", 0.05, min = 0.001, max = 1, step = 0.01),
        conditionalPanel(sprintf("['limma','edgeR'].includes(input['%s'])", ns("method")), checkboxInput(ns("robust"), "Robust estimation", FALSE)),
        conditionalPanel(sprintf("input['%s'] === 'limma'", ns("method")), checkboxInput(ns("trend"), "Mean–variance trend", FALSE)),
        conditionalPanel(sprintf("input['%s'] === 'edgeR'", ns("method")), selectInput(ns("normalization"), "Normalisation", c("TMM", "TMMwsp", "RLE", "upperquartile", "none"))),
        conditionalPanel(sprintf("input['%s'] === 'DESeq2'", ns("method")), selectInput(ns("size_factors"), "Size factors", c("ratio", "poscounts", "iterate"))),
        conditionalPanel(sprintf("input['%s'] === 'MaAsLin3'", ns("method")),
        selectInput(ns("maaslin_norm"), "MaAsLin3 normalisation", c("TSS", "NONE", "CLR")),
        selectInput(ns("maaslin_transform"), "MaAsLin3 transformation", c("LOG", "NONE")),
        checkboxInput(ns("standardize"), "MaAsLin3 standardise numeric covariates", TRUE),
        checkboxInput(ns("median_comparison"), "Abundance median comparison", TRUE)),
        conditionalPanel(sprintf("input['%s'] === 'ANCOM-BC2'", ns("method")), checkboxInput(ns("pseudo_sens"), "Pseudo-count sensitivity analysis", TRUE)),
        conditionalPanel(sprintf("['ComBat','ComBat-seq'].includes(input['%s'])", ns("method")),
        selectInput(ns("batch"), "ComBat / ComBat-seq batch column", NULL),
        checkboxInput(ns("parametric"), "ComBat parametric prior", TRUE),
        checkboxInput(ns("mean_only"), "ComBat mean-only adjustment", FALSE)))),
    actionButton(ns("run"), "Run analysis", class = "btn-primary"),
    textOutput(ns("freshness")),
    verbatimTextOutput(ns("status")), DT::dataTableOutput(ns("design")),
    helpText("BH correction is per block and coefficient for linear/mixed models, limma and edgeR. DESeq2 retains its independent-filtering adjustment; microbiome backends retain their native testing families and output schemas. Missing/failed tests are not evidence of no association."),
    h3("4. Explore and export results"),
    helpText("Successful analyses are also listed under Multi-omics → DA results overview. They do not change DIABLO inputs or mark DIABLO-selected features as significant."),
    selectInput(ns("table"), "Result table", NULL), DT::dataTableOutput(ns("results")),
    downloadButton(ns("download"), "Download selected table"), actionButton(ns("send_table"), "Send table to Galaxy"),
    downloadButton(ns("provenance"), "Download fit + settings RDS"),
    plotOutput(ns("volcano"), height = "550px"),
    downloadButton(ns("plot"), "Download plot PDF"), actionButton(ns("send_plot"), "Send plot to Galaxy"))
}

mod_DA_server <- function(id, single, metadata, da_results = NULL) {
  moduleServer(id, function(input, output, session) {
    fitted <- reactiveVal(NULL); status <- reactiveVal("Load sample metadata, preview the design, then run.")
    observe({ updateSelectInput(session, "block", choices = names(single$data), selected = isolate(input$block)) })
    observeEvent(input$type, {
      choices <- switch(input$type, continuous = c("Linear model", "limma", "Mixed model", "ComBat"),
        counts = c("DESeq2", "edgeR", "MaAsLin3", "ANCOM-BC2", "ComBat-seq"), relative = "MaAsLin3")
      current <- isolate(input$method)
      updateSelectInput(session, "method", choices = choices, selected = if (current %in% choices) current else choices[1])
    })
    output$method_help <- renderUI({
      package <- switch(input$method, "Linear model" = "stats", "Mixed model" = "lmerTest", "MaAsLin3" = "maaslin3",
        "ANCOM-BC2" = "ANCOMBC", "ComBat" = "sva", "ComBat-seq" = "sva", input$method)
      ready <- !is.null(package) && requireNamespace(package, quietly = TRUE)
      helpText(if (ready) paste(input$method, "backend installed. Validate the design before fitting.") else
        paste(input$method, "is not installed in this image; choose another method or rebuild."))
    })
    observe({
      names <- names(metadata$data)
      defaults <- names[vapply(metadata$data, function(x) is.character(x) || is.factor(x), logical(1))]
      updateSelectInput(session, "categorical", choices = names, selected = defaults)
      updateSelectInput(session, "numeric", choices = names, selected = setdiff(names, defaults))
      updateSelectInput(session, "batch", choices = names, selected = if ("batch" %in% names) "batch" else names[1])
      updateSelectInput(session, "group", choices = names, selected = if (is.null(input$group) || !input$group %in% names) if ("Group" %in% names) "Group" else names[1] else input$group)
      updateSelectInput(session, "covariates", choices = names)
      updateSelectInput(session, "subject", choices = c("None" = "", names))
    })
    output$reference_control <- renderUI({
      req(input$group, metadata$data)
      categorical <- if (isTRUE(input$override_types)) input$categorical else names(metadata$data)[vapply(metadata$data, function(x) is.character(x) || is.factor(x), logical(1))]
      if (!input$group %in% categorical) return(helpText("Numeric variable: the coefficient is the change per unit, not a group comparison."))
      values <- sort(unique(as.character(metadata$data[[input$group]])))
      ref <- metadata$references[[input$group]]
      if (is.null(ref)) ref <- if ("Control" %in% values) "Control" else values[1]
      selectInput(session$ns("reference"), "Reference group", values, selected = ref)
    })
    model_formula <- reactive({
      if (isTRUE(input$advanced_formula)) return(input$formula)
      req(input$group)
      quote_name <- function(x) { if (grepl("`", x, fixed = TRUE)) stop("Backticks in metadata names are not supported"); paste0("`", x, "`") }
      terms <- vapply(unique(c(input$group, input$covariates)), quote_name, character(1))
      if (input$method %in% c("Mixed model", "MaAsLin3", "ANCOM-BC2") && !is.null(input$subject) && nzchar(input$subject)) {
        if (!input$method %in% c("Mixed model", "MaAsLin3", "ANCOM-BC2")) stop("Choose a method supporting repeated measures, or clear the subject selection")
        terms <- c(terms, paste0("(1 | ", quote_name(input$subject), ")"))
      }
      paste("~", paste(terms, collapse = " + "))
    })
    output$formula_preview <- renderText({ tryCatch(paste("Model:", model_formula()), error = function(e) conditionMessage(e)) })
    prepared_inputs <- function() {
      req(single$data[[input$block]], metadata$data)
      data <- metadata$data
      reference <- list()
      tryCatch({
        if (!is.null(input$reference_json)) {
          val <- jsonlite::fromJSON(input$reference_json, simplifyVector = FALSE)
          if (is.list(val) && length(val)) reference <- val
        }
      }, error = function(e) NULL)
      settings <- reactiveValuesToList(input); settings$reference <- reference
      if (!is.null(metadata$references)) settings$reference <- utils::modifyList(metadata$references, reference)
      settings$formula <- model_formula()
      if (!isTRUE(input$advanced_formula) && (is.factor(data[[input$group]]) || is.character(data[[input$group]])) && !is.null(input$reference))
        settings$reference[[input$group]] <- input$reference
      list(X = single$data[[input$block]]$omicsData, metadata = data, settings = settings)
    }
    preview <- reactiveVal(NULL)
    design_snapshot <- reactiveVal(NULL)
    run_snapshot <- reactiveVal(NULL)
    design_fingerprint <- function(x) {
      tryCatch({
        list(ids = rownames(x$X), dims = dim(x$X),
             formula = x$settings$formula, reference = x$settings$reference,
             method = x$settings$method, type = x$settings$type)
      }, error = function(e) NULL)
    }
    snapshot <- function() {
      x <- prepared_inputs()
      # Plot/table selection and action-button counters do not change a model.
      keys <- c("block", "type", "method", "formula", "reference", "coefficient", "min_prevalence", "alpha", "robust", "trend", "normalization", "size_factors", "maaslin_norm", "maaslin_transform", "standardize", "median_comparison", "pseudo_sens", "batch", "parametric", "mean_only")
      list(X = x$X, metadata = x$metadata, settings = x$settings[intersect(keys, names(x$settings))])
    }
    output$freshness <- renderText({
      if (is.null(run_snapshot())) return("No fit for these settings yet. Review the design before running.")
      current <- tryCatch(snapshot(), error = function(e) NULL)
      if (identical(current, run_snapshot())) "Results match the fitted data and settings." else "Settings or data changed — rerun needed. Displayed results still belong to the previous fit."
    })
    auto_preview_run <- function() {
      tryCatch({
        x <- prepared_inputs()
        random <- input$method %in% c("Mixed model", "MaAsLin3", "ANCOM-BC2") && grepl("|", x$settings$formula, fixed = TRUE)
        value <- da_prepare(x$X, x$metadata, x$settings$formula, input$type, x$settings$reference, random)
        preview(value$design)
        design_snapshot(design_fingerprint(x))
        choices <- setdiff(colnames(value$design), "(Intercept)")
        if (length(choices) && (is.null(input$coefficient) || !input$coefficient %in% choices)) {
          updateSelectInput(session, "coefficient", choices = choices, selected = choices[1])
        } else if (length(choices)) {
          updateSelectInput(session, "coefficient", choices = choices, selected = input$coefficient)
        }
        status("Design validated. Running analysis...")
        fitted(NULL)
        value_fit <- da_run(x$X, x$metadata, x$settings)
        run_snapshot(snapshot())
        if (!is.null(da_results)) {
          key <- paste(input$block, input$method, input$coefficient, sep = " · ")
          value_fit$block <- input$block
          value_fit$completed <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
          da_results$data[[key]] <- value_fit
        }
        fitted(value_fit); updateSelectInput(session, "table", choices = names(value_fit$tables), selected = names(value_fit$tables)[1])
        status(paste(c(paste("Completed", input$method, "on", length(value_fit$sample_ids), "samples and", length(value_fit$tested_features), "features."), value_fit$warnings), collapse = "\n"))
      }, error = function(e) { fitted(NULL); preview(NULL); status(paste("Analysis failed:", conditionMessage(e))) })
    }
    observeEvent(input$preview, { auto_preview_run() })
    observeEvent(input$run, { auto_preview_run() })
    output$design <- DT::renderDataTable({ req(preview()); preview() })
    output$status <- renderText(status())
    selected_table <- reactive({ req(fitted(), input$table); fitted()$tables[[input$table]] })
    output$results <- DT::renderDataTable(selected_table(), options = list(scrollX = TRUE))
    draw <- function() {
      table <- selected_table()
      validate(need(all(c("effect", "q_value") %in% names(table)), "This backend retains native columns; select a standard coefficient result for a volcano plot."))
      graphics::plot(table$effect, -log10(pmax(table$q_value, .Machine$double.xmin)),
        col = ifelse(!is.na(table$q_value) & table$q_value <= fitted()$settings$alpha, "firebrick", "grey50"),
        pch = 16, xlab = "Effect (backend scale; see method)", ylab = "−log10 adjusted p-value")
      graphics::abline(h = -log10(fitted()$settings$alpha), lty = 2)
    }
    output$volcano <- renderPlot(draw())
    write_table <- function(file) utils::write.table(selected_table(), file, sep = "\t", row.names = FALSE, quote = FALSE)
    write_plot <- function(file) { grDevices::pdf(file, width = 10, height = 8); on.exit(grDevices::dev.off()); draw() }
    output$download <- downloadHandler(filename = "da_results.tsv", content = write_table)
    output$plot <- downloadHandler(filename = "da_plot.pdf", content = write_plot)
    output$provenance <- downloadHandler(filename = "da_fit.rds", content = function(file) { req(fitted()); saveRDS(fitted(), file) })
    send <- function(writer, name) {
      tryCatch({
        if (!galaxy_enabled()) stop("No active Galaxy connection")
        file <- tempfile(); on.exit(unlink(file)); writer(file); galaxy_publish(file, name)
        showNotification("Export staged; Galaxy upload started. Check the history for completion.")
      }, error = function(e) showNotification(conditionMessage(e), type = "error"))
    }
    observeEvent(input$send_table, send(write_table, "da_results.tsv"))
    observeEvent(input$send_plot, send(write_plot, "da_plot.pdf"))
  })
}
