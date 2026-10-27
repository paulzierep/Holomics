# Galaxy Interactive Tool baseline

This branch preserves the original Holomics analysis modules and standalone
launcher. The optional integration activates only when `HOLOMICS_INPUT_DIR`
is set by the Galaxy container launcher.

- `manifest.json` in that directory describes omics blocks and optional labels.
  Each block has `name`, `path`, `separator` (`tab`, `comma`, `semicolon`),
  `transpose` and `prepared` fields.
- Import validates finite numeric measurements and unique identifiers, requires
  matching sample sets, and reorders rows by sample ID. It does not normalize,
  filter or silently intersect the staged measurements.
- Already-prepared blocks may be made available in the original multi-omics
  store. Other blocks follow the original single-omics reduction workflow.
- Existing downloads also stage a copy in `HOLOMICS_OUTPUT_DIR` and attempt
  background upload to the current Galaxy history. Browser downloads still work.
- The data workspace is checkpointed atomically to `HOLOMICS_PROJECT_OUTPUT`.
  Restore it by staging the file as `HOLOMICS_INPUT_DIR/project.rds` on launch.
  Imported/reduced datasets and labels are preserved; fitted models and UI
  settings are not serialized in this baseline.
- Parallel tuning respects `GALAXY_SLOTS` when set.

The packaging, fixtures and regression tests live in
`usegalaxy-eu/microbiome-ITs/holomics/`.
