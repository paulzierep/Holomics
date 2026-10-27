# Dynamic output containers must not share ids with the inputs they contain.
library(Holomics)
library(shiny)
env <- new.env(parent = asNamespace("Holomics"))
for (file in list.files("/opt/Holomics/R", full.names = TRUE, pattern = "\\.R$")) sys.source(file, env)
shiny::testServer(function(input, output, session) {
  tuned <- reactiveValues(ncomp = 2)
  env$renderImgComp(session$ns, input, output, TRUE, tuned)
  env$renderLoadComp(session$ns, input, output, TRUE, tuned)
  env$renderSelVarComp(session$ns, input, output, TRUE, tuned)
}, {
  session$setInputs(ncomp = 2)
  for (name in c("img.comp", "load.comp", "load.ndisplay", "sel.var.comp")) for (postfix in c("", ".tuned")) {
    output_id <- paste0(name, ".ui", postfix)
    input_id <- session$ns(paste0(name, postfix))
    html <- output[[output_id]]$html
    stopifnot(grepl(paste0('id="', input_id, '"'), html, fixed = TRUE))
    stopifnot(!grepl(paste0('id="', session$ns(output_id), '"'), html, fixed = TRUE))
    cat("PASS separate dynamic container/input ids", output_id, "\n")
  }
})
