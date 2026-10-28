# Respect Galaxy's CPU allocation instead of detecting all host CPUs. A
# one-slot job must not start socket workers (container hostnames may not resolve).
galaxy_parallel_param <- function() {
  slots <- Sys.getenv("GALAXY_SLOTS")
  if (nzchar(slots)) {
    workers <- suppressWarnings(as.integer(slots))
    if (is.na(workers) || workers <= 1L) return(BiocParallel::SerialParam())
    return(BiocParallel::SnowParam(workers = workers, type = "SOCK", manager.hostname = "127.0.0.1"))
  }
  BiocParallel::SnowParam(workers = max(1L, parallel::detectCores() - 1L, na.rm = TRUE))
}

# Load launcher inputs into the original application's reactive data stores.
galaxy_read_table <- function(path, separator = "tab", transpose = FALSE) {
  sep <- switch(separator, tab = "\t", comma = ",", semicolon = ";",
                stop("Unsupported table separator"))
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
  block_names <- vapply(blocks, function(x) x$name, character(1))
  if (any(!nzchar(block_names)) || anyDuplicated(block_names)) stop("Omics block names must be unique and nonempty")
  # Validate all inputs before changing the original application's data stores.
  datasets <- lapply(blocks, function(block) {
    data <- galaxy_read_table(block$path, block$separator, isTRUE(block$transpose))
    if (!all(vapply(data, is.numeric, logical(1))) || any(!is.finite(as.matrix(data))))
      stop("Omics blocks must contain finite numeric measurements: ", block$name)
    if (ncol(data) < 2L || nrow(data) < 3L) stop("Need at least 3 samples and 2 features")
    list(omicsData = data, name = block$name)
  })
  classes <- NULL
  if (!is.null(manifest$labels)) {
    metadata <- galaxy_read_table(manifest$labels$path, manifest$labels$separator)
    if (ncol(metadata) != 1L || anyNA(metadata[[1]]) || any(!nzchar(as.character(metadata[[1]]))))
      stop("Labels need exactly two columns: sample ID and nonempty class")
    classes <- data.frame(sample = rownames(metadata), class = as.character(metadata[[1]]),
                          stringsAsFactors = FALSE)
    names(classes)[2] <- names(metadata)[1]
  }
  canonical <- if (!is.null(classes)) classes[[1]] else if (length(datasets)) rownames(datasets[[1]]$omicsData) else character()
  for (i in seq_along(datasets)) {
    ids <- rownames(datasets[[i]]$omicsData)
    if (!setequal(ids, canonical)) stop("Sample sets differ in ", blocks[[i]]$name,
      "; Galaxy inputs require matching samples across all tables and labels")
    datasets[[i]]$omicsData <- datasets[[i]]$omicsData[match(canonical, ids), , drop = FALSE]
  }
  for (i in seq_along(blocks)) {
    block <- blocks[[i]]
    single$data[[block$name]] <- datasets[[i]]
    if (isTRUE(block$prepared)) multi$data[[block$name]] <- datasets[[i]]
    tables$data <- extendDataTable(tables$data, block$name, basename(block$path),
      nrow(datasets[[i]]$omicsData), ncol(datasets[[i]]$omicsData), FALSE,
      if (isTRUE(block$prepared)) "both" else "single", block$name)
  }
  if (!is.null(classes)) {
    single_classes$data[["Galaxy labels"]] <- classes
    multi_classes$data[["Galaxy labels"]] <- classes
    tables$classes <- extendClassTable(tables$classes, "Galaxy labels", "labels", nrow(classes), FALSE)
  }
  invisible(NULL)
}

galaxy_import_server <- function(single, multi, single_classes, multi_classes, tables) {
  directory <- Sys.getenv("HOLOMICS_INPUT_DIR")
  if (!nzchar(directory)) return(invisible(NULL))
  shiny::observeEvent(TRUE, {
    manifest <- file.path(directory, "manifest.json")
    if (!file.exists(manifest)) return(invisible(NULL))
    tryCatch({
      galaxy_import(jsonlite::fromJSON(manifest, simplifyVector = FALSE),
        single, multi, single_classes, multi_classes, tables)
      shiny::showNotification(paste("Galaxy inputs loaded:", length(single$data), "omics blocks"),
                              type = "message", duration = 10)
    }, error = function(e) {
      shiny::showNotification(paste("Galaxy import failed:", conditionMessage(e)),
                              type = "error", duration = NULL)
    })
  }, once = TRUE)
}

# Keep the original browser downloads; stage an additional copy only in Galaxy.
galaxy_capture_download <- function(file, filename) {
  directory <- Sys.getenv("HOLOMICS_OUTPUT_DIR")
  if (!nzchar(directory)) return(invisible(NULL))
  tryCatch({
    dir.create(directory, showWarnings = FALSE, recursive = TRUE)
    filename <- gsub("[^A-Za-z0-9_.-]", "_", basename(filename))
    destination <- file.path(directory, paste0(basename(tempfile("export_")), "_", filename))
    if (!file.copy(file, destination)) stop("Could not stage Galaxy export")
    python <- Sys.which("python3")
    script <- system.file("galaxy", "upload.py", package = "Holomics")
    if (nzchar(Sys.getenv("API_KEY")) && nzchar(python) && nzchar(script)) {
      log <- file.path(dirname(directory), "holomics_upload.log")
      system2(python, c(shQuote(script), shQuote(destination)), wait = FALSE,
              stdout = log, stderr = log)
    }
    invisible(destination)
  }, error = function(e) {
    warning("Galaxy export failed; browser download is still available: ", conditionMessage(e))
    invisible(NULL)
  })
}
