# Keep statistical associations separate from latent-variable selection.
mod_DAOverview_ui <- function(id) {
  ns <- NS(id)
  bs4Dash::box(title = "DA results overview (separate from DIABLO selection)", width = 12,
    helpText("Run analyses in DA / statistics for each omics block. Saved results appear here alongside, not inside, DIABLO plots. DA significance does not imply a DIABLO association, and DIABLO selection does not imply DA significance. Running DA does not filter or refit the integration model."),
    DT::dataTableOutput(ns("summary")),
    selectInput(ns("analysis"), "Inspect completed analysis", NULL),
    selectInput(ns("table"), "Result table", NULL),
    DT::dataTableOutput(ns("results")),
    plotOutput(ns("effects"), height = "450px"))
}

mod_DAOverview_server <- function(id, results) {
  moduleServer(id, function(input, output, session) {
    observe({ updateSelectInput(session, "analysis", choices = names(results$data), selected = isolate(input$analysis)) })
    output$summary <- DT::renderDataTable({
      if (!length(results$data)) return(data.frame(Status = "No DA analyses yet. Load sample metadata and run DA / statistics."))
      do.call(rbind, lapply(results$data, function(value) data.frame(
        block = value$block, method = value$settings$method, formula = value$settings$formula,
        samples = length(value$sample_ids), features = length(value$tested_features), completed = value$completed)))
    }, rownames = FALSE, options = list(scrollX = TRUE))
    analysis <- reactive({ req(input$analysis); results$data[[input$analysis]] })
    observe({ req(analysis()); updateSelectInput(session, "table", choices = names(analysis()$tables), selected = names(analysis()$tables)[1]) })
    table <- reactive({ req(analysis(), input$table); analysis()$tables[[input$table]] })
    output$results <- DT::renderDataTable(table(), options = list(scrollX = TRUE))
    output$effects <- renderPlot({
      x <- table()
      validate(need(all(c("feature", "effect", "q_value") %in% names(x)), "Native result table shown above; effect plot is available for standard coefficient results."))
      x <- x[is.finite(x$effect) & is.finite(x$q_value), , drop = FALSE]
      validate(need(nrow(x) > 0, "No finite effect estimates"))
      x <- head(x[order(x$q_value), , drop = FALSE], 20)
      graphics::par(mar = c(5, 10, 3, 1))
      graphics::barplot(rev(x$effect), names.arg = rev(x$feature), horiz = TRUE, las = 1,
        col = rev(ifelse(x$q_value <= analysis()$settings$alpha, "firebrick", "grey70")),
        xlab = "Adjusted model effect (backend scale)", main = "Top 20 tested features; red = passes fitted FDR threshold")
    })
  })
}
