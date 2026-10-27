# Run inside the preview image: Rscript /opt/Holomics/tests/regression.R
library(Holomics)
library(shiny)
env <- new.env(parent = asNamespace("Holomics"))
for (file in list.files("/opt/Holomics/R", full.names = TRUE, pattern = "\\.R$")) sys.source(file, env)
Sys.unsetenv("HOLOMICS_INPUT_DIR")
directory <- system.file("extdata", "three-omics", package = "Holomics")
blocks <- lapply(c("transcriptomics", "proteomics", "metabolomics"), function(name)
  as.matrix(env$galaxy_read_table(file.path(directory, paste0(name, ".tsv")))))
names(blocks) <- c("transcriptomics", "proteomics", "metabolomics")
metadata <- env$galaxy_read_table(file.path(directory, "metadata.tsv"))
labels <- data.frame(sample = rownames(metadata), Group = metadata$Group)
results <- list()
check <- function(name, code) {
  started <- Sys.time()
  error <- tryCatch({ force(code); "" }, error = function(e) conditionMessage(e))
  results[[length(results) + 1L]] <<- data.frame(case = name, status = if (nzchar(error)) "FAIL" else "PASS",
    seconds = as.numeric(difftime(Sys.time(), started, units = "secs")), error = error)
  cat(if (nzchar(error)) "FAIL" else "PASS", name, error, "\n")
}
for (components in c(1, 2)) for (transpose in c(FALSE, TRUE)) {
  check(paste("sPLS CIM original+tuned", components, transpose), {
    model <- mixOmics::spls(blocks[[1]], blocks[[2]], ncomp = 2, keepX = c(5, 5), keepY = c(5, 5))
    shiny::testServer(function(input, output, session) {
      selection <- reactiveValues(dataX = blocks[[1]], dataY = blocks[[2]], dataXName = "transcripts", dataYName = "proteins")
      classes <- reactiveValues(data = labels)
      fit <- reactiveVal(model)
      env$generate_spls_plots(session$ns, input, output, selection, classes, fit, fit, reactiveValues(ncomp = 2))
    }, {
      session$setInputs(ncomp = 2, img.comp = components, img.comp.tuned = components,
        xmargin = 5, ymargin = 5, xmargin.tuned = 8, ymargin.tuned = 8,
        heatmap.rows = TRUE, heatmap.columns = TRUE, heatmap.transpose = transpose,
        heatmap.rows.tuned = FALSE, heatmap.columns.tuned = FALSE, heatmap.transpose.tuned = transpose)
      for (id in c("Img", "Img.tuned")) {
        image <- output[[id]]
        stopifnot(is.list(image), nzchar(image$src))
      }
      for (id in c("Img.download", "Img.download.tuned", "Img.table.download", "Img.table.download.tuned")) {
        file <- output[[id]]
        stopifnot(file.exists(file), file.info(file)$size > 100)
        if (grepl("table", id)) stopifnot(nrow(utils::read.csv2(file, row.names = 1)) > 0)
        else stopifnot(identical(readBin(file, "raw", 8), as.raw(c(137, 80, 78, 71, 13, 10, 26, 10))))
      }
    })
  })
}
for (nblocks in 2:3) for (components in c(1, 2)) {
  check(paste("DIABLO CIM original+tuned", nblocks, components), {
    model <- mixOmics::block.splsda(blocks[seq_len(nblocks)], labels$Group, ncomp = 2,
      keepX = lapply(blocks[seq_len(nblocks)], function(x) c(5, 5)))
    shiny::testServer(function(input, output, session) {
      selection <- reactiveValues(data = blocks[seq_len(nblocks)])
      classes <- reactiveValues(data = labels)
      fit <- reactiveVal(model)
      env$generate_diablo_plots(session$ns, input, output, selection, classes, fit, fit,
        reactiveValues(ncomp = 2), reactiveValues(), reactiveValues())
    }, {
      session$setInputs(ncomp = 2, img.comp = components, img.comp.tuned = components,
        xmargin = 5, ymargin = 5, xmargin.tuned = 5, ymargin.tuned = 5,
        heatmap.rows = FALSE, heatmap.columns = FALSE, heatmap.transpose = FALSE,
        heatmap.rows.tuned = FALSE, heatmap.columns.tuned = FALSE, heatmap.transpose.tuned = FALSE)
      # Read outputs explicitly: merely flushing does not verify lazy renderPlot outputs.
      for (id in c("Img", "Img.tuned")) {
        image <- output[[id]]
        stopifnot(is.list(image), nzchar(image$src))
      }
      for (id in c("Img.download", "Img.download.tuned", "Img.table.download", "Img.table.download.tuned")) {
        file <- output[[id]]
        stopifnot(file.exists(file), file.info(file)$size > 100)
        if (grepl("table", id)) stopifnot(nrow(utils::read.csv2(file, row.names = 1)) > 0)
        else stopifnot(identical(readBin(file, "raw", 8), as.raw(c(137, 80, 78, 71, 13, 10, 26, 10))))
      }
    })
  })
}
for (method in c("pca", "spls", "plsda", "block.spls", "block.plsda", "block.splsda")) {
  for (size in c(0.5, 1, 2)) check(paste("Correlation circle", method, size), {
    model <- switch(method,
      pca = mixOmics::pca(blocks[[1]], ncomp = 2),
      spls = mixOmics::spls(blocks[[1]], blocks[[2]], ncomp = 2),
      plsda = mixOmics::plsda(blocks[[1]], labels$Group, ncomp = 2),
      block.spls = mixOmics::block.spls(blocks[1:2], indY = 2, ncomp = 2),
      block.plsda = mixOmics::block.plsda(blocks[1:2], labels$Group, ncomp = 2),
      block.splsda = mixOmics::block.splsda(blocks[1:2], labels$Group, ncomp = 2))
    file <- tempfile(fileext = ".pdf")
    grDevices::pdf(file)
    tryCatch(env$plotVar(model, c(1, 2), TRUE, cex = size), finally = grDevices::dev.off())
    stopifnot(file.info(file)$size > 1000)
    unlink(file)
  })
}
report <- do.call(rbind, results)
utils::write.table(report, "/opt/Holomics/tests/regression-results.tsv", sep = "\t", row.names = FALSE, quote = TRUE)
if (any(report$status == "FAIL")) quit(status = 1)
