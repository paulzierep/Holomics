# Holomics in Galaxy

This branch retains the original Holomics application at upstream `24129f9`.
Application changes are Galaxy input loading and export hooks in existing download handlers.
Authors, license, interface, import and analysis workflows remain unchanged.

Select numeric tables and matching sample labels on the Galaxy launch form.
They load automatically into the original application's data stores. Rows are
aligned by sample ID; mismatched sets, duplicate IDs and nonnumeric measurements
are rejected before import. Mark prepared tables for direct multi-omics use;
otherwise follow the original single-omics reduction workflow. The original
Upload data tab remains available. No project restore, extra modules or branding
is added.

Every export has a Download button (browser only) and, when
`HOLOMICS_OUTPUT_DIR` is set, a separate Send to Galaxy button. Only the latter
stages a copy for Galaxy's results collection and starts a live upload using
`API_KEY`, `HISTORY_ID` and `GALAXY_URL`. The staged collection is collected
after the session ends and is the fallback if live upload fails.

The launcher installs `galaxy-ie-helpers==0.3.0`. Outside Galaxy the hooks do
nothing. No credentials are stored in the source or exported results.
