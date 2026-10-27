# Reproducible dependency repair for the existing DA-enabled preview image.
# mirai 2.5.0 introduced info(), required by the pinned MaAsLin3 1.5.8.
options(repos = c(CRAN = "https://cloud.r-project.org"))
remotes::install_version("nanonext", version = "1.7.0", upgrade = "never")
remotes::install_version("mirai", version = "2.5.0", upgrade = "never")
stopifnot("info" %in% getNamespaceExports("mirai"))
