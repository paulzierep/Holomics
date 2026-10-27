# Stabilization checkpoint — 2026-10-27

## Confirmed

- DA backend matrix: **65 populated successful fits**, **8 expected invalid
  CLR+LOG rejections**, **0 unexpected failures** (73 combinations).
- Rendering/export regression: **26 passed cases**, including original/tuned
  sPLS and DIABLO CIM, readable heatmap CSV exports and PNG signatures.
- Actual reactive tuning events: PCA, PLS-DA, sPLS and DIABLO produced fitted
  component selections. Separate sPLS/DIABLO runs rendered CIM from the actual
  tuned result, not a pre-fitted substitute.
- Boundary/design checks: four numeric endpoint combinations, eight invalid
  numeric values, 12-subject/three-observation mixed model, reference-effect
  inversion all passed. Input validation, nine distinct example blocks and
  repeated loader events also passed.
- Initial refreshed-browser run: all six loader/reloader checks and six DA
  run-button routes passed. DIABLO sample, loading, arrow and Circos plots
  rendered. Correlation selector ambiguity and CIM render timing require
  corrected browser-harness reruns; they are not counted as browser passes.

## Still pending

- Expanded browser campaign including all four tuning buttons, original/tuned
  plots and clicked downloads is in progress. Do not equate the backend/
  reactive counts above with browser coverage.
- All remaining controls, Advanced mixOmics methods, uploads/project restore,
  all cross-parameter interactions and multi-backend repeated measures need
  further systematic coverage.
- sPLS cross-validation emits SGCCA convergence warnings for some candidate
  fits. Actual tuned CIM renders, but candidate convergence is not certified.
- Live Galaxy delivery is unverified. No active Galaxy connection means
  send actions must be disabled or return an actionable message.
- An action-sampled headless video was created at
  `browser-evidence-v2/representative-clicks.mp4` (38.5 seconds). This is a
  screenshot-sequence video, not a real-time recording or exhaustive coverage.

## Browser-discovered follow-up

The expanded v2 run passed six loader checks, six DA run routes, six clicked
table downloads, and DIABLO sample/correlation-circle plots. It then stalled
on CIM. Inspection found duplicate output-container/input HTML IDs for the
dynamic CIM/component selectors. Container IDs now have `.ui` suffixes;
eight selector regression checks pass. The v3 browser campaign is rerunning
against the reinstalled preview. The v2 run was deliberately stopped, not
counted as a completed campaign.

The v3 run then passed **24 real-browser cases**: six example loader/reloader
checks, six DA fits, six clicked table downloads, and six DIABLO plots,
including **CIM**. It stopped at a harness-only sidebar locator before PCA;
the locator has been corrected and v4 is running. No claim of browser tuning
acceptance is made from v3.

### v4 follow-up (completed, not accepted)

v4 recorded 48 PASS / 8 FAIL, but its two tuning-to-CIM passes were not
specific to the tuned output and are **not acceptance evidence**. All four
tuned-parameter checks read hidden text inside collapsed panels. The PCA
screenshot confirms a reduced result with nine components; persistent
notifications also intercepted sPLS download clicks. DIABLO tuned downloads
remain unexplained pending a stricter rerun.

The v5 harness explicitly opens collapsed parameter panels, verifies the
component-budget value received by Shiny, navigates using each plot's exact
output ID (including `.tuned`), dismisses notifications via their close buttons,
and checks downloaded PNG signatures / readable CSV rows. A tuning-focused
campaign is running against the package reinstalled through `e61cc1e`.

### Advanced catalog backend sweep

The initial sweep passed 17/21 fits and exposed missing `indY` in four
continuous block methods. The implementation now explicitly uses the last
selected block as response Y and documents this convention in the UI.
The rerun passed **all 21 catalog fits**, with finite populated loadings and
fitted-model RDS round trips. MINT study assignments are synthetic stratified
fixtures: these test the software interface, not independent-cohort validity.
Catalog-wide reactive plot/PDF/table/model export tests are running separately.

That output sweep exposed a shared Scores renderer defect: it passed a raw
score matrix to mixOmics' model-dispatched `plotIndiv()`. Scores now render
the chosen fitted block's coordinates directly, with optional sample labels
and group ellipses. A sweep printed passes for all 21 plot/export cases but
ended with a parse error because its script was edited during execution; that
run is **not counted as a clean pass**. The unchanged final script is being
rerun. Do not edit running scripts, just as package installs/restarts must not
overlap active tests.

The final unchanged rerun completed successfully (exit 0): **21/21 backend
fits and 21/21 module plot/export cases passed**, including score labels and
group ellipses, all offered default plot types, PDF signatures, readable
loading TSVs and model RDS round trips. The 26 existing plot/export regression
cases and eight dynamic-selector checks also passed again. These are source-
based reactive tests; the live preview still has the pre-Advanced-fix package
until a safe reinstall after the active browser campaign.

### v5 browser follow-up

The stricter v5 run confirmed actual sPLS tuned CIM and clicked PNG/CSV exports,
and visible fitted parameters for PCA/PLS-DA/sPLS. Four component-budget checks
used the wrong client-side typed-input key despite correctly changing the
visible numeric control. DIABLO's dataset selector had become empty before
tuning, so its tuned checks are not accepted. v6 reads the typed input key
correctly and explicitly reselects DIABLO blocks before its original/tuned
checks. This run is still pending, not counted as completed acceptance.

Tuned-state checks now explicitly cover changed data, component counts, sPLS
mode and DIABLO coupling as well as scaling and class labels; all pass.

## Execution caveats

Two attempted test launches overlapped package installation and failed loading
the transient staged package; those are not counted. Another run was killed
with exit 137 during a container restart; it is not counted. The completed
73-case rerun supersedes these interrupted runs. Never install/restart during
active tests.

The image dependency installer in the microbiome-ITs packaging workspace has
also been updated locally to pin nanonext 1.7.0 / mirai 2.5.0; that separate
workspace change is not part of the Holomics fork commit.
