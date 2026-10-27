# Galaxy integration is inactive unless the launcher supplies an input directory.
galaxy_enabled <- function() nzchar(Sys.getenv("HOLOMICS_INPUT_DIR"))

galaxy_workers <- function() {
  slots <- suppressWarnings(as.integer(Sys.getenv("GALAXY_SLOTS", "1")))
  if (nzchar(Sys.getenv("GALAXY_SLOTS"))) {
    if (is.na(slots) || slots < 1L) 1L else slots
  } else {
    max(1L, parallel::detectCores() - 1L, na.rm = TRUE)
  }
}

galaxy_read_table <- function(path, separator = "tab", transpose = FALSE) {
  sep <- switch(separator, tab = "\t", comma = ",", semicolon = ";")
  data <- utils::read.table(path, header = TRUE, sep = sep, check.names = FALSE,
                            stringsAsFactors = FALSE, comment.char = "", quote = "\"")
  if (ncol(data) < 2L || !nrow(data)) stop("Expected sample IDs and at least one data column")
  ids <- as.character(data[[1]])
  if (anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids)) stop("Missing or duplicate IDs")
  data <- data[, -1, drop = FALSE]
  if (anyDuplicated(names(data))) stop("Duplicate column identifiers")
  rownames(data) <- ids
  if (transpose) data <- as.data.frame(t(data))
  data
}

galaxy_import <- function(manifest, single, multi, single_classes, multi_classes, tables) {
  blocks <- manifest$blocks
  names_seen <- vapply(blocks, function(x) x$name, character(1))
  if (anyDuplicated(names_seen)) stop("Omics block names must be unique")
  # Validate everything before mutating the reactive stores.
  datasets <- lapply(blocks, function(block) {
    data <- galaxy_read_table(block$path, block$separator, isTRUE(block$transpose))
    if (!all(vapply(data, is.numeric, logical(1))) || any(!is.finite(as.matrix(data))))
      stop("Omics blocks must contain finite numeric measurements: ", block$name)
    if (ncol(data) < 2L || nrow(data) < 3L) stop("Need at least 3 samples and 2 features")
    if (!nzchar(block$name)) stop("Block names cannot be empty")
    list(omicsData = data, name = block$name)
  })
  classes <- NULL
  if (!is.null(manifest$labels)) {
    metadata <- galaxy_read_table(manifest$labels$path, manifest$labels$separator)
    if (ncol(metadata) != 1L || anyNA(metadata[[1]]))
      stop("Baseline labels need exactly two columns: sample ID and class")
    classes <- data.frame(sample = rownames(metadata), class = as.character(metadata[[1]]),
                          stringsAsFactors = FALSE)
    names(classes)[2] <- names(metadata)[1]
  }
  # Original modules consume rows positionally: align explicitly without dropping samples.
  canonical <- if (!is.null(classes)) classes[[1]] else if (length(datasets)) rownames(datasets[[1]]$omicsData) else character()
  for (i in seq_along(datasets)) {
    ids <- rownames(datasets[[i]]$omicsData)
    if (!setequal(ids, canonical))
      stop("Sample sets differ in ", blocks[[i]]$name,
           "; baseline Galaxy import requires matching samples in all tables and labels")
    datasets[[i]]$omicsData <- datasets[[i]]$omicsData[match(canonical, ids), , drop = FALSE]
  }
  for (i in seq_along(blocks)) {
    block <- blocks[[i]]
    single$data[[block$name]] <- datasets[[i]]
    # Direct multi-omics import requires an explicit already-prepared declaration.
    if (isTRUE(block$prepared)) multi$data[[block$name]] <- datasets[[i]]
    tables$data <- extendDataTable(tables$data, block$name, basename(block$path),
      nrow(datasets[[i]]$omicsData), ncol(datasets[[i]]$omicsData), FALSE,
      if (isTRUE(block$prepared)) "both" else "single", block$name)
  }
  if (!is.null(classes)) {
    label_name <- if (is.null(manifest$label_name)) "Galaxy labels" else manifest$label_name
    single_classes$data[[label_name]] <- classes
    multi_classes$data[[label_name]] <- classes
    tables$classes <- extendClassTable(tables$classes, label_name, "labels", nrow(classes), FALSE)
  }
  invisible(NULL)
}

