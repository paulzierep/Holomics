analysis_tasks <- function() list(
  explore = list(title = "Explore samples", detail = "PCA: patterns, outliers and variation in one omics layer.", tab = "PCA"),
  associations = list(title = "Find adjusted feature associations", detail = "DA: compare groups while accounting for age, sex, batch or other covariates.", tab = "da"),
  signature = list(title = "Find a group-discriminating signature", detail = "PLS-DA: supervised multifeature patterns; independent validation is still needed.", tab = "PLSDA"),
  pairwise = list(title = "Connect two omics layers", detail = "sPLS: relationships between matched samples in two layers.", tab = "sPLS"),
  integration = list(title = "Integrate several omics layers", detail = "DIABLO: supervised integration and cross-layer signatures.", tab = "DIABLO"),
  studies = list(title = "Combine independent studies / expert methods", detail = "MINT and the full mixOmics catalog. Study information is required only for MINT.", tab = "advanced"))

project_home_ui <- function() {
  tagList(h2("What would you like to learn from your data?"),
    p(tags$strong("OmicsHarbor"), " — a multi-omics workspace by Paul Zierep, based on Holomics and powered by mixOmics and statistical analysis packages."),
    p("1. Load a complete example or import your project. 2. Check sample metadata. 3. Choose a question below."),
    uiOutput("project_readiness"),
    actionButton("project_data", "Project & data", icon = icon("upload")),
    fluidRow(lapply(names(analysis_tasks()), function(key) {
      task <- analysis_tasks()[[key]]
      column(4, bs4Dash::box(title = task$title, width = 12, p(task$detail),
        actionButton(paste0("task_", key), "Start this analysis")))
    })),
    tags$details(tags$summary("Workflow flowchart and step-by-step guide"), workflow_guide_ui()))
}

project_navigation_server <- function(input, session, output, single, metadata) {
  observeEvent(input$project_data, bs4Dash::updateTabItems(session, "main_navigation", "upload"))
  for (key in names(analysis_tasks())) local({
    task <- key
    observeEvent(input[[paste0("task_", task)]], {
      bs4Dash::updateTabItems(session, "main_navigation", analysis_tasks()[[task]]$tab)
    })
  })
  output$project_readiness <- renderUI({
    blocks <- single$data
    if (!length(blocks)) return(tags$div(class = "alert alert-info", "No data yet. Open Quick start → Load complete example, or Project & data to import your own tables."))
    meta <- metadata$data
    rows <- lapply(names(blocks), function(name) {
      x <- blocks[[name]]$omicsData
      ids <- rownames(x)
      aligned <- !is.null(meta) && !anyDuplicated(ids) && !anyDuplicated(rownames(meta)) && setequal(ids, rownames(meta))
      tags$tr(tags$td(name), tags$td(nrow(x)), tags$td(ncol(x)), tags$td(if (is.null(meta)) "Metadata not loaded" else if (aligned) "Sample IDs match" else "Sample IDs differ — reconcile before DA"))
    })
    tagList(h4("Project readiness"), tags$table(class = "table table-striped",
      tags$thead(tags$tr(lapply(c("Block", "Samples", "Features", "Metadata alignment"), tags$th))), tags$tbody(rows)),
      helpText("ID alignment is only the first check. Declare the measurement scale and preview the design before analysis; no automatic transformation is performed here."))
  })
}
