# Worked examples and plot gallery

These plots are **real computations on the bundled synthetic three-omics dataset**, not biological findings or evidence of predictive accuracy. The examples illustrate interpretation, not expected results for your study. Default feature counts and penalties below are starting points, **not tuned recommendations**. Package availability and method-specific plot support vary; an installed backend is not a guarantee that a model is suitable.

## Quick start and input selection

1. Open **Quick start → Load complete example**. This loads the three layers, labels and covariate metadata together. If metadata or Example_ blocks already exist, confirm replacement first; other blocks are retained.
2. In **Project & data → Sample metadata**, review column types and reference levels. Use **Apply metadata types and references** to save edits. For your own data, **Use as class labels** makes a metadata column available to PCA / PLS-DA / DIABLO without a second upload.
3. Choose the `Example_` blocks and **Example labels** in legacy analysis tabs. In DA, choose the metadata column `Group` instead of the legacy class table.
4. The example contains 36 samples: 12 Control, 12 Treatment_A, 12 Treatment_B; 60 transcript, 40 protein and 30 metabolite features.

| Your input | Suitable starting points | Do not do this |
|---|---|---|
| Raw non-negative integer counts | DESeq2 / edgeR; microbiome counts: ANCOM-BC2 or MaAsLin3 | Round transformed measurements into counts |
| Microbiome relative abundances (fractions summing to 1) | MaAsLin3 with explicit normalization/transformation | Treat fractions as raw counts |
| Continuous, appropriately transformed measurements | PCA, PLS families, limma, linear/mixed models | Automatically log already-log-transformed data |
| Batch-affected data | Prefer batch as a DA covariate; consider explicit ComBat / ComBat-seq preprocessing | Correct a perfectly confounded batch/treatment design or leak outcome-preserving correction into predictive evaluation |

**The bundled measurements are continuous, already transformed demo values.** They are not valid count-method examples. The bundled `subject_id` has one observation per subject; it is not a repeated-measures example.

## 1. PCA / sparse PCA: explore one layer

**Question:** What are the strongest variation patterns, and are there unusual samples?

**Try:** Single-omics → PCA → `Example_transcriptomics`, **Example labels**, two components, scale enabled. Inspect scores, scree and loadings. In Advanced mixOmics use `pca` or `spca`; for `spca`, try `keepX = 6,6` as an illustration. The legacy reduction workflow provides its own tuning.

<img src="www/img/help/pca.png" alt="PCA scores computed from synthetic transcriptomics, coloured by three classes" style="max-width:100%;width:850px"/>
<img src="www/img/help/scree.png" alt="Scree plot showing explained variance for the first ten principal components" style="max-width:100%;width:850px"/>

**Read the plots:** nearby samples have similar component scores. A large first component may reflect biology, batch or technical variation; investigate metadata. Scree values describe explained variance, not classification accuracy. There is no universal 80% rule for choosing components. Sparse PCA retains a subset of features; non-zero loadings are **not p-values**.

## 2. PLS-DA / sPLS-DA: supervised discrimination

**Question:** Which latent signatures distinguish known classes?

**Try:** Single-omics → PLS-DA → one Example block + Example labels. For a manual sparse fit choose Advanced → `splsda`, one block, Example labels, two components and `keepX = 6,6`. `plsda` retains a dense signature; `splsda` selects features. Keep model-selected features separate from DA significance.

<img src="www/img/help/plsda.png" alt="Sparse PLS-DA training scores; class separation is not a validation result" style="max-width:100%;width:850px"/>
<img src="www/img/help/loadings.png" alt="Six non-zero loadings on component one of the synthetic sparse PLS-DA fit" style="max-width:100%;width:850px"/>

**Read the plots:** class labels were used during fitting, so clean training separation is not independent evidence of prediction. Loading magnitude measures contribution to a component; its sign depends on arbitrary component orientation. Tune on training folds and evaluate on held-out subjects. Feature selection outside cross-validation causes leakage.

## 3. PLS / sPLS: connect two layers

**Question:** Which transcript and protein patterns vary together, or can X predict Y?

**Try:** Pairwise → `Example_transcriptomics` as X and `Example_proteomics` as Y. Alternatively Advanced → `spls`, exactly these two blocks, two components, `keepX = 6,6`, `keepY = 6,6`, **canonical** mode for symmetric association. Use **regression** mode for an X-to-Y question; block selection order matters. `pls` is the dense counterpart.

<img src="www/img/help/pairwise.png" alt="Two-layer sparse PLS correlation circle" style="max-width:100%;width:850px"/>
<img src="www/img/help/pairwise-cim.png" alt="Pairwise clustered image map of model-based feature associations" style="max-width:100%;width:850px"/>

**Read the plots:** features close on the correlation circle have similar component relationships; distance from the origin indicates representation on those components. The pairwise CIM shows model-derived associations, **not sample expression or adjusted DA p-values**. Cutoffs control displayed associations, not FDR.

## 4. DIABLO: integrate three layers with classes

**Question:** Which cross-layer signature distinguishes the classes while connecting omics blocks?

