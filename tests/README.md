# Stabilization checks

Run against the DA-enabled preview container with this checkout mounted at
`/opt/Holomics`. Never install the package or restart the container while tests
are running. Source-based tests do not certify the installed running app.

```bash
docker exec omicsharbor Rscript /opt/Holomics/tests/validation.R
docker exec omicsharbor Rscript /opt/Holomics/tests/da-boundaries.R
docker exec omicsharbor Rscript /opt/Holomics/tests/da-matrix.R
docker exec omicsharbor Rscript /opt/Holomics/tests/regression.R
docker exec omicsharbor Rscript /opt/Holomics/tests/ui-identifiers.R
docker exec -e TEST_METHOD=PCA omicsharbor Rscript /opt/Holomics/tests/tuning.R
docker exec -e TEST_METHOD=PLSDA omicsharbor Rscript /opt/Holomics/tests/tuning.R
docker exec -e TEST_METHOD=sPLS omicsharbor Rscript /opt/Holomics/tests/tuning.R
docker exec -e TEST_METHOD=DIABLO omicsharbor Rscript /opt/Holomics/tests/tuning.R
python3 tests/browser_routes.py
```

- `da-matrix.R`: 73 combinations: 65 fitted analyses and eight explicit
  rejections of CLR + LOG. Finite options are crossed for limma, edgeR,
  ComBat, DESeq2, ANCOM-BC2, and MaAsLin3, on one block per measurement type.
- `da-boundaries.R`: prevalence/FDR endpoints and invalid values, real
  repeated-measures mixed-model fixture, reference-effect inversion.
- `validation.R`: mismatched samples/scales, missing/confounded metadata,
  formula safety, all nine example blocks, repeated loader events.
- `regression.R`: 26 cases. Eight original/tuned CIM cases assert rendered
  images, PNG signatures and readable CSVs; 18 correlation-circle cases
  cover six model classes and three symbol sizes. These use pre-fitted models.
- `tuning.R`: actual module tuning event; sPLS/DIABLO also read the resulting
  tuned CIM output. These are reactive-server tests, not browser clicks.
- `ui-identifiers.R`: verifies eight original/tuned dynamic selector outputs
  use container IDs distinct from their nested inputs. Real-browser tests
  remain necessary: server output tests alone missed the duplicate-ID bug.
- `browser_routes.py`: headless real-button/navigation/download campaign;
  select inputs use the widget API. Screenshots, control inventory, logs and
  per-case results are retained under ignored `browser-evidence*/` directories.
  Frames are an action-sampled record, not a real-time screen recording.

## Known coverage limits

This suite is not an exhaustive certification of every UI control. Advanced
mixOmics routes, all plot-specific interactions, browser uploads/project
restore, Galaxy delivery, and all invalid/repeated-measures backend combinations
need further coverage. A backend pass is not a browser pass. Convergence
warnings from sPLS cross-validation remain relevant and must not be interpreted
as successful convergence of every candidate fit.

The preview's pinned MaAsLin3 needs `mirai >= 2.5.0` (`info()`); the older CRAN
snapshot has 2.2.0. `install-preview-dependencies.R` provides pinned compatible
sources for repairing that preview. The image dependency installer must carry
the same pins for reproducible rebuilds.
