# Holomics in Galaxy

This branch retains the original Holomics application at upstream `24129f9`.
The only application changes are export hooks in the existing download handlers.
Authors, license, interface, import and analysis workflows remain unchanged.

Use the original Upload data tab (or its examples) to load data. No automatic
Galaxy import, project restore, extra analysis modules or branding is added.

When `HOLOMICS_OUTPUT_DIR` is set, downloading a result also stages a copy for
Galaxy's results collection. With `API_KEY`, `HISTORY_ID` and `GALAXY_URL` supplied
by the interactive-tool launcher, a Python helper also uploads it to the current
history. The staged collection is collected after the session ends and is the
fallback if the live upload fails. Browser downloads remain available.

The launcher installs `galaxy-ie-helpers==0.3.0`. Outside Galaxy the hooks do
nothing. No credentials are stored in the source or exported results.
