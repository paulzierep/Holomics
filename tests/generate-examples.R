# Deterministic synthetic count/compositional blocks, preserving matched IDs.
root <- "/opt/Holomics/inst/extdata/three-omics"
set.seed(2702026)
for (block in c("transcriptomics", "proteomics", "metabolomics")) {
  original <- read.delim(file.path(root, paste0(block, ".tsv")), row.names = 1, check.names = FALSE)
  z <- scale(as.matrix(original))
  mu <- exp(3 + 0.4 * z)
  counts <- matrix(rnbinom(length(mu), mu = mu, size = 8), nrow = nrow(mu), dimnames = dimnames(mu))
  relative <- counts / rowSums(counts)
  for (type in c("counts", "relative")) {
    value <- if (type == "counts") counts else relative
    write.table(data.frame(sample_id = rownames(value), value, check.names = FALSE),
      file.path(root, type, paste0(block, ".tsv")), sep = "\t", quote = FALSE, row.names = FALSE)
  }
}
