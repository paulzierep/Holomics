# Keep controls aligned with the fitted number of components, including tuned fits.
render_circos_components <- function(ns, input, output, tunedVals) {
  for (postfix in c("", ".tuned")) local({
    suffix <- postfix
    output[[paste0("circos.components", suffix)]] <- shiny::renderUI({
      n <- if (suffix == "") input$ncomp else tunedVals$ncomp
      shiny::req(n, n >= 1)
      shiny::selectInput(paste0(ns("circos.components"), suffix),
        "Components contributing to associations", choices = seq_len(n),
        selected = seq_len(n), multiple = TRUE)
    })
  })
}
