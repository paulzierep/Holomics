# OmicsHarbor — optional Galaxy integration

This document describes the enhanced **OmicsHarbor** development fork by
**Paul Zierep**, based on Holomics. The original modules and standalone launcher
remain available alongside the new workbenches. The internal package and
environment-variable prefix remain `Holomics` / `HOLOMICS_` for compatibility.
Input staging activates when `HOLOMICS_INPUT_DIR` is set by a Galaxy launcher.
The separately published minimal Holomics container uses
`galaxy-it-adaptations`, not this branch; its release does not deploy OmicsHarbor.

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
