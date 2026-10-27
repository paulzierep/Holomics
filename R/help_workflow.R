workflow_guide_ui <- function() {
  tagList(
    h2("Start here: choose your analysis"),
    p("Follow the shared preparation steps, then choose a branch based on your scientific question. You do not need to run every branch."),
    tags$img(src = "www/img/help/workflow.svg", alt = paste(
      "Workflow: load omics tables and sample metadata; match sample IDs and check measurement types;",
      "explore with PCA. Then choose covariate-adjusted DA, pairwise integration, multi-omics integration,",
      "or batch correction. Review validation and export. DA and DIABLO are complementary, not equivalent."),
      style = "width:100%;max-width:1400px;height:auto;display:block;margin:1rem auto;"),
    bs4Dash::box(title = "Try the three-omics example in five steps", width = 12,
      tags$ol(
         tags$li("Open Project & data and choose Continuous example, Raw counts example or Relative abundance example. Each loads three layers and matching sample metadata."),
         tags$li("Project & data → Sample metadata: review Group, age, sex, batch and subject_id; edit categorical/numeric types and reference levels if needed."),
        tags$li("Single-omics → PCA: select Example_transcriptomics and Example labels; fit two components and inspect scores/loadings."),
        tags$li("DA / statistics: choose continuous measurements, Linear model, Group as the variable of interest, Control as reference, and age/sex/batch as covariates. Preview the design; choose GroupTreatment_A; run."),
        tags$li("Multi-omics: inspect the DA overview, then separately fit DIABLO with the three Example_ blocks and Example labels. Compare integration patterns with DA effects without treating model-selected features as significant.")),
      helpText("Example measurements are already transformed continuous data: do not send them to DESeq2, edgeR, ANCOM-BC2 or ComBat-seq. Example subjects have one observation each: use a real repeated-measures dataset for random-effects analysis.")),
    bs4Dash::box(title = "Before interpreting a result", width = 12,
      tags$ul(tags$li("DA estimates adjusted feature associations. mixOmics describes latent structure or supervised discrimination. Neither alone proves causality."),
        tags$li("Covariates must be measured, aligned by sample ID and included intentionally. A perfectly confounded batch/treatment design cannot be rescued by correction."),
        tags$li("For prediction, split subjects/studies before fitting preprocessing, selecting features or tuning; report held-out performance, not training separation."),
        tags$li("Open Help → Worked examples for example plots, recommended settings, interpretation and limitations for every method family."))))
}