**Try:** Multi-omics → choose all three Example blocks and Example labels; start with two components. Set a modest design coupling such as 0.1, and examine the design before tuning. For a quick manual illustration use Advanced → `block.splsda`, two components, `keepX = 6,6`, coupling 0.1. This keeps six features per component **in each block**. Different per-block counts can be set in advanced keepX JSON.

<img src="www/img/help/diablo.png" alt="DIABLO component-one score agreement across three synthetic omics blocks" style="max-width:100%;width:850px"/>
<img src="www/img/help/diablo-cim.png" alt="DIABLO clustered image map of selected feature expression across samples" style="max-width:100%;width:850px"/>
<img src="www/img/help/circos.png" alt="Circos links between model-selected features at absolute association cutoff 0.7" style="max-width:100%;width:850px"/>
<img src="www/img/help/arrows.png" alt="Sample arrows illustrating agreement between the three block score representations" style="max-width:100%;width:850px"/>

**Read the plots:** DIABLO score panels show block-level agreement. Unlike pairwise CIM, DIABLO CIM displays selected feature expression across samples. Circos links are model-based associations above a cutoff; they are neither causal links nor significance tests. Short sample arrows indicate stronger agreement between block score representations. Change components, association cutoff, labels and plot size to reduce clutter; use **Expand plot** for larger figures.

**Where DA appears:** the Multi-omics **DA results overview** lists completed DA analyses and provides separate effect plots for standardized coefficient result tables. It does not overlay significance on Circos or automatically filter/refit DIABLO. A feature can be DA-significant without being selected by DIABLO, and vice versa.

## 5. Advanced mixOmics: method chooser

This table covers every fitting method exposed in the Advanced workspace. Shared plots above illustrate the relevant family; not every generic plot applies to every class. An explanatory message is preferable to forcing an incompatible plot.

| Methods | Required data and example | Important settings / interpretation |
|---|---|---|
| `pca`, `spca` | One block; Example_transcriptomics | Center/scale, components; sparse keepX. See PCA and scree above. |
| `ipca`, `sipca` | One continuous block; Example_transcriptomics | ICA nonlinearity, deflation/parallel, tolerance/iterations; sipca keepX. Independent components are not ranked/validated like class predictions. |
| `pls`, `spls` | Exactly two aligned blocks; transcriptomics + proteomics | Regression vs canonical mode; sparse keepX/keepY. See pairwise circle/CIM. |
| `plsda`, `splsda` | One block + class labels | Components, scale, sparse keepX. See training scores/loadings above. |
| `rcc` | Exactly two continuous blocks | Ridge/shrinkage and penalties; ridge example below uses lambda1=lambda2=0.1. Penalties require tuning for an inferential/predictive application. |
| `block.pls`, `block.spls` | Two or more continuous X blocks | Design coupling, scheme, initialization; sparse per-block keepX. These multiblock X fits need no class labels; do not interpret them as class discrimination. |
| `block.plsda`, `block.splsda` | Two or more blocks + classes | Dense/sparse supervised integration; DIABLO is the sparse family illustrated above. |
| `mint.pls`, `mint.spls` | Two blocks + study table | Study-aware paired integration; scale/mode and sparse keepX/keepY. Requires multiple studies with adequate samples. |
| `mint.plsda`, `mint.splsda` | One block + labels + study table | Each study must contain all classes with adequate replication. Validate by leaving studies out; training scores are not cross-study performance. |
| `mint.block.pls`, `mint.block.spls` | Multiple X blocks + study table | Study-aware multiblock integration; design, scheme and sparse keepX. |
| `mint.block.plsda`, `mint.block.splsda` | Multiple blocks + labels + study table | Study-aware supervised multiblock integration. Keep study and class distinct; a study/class confounding cannot be solved by more components. |

<img src="www/img/help/ica.png" alt="Independent PCA scores on the bundled synthetic transcriptomics" style="max-width:100%;width:850px"/>
<img src="www/img/help/rcca.png" alt="Regularised canonical correlation example with ridge penalties of 0.1" style="max-width:100%;width:850px"/>

**MINT input example:** a tab-delimited table with `sample_id` and `study` columns. Use actual cohort/study membership, not a randomly assigned label. The default three-omics fixture does not contain independent cohorts, so the gallery does not present it as a validated MINT benchmark.

## 6. DA with covariates: test features, not latent components

**Question:** Is each feature associated with treatment after adjusting for age, sex and batch?

**Try on the bundled data:** DA / statistics → Example_transcriptomics → continuous → **Linear model**. Choose `Group`, reference `Control`, covariates `age`, `sex`, `batch`. Preview design; select `GroupTreatment_A`; run. This fits:

```r
~ Group + age + sex + batch
```

<img src="www/img/help/da-volcano.png" alt="Actual adjusted linear-model volcano plot for Treatment_A versus Control on synthetic transcriptomics" style="max-width:100%;width:850px"/>
<img src="www/img/help/da-effects.png" alt="Top adjusted DA feature effects with BH-significant features coloured red" style="max-width:100%;width:850px"/>

**Read the plots:** x is an adjusted effect on the backend's scale; y is −log10 adjusted p-value. Red denotes the fitted FDR threshold, not biological importance. Coefficients for Treatment_A and Treatment_B are separate tests against the reference, not a global Group test. A nonsignificant result is not proof of no effect. Fold changes across backends/scales are not interchangeable.

