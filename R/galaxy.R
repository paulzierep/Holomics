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
