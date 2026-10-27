# Exercise the real module's outputs and export handlers after catalog fits.
source("/opt/Holomics/tests/advanced-methods.R")
library(shiny)
study_file <- tempfile(fileext = ".tsv")
write.table(study, study_file, sep = "\t", row.names = FALSE, quote = FALSE)
results <- list()
for (method in env$advanced_methods()) {
  error <- tryCatch({
    selected <- if (grepl("block", method) || method %in% c("pls", "spls", "rcc", "mint.pls", "mint.spls")) blocks else blocks[1]
    shiny::testServer(function(input, output, session) {
      store <- reactiveValues(data = lapply(blocks, function(x) list(omicsData = x)))
      classes <- reactiveValues(data = list(labels = labels))
      env$mod_Advanced_server("advanced", store, store, classes)
    }, {
      inputs <- c(setNames(settings, paste0("advanced-", names(settings))),
        list(`advanced-method` = method, `advanced-blocks` = names(selected),
          `advanced-labels` = "labels", `advanced-study` = list(datapath = study_file),
          `advanced-comp1` = 1, `advanced-comp2` = 2, `advanced-plot_block` = names(selected)[1],
          `advanced-names` = FALSE, `advanced-ellipse` = FALSE, `advanced-size` = 1,
          `advanced-top` = 5, `advanced-cutoff` = 0.5, `advanced-row_names` = FALSE,
          `advanced-col_names` = FALSE, `advanced-transpose` = FALSE, `advanced-margin` = 5,
          `advanced-intra` = FALSE, `advanced-line` = TRUE, `advanced-feature_method` = "loadings"))
      do.call(session$setInputs, inputs)
      session$setInputs(`advanced-fit` = 1)
      stopifnot(grepl("Fitted", output$`advanced-status`))
      fitted_model <- readRDS(output$`advanced-model_rds`)
      # testServer does not apply updateSelectInput messages to browser inputs.
      session$setInputs(`advanced-plot_block` = names(fitted_model$model$loadings)[1])
      plots <- c("Scores", "Loadings", "Correlation circle")
      if (method %in% c("pls", "spls", "block.splsda")) plots <- c(plots, "CIM heatmap")
      if (method == "block.splsda") plots <- c(plots, "DIABLO", "Circos")
      for (plot in plots) {
        session$setInputs(`advanced-plot` = plot)
        image <- output$`advanced-figure`
        stopifnot(is.list(image), nzchar(image$src))
        file <- output$`advanced-plot_pdf`
        stopifnot(file.info(file)$size > 100, rawToChar(readBin(file, "raw", 4)) == "%PDF")
      }
      session$setInputs(`advanced-plot` = "Scores", `advanced-names` = TRUE, `advanced-ellipse` = TRUE)
      image <- output$`advanced-figure`
      stopifnot(is.list(image), nzchar(image$src))
      file <- output$`advanced-feature_tsv`
      table <- read.delim(file)
      stopifnot(nrow(table) > 0, all(is.finite(table$loading)))
      file <- output$`advanced-model_rds`
      stopifnot(identical(readRDS(file)$method, method))
    })
    ""
  }, error = conditionMessage)
  results[[method]] <- data.frame(method = method, status = if (nzchar(error)) "FAIL" else "PASS", error = error)
  cat(results[[method]]$status, "module plots/exports", method, error, "\n")
}
table <- do.call(rbind, results)
write.table(table, "/opt/Holomics/tests/advanced-output-results.tsv", sep = "\t", row.names = FALSE)
if (any(table$status == "FAIL")) quit(status = 1)