galaxy_atomic_save <- function(state, path) {
  tmp <- paste0(path, ".tmp")
  saveRDS(state, tmp)
  if (!file.rename(tmp, path)) stop("Could not save project checkpoint")
}

galaxy_publish <- function(path, filename) {
  directory <- Sys.getenv("HOLOMICS_OUTPUT_DIR")
  dir.create(directory, showWarnings = FALSE, recursive = TRUE)
  filename <- gsub("[^A-Za-z0-9_.-]", "_", basename(filename))
  destination <- file.path(directory, paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", filename))
  if (file.exists(destination)) destination <- file.path(directory, paste0(basename(tempfile()), "_", filename))
  if (!file.copy(path, destination)) stop("Could not stage export")
  # Upload in a separate process; the discovered collection is the offline fallback.
  helper <- Sys.which("python")
  script <- system.file("galaxy", "upload.py", package = "Holomics")
  if (nzchar(Sys.getenv("API_KEY")) && nzchar(helper)) {
    system2(helper, c(shQuote(script), shQuote(destination)), wait = FALSE,
            stdout = file.path(dirname(directory), "holomics_upload.log"),
            stderr = file.path(dirname(directory), "holomics_upload.log"))
  }
  invisible(destination)
}

# Called by every existing export handler: browser downloads remain available.
galaxy_capture_download <- function(file, filename) {
  if (galaxy_enabled()) galaxy_publish(file, filename)
}

galaxy_ui <- function() {
  bs4Dash::box(title = "Quick start", width = 12, collapsed = TRUE,
    shiny::helpText("Choose Continuous, Raw counts or Relative abundance under Project & data. Each loads a complete synthetic example with matching metadata. Synthetic examples are for learning, not biological evidence."),
    shiny::textOutput("galaxy_status"),
    shiny::helpText("After loading, select the Example_ blocks and Metadata labels in an analysis tab."))
}

galaxy_server <- function(single, multi, single_classes, multi_classes, tables, input, output, metadata = NULL) {
  status <- shiny::reactiveVal("")
  output$galaxy_status <- shiny::renderText(status())
  if (!galaxy_enabled()) return(invisible(NULL))
  shiny::observeEvent(TRUE, {
    tryCatch({
      project <- file.path(Sys.getenv("HOLOMICS_INPUT_DIR"), "project.rds")
      if (file.exists(project)) {
        state <- readRDS(project)
        if (!identical(state$format, "Holomics-Galaxy-1")) stop("Unrecognized project format")
        single$data <- state$single; multi$data <- state$multi
        single_classes$data <- state$single_classes; multi_classes$data <- state$multi_classes
        tables$data <- state$data_table; tables$classes <- state$class_table
      } else {
        manifest <- file.path(Sys.getenv("HOLOMICS_INPUT_DIR"), "manifest.json")
        if (file.exists(manifest)) galaxy_import(jsonlite::fromJSON(manifest, simplifyVector = FALSE),
          single, multi, single_classes, multi_classes, tables)
      }
      status(paste("Galaxy inputs ready:", length(single$data), "omics blocks"))
    }, error = function(e) status(paste("Galaxy import failed:", conditionMessage(e))))
  }, once = TRUE)
  state <- shiny::reactive(list(format = "Holomics-Galaxy-1", single = single$data,
    multi = multi$data, single_classes = single_classes$data, multi_classes = multi_classes$data,
    data_table = tables$data, class_table = tables$classes))
  shiny::observe({
    value <- state()
    if (!is.null(value$data_table)) {
      tryCatch(galaxy_atomic_save(value, Sys.getenv("HOLOMICS_PROJECT_OUTPUT")),
        error = function(e) status(paste("Checkpoint failed:", conditionMessage(e))))
    }
  })
  shiny::observeEvent(input$galaxy_send_project, {
    galaxy_atomic_save(state(), Sys.getenv("HOLOMICS_PROJECT_OUTPUT"))
    galaxy_publish(Sys.getenv("HOLOMICS_PROJECT_OUTPUT"), "holomics_project.rds")
    shiny::showNotification("Project staged for Galaxy; direct upload started if connected.")
  })
  output$galaxy_status <- shiny::renderText(status())
}
