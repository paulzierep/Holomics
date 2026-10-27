#' The application server-side
#' 
#' @param input,output,session Internal parameters for {shiny}. 
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function( input, output, session ) {
  # Your application server logic 
  singleomicsData <- reactiveValues(data = list())
  multiomicsData <- reactiveValues(data = list())
  singleomicsClasses <- reactiveValues(data = list())
  multiomicsClasses <- reactiveValues(data = list())
  
  tables <- reactiveValues(data = NULL, classes = NULL)
  metadata <- reactiveValues(data = NULL, references = list())
  da_results <- reactiveValues(data = list())
  
  
  mod_Upload_server("upload", singleomicsData, singleomicsClasses, multiomicsData, multiomicsClasses, tables, metadata)
  galaxy_server(singleomicsData, multiomicsData, singleomicsClasses, multiomicsClasses, tables, input, output, metadata)

  auto_labels <- function() {
    if (is.null(metadata$data)) return(invisible(NULL))
    md <- metadata$data
    if (!nrow(md)) return(invisible(NULL))
    choices <- names(md)
    candidate <- if ("Group" %in% choices) "Group" else choices[1]
    x <- md[[candidate]]
    if (is.factor(x)) x <- as.character(x)
    if (!is.character(x) || anyNA(x)) return(invisible(NULL))
    classes <- data.frame(sample = rownames(md), value = x, stringsAsFactors = FALSE)
    names(classes)[2] <- candidate
    label_name <- "Metadata labels"
    singleomicsClasses$data[[label_name]] <- classes
    multiomicsClasses$data[[label_name]] <- classes
    tryCatch({
      if (is.null(tables$classes) || nrow(tables$classes) == 0 || !"Metadata labels" %in% as.character(tables$classes[, 1])) {
        tables$classes <- extendClassTable(tables$classes, label_name, "metadata", nrow(classes), FALSE)
      }
    }, error = function(e) NULL)
    invisible(NULL)
  }
  observe({ auto_labels() }, priority = -10)
  
  mod_PLSDA_server("PLSDA", singleomicsData, singleomicsClasses, multiomicsData, tables)
  mod_PCA_server("PCA", singleomicsData, singleomicsClasses, multiomicsData, tables)
  
  mod_sPLS_server("sPLS", data = multiomicsData, classes = multiomicsClasses)
  mod_DIABLO_server("DIABLO", data = multiomicsData, classes = multiomicsClasses)
  mod_Advanced_server("advanced", singleomicsData, multiomicsData, singleomicsClasses)
  mod_Metadata_server("metadata", metadata, singleomicsClasses, multiomicsClasses, tables)
  mod_DA_server("da", singleomicsData, metadata, da_results)
  mod_DAOverview_server("da_overview", da_results)
  project_navigation_server(input, session, output, singleomicsData, metadata)
}