### Choose a DA backend

| Method | Example setup | Parameters and results |
|---|---|---|
| Linear model | Continuous example above | Effect per selected coefficient, standard error, p-value, BH FDR. Check residual assumptions; input has no automatic log transform. |
| Mixed model | Repeated continuous measurements; `~ Group * time + age + (1 | subject_id)` | Needs true repeated subjects and adequate replication. Reports singular fits; these need investigation. Not valid with one observation per subject in the demo. |
| limma | Continuous transformed proteomics/metabolomics; `~ Group + age + batch` | Empirical Bayes moderation, optional trend/robust fitting. Same effect/volcano interpretation but different variance estimation from ordinary lm. |
| DESeq2 | Raw integer gene counts; `~ batch + Group` | Size-factor method; selected model coefficient, log2 fold change, p-value, native independent-filtered adjusted p-value. Do not use the continuous bundled data. |
| edgeR | Raw integer counts; `~ batch + Group` | TMM/TMMwsp/RLE/upper-quartile normalization, robust option, quasi-likelihood test. Log2 fold change and per-coefficient FDR. |
| MaAsLin3 | Microbiome counts or relative abundances; `~ Group + age + sex` | Explicit TSS/NONE/CLR and LOG/NONE; avoid double normalization. CLR requires NONE transform. Numeric covariate standardization changes coefficient interpretation. Abundance and prevalence associations differ; native tables are retained. |
| ANCOM-BC2 | Raw microbial counts; `~ Group + age + batch`, optionally random subject effects | Keep pseudo-count sensitivity enabled. Native result has lfc/se/p/q and sensitivity flags; natural-log effects are not log2 effects. In this workspace primary coefficient tests are exposed; global/pairwise/trend controls are not yet exposed. |

**Native backend plots:** MaAsLin3 and ANCOM-BC2 currently retain native result schemas, so the generic DA volcano/top-effect plots are not available for those tables. Inspect their effect, p/q and diagnostic columns rather than interpreting an empty generic plot as an empty result. Do not assume a backend is available until the app reports it installed; additional backends still require runtime acceptance testing.

**Adjustment scope:** linear/mixed models, limma and edgeR adjust per selected block/coefficient; DESeq2 retains its native filtering/adjustment. Microbiome backends retain their own testing families. Repeatedly trying many formulas, blocks or thresholds creates additional multiplicity that these per-run values do not address.

## 7. ComBat / ComBat-seq: explicit preprocessing, not a DA test

**Question:** Can I reduce known batch effects while preserving a specified biological design?

- **ComBat:** continuous, suitably transformed measurements (for example log-intensities), batch column `batch`, preservation formula `~ Group + age + sex`. Choose parametric or nonparametric prior and mean-only if justified.
- **ComBat-seq:** raw integer counts, batch column `batch`, biological preservation formula without batch. Do not use log-counts or relative abundances.
- **Exclude batch from the preservation formula.** The app checks its relationship with preserved biology; perfectly confounded designs are rejected.
- Output is a **corrected measurement table**, not effect sizes or p-values. Review and export it explicitly; the app does not automatically replace imported blocks.
- Reimport a corrected table if scientifically appropriate, and compare PCA before/after with batch and biology labels. Reduced batch separation alone is not proof of valid correction. The PCA figure above is a plot-reading example, **not a fabricated before/after ComBat result**.
- For DA, modelling batch as a covariate is often preferable to correcting first. For prediction, estimate preprocessing inside training folds; never preserve the held-out outcome during correction.

## 8. Save results and reproduce an analysis

- DA provides separate **Download** and **Send to Galaxy** buttons for tables and plots. A started upload is not a confirmed upload: inspect the history for completion.
- Download fit/settings RDS for method, metadata, design, warnings and session information. Treat RDS files as trusted local artifacts, not safe interchange from unknown sources.
- DA results overview is session-local. Project checkpoints do not yet restore metadata, fitted DA models, formulas or all UI settings; save these separately and provide metadata again when resuming.
- Record measurement scale, filtering, reference levels, formula, selected coefficient, software versions and FDR family in reports.

## Troubleshooting

| Message / symptom | What to do |
|---|---|
| Backend not installed | Use the tested linear-model path or ask for a DA-enabled image; an option in a selector is not proof of installation. |
| Sample IDs differ | Check sample-name whitespace, duplicate IDs and missing samples. Reconcile files explicitly; the app will not silently intersect them. |
| Rank-deficient design | Remove redundant covariates, check reference groups, batch/class confounding and over-complex interactions. |
| Numeric/categorical conflict | Assign each covariate to only one type. Numeric batch codes should usually be categorical. |
| No residual degrees of freedom | Reduce model complexity or collect more independent samples. |
| Repeated-measures model singular | Check observations per subject, group balance and random-effect identifiability. |
| Plot component out of range | Select distinct components that were fitted; some plots require at least two components. |
| Empty generic DA plot for native tables | Use the native table; generic plots currently need feature/effect/q_value columns. |
