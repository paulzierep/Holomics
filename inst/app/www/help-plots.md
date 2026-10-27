# Plots

For a complete walkthrough with computed example figures, open **Help → Worked examples**. For the decision flowchart, open **Help → Workflow guide** (also shown on Home). Use **Expand plot** to enlarge a live plot and redraw it at a larger size.

### Scree plot 
The scree plot shows the variance explained by each principal component. Use it to understand diminishing returns and the dimensionality of your data; there is no universal rule that components must cover 80% of the variance. Predictive component selection requires appropriate validation rather than a variance threshold alone.

### Sample plot
The sample plot shows the the samples as points in the 2D space spanned by the selected components. It enables the user to get an impression on how the data are clustered. For more information please have a look at the documentation of mixOmics, specifically at <a class='mixOmics-link' href="https://mixomics.org/graphics/plotindiv/" rel="noreferrer noopener" target="_blank">plotIndiv() – Sample plot</a>.

### Correlation circle plot
The correlation circle presents the features as points in the 2D space spanned by the selected components, whereas the coordinates of the features are the calculated correlation values with these components. For more information please have a look at <a class='mixOmics-link' href="https://mixomics.org/graphics/plotvar/" rel="noreferrer noopener" target="_blank">plotVar() – Correlation circle plot</a>.

### Loading plot 
The loadings bar plot shows the contribution of (every) feature to the calculation of the selected component. The greater the absolute contribution value the more important the feature is. For more information please have a look at <a class='mixOmics-link' href="https://mixomics.org/graphics/plotloadings/" rel="noreferrer noopener" target="_blank">plotLoadings() – Loadings Bar plot</a>.

### Selected features table
The table with the selected features shows the numerical contribution of each features to the selected component.
These are model-selected features, **not statistically significant features**. Sparse methods retain non-zero loadings; ordinary dense fits may retain all features. DA tests and FDR are shown separately in DA / statistics and the Multi-omics DA overview.
For more information please have a look at <a class='mixOmics-link' href="https://rdrr.io/cran/mixOmics/man/selectVar.html" rel="noreferrer noopener" target="_blank">selectVar: Output of selected features</a>.

### Clustered image map
The clustered image map (CIM), shown on the sPLS analysis page, presents per cell color the correlation between a defined pair of features of the two datasets. Neighboring regions with the same color indicate a possible relationship between the features of the datasets. The variant for the DIABLO analysis presents the multi-omics molecular signature expression for each sample. For more information please have a look at <a class='mixOmics-link' href="https://mixomics.org/graphics/cim/" rel="noreferrer noopener" target="_blank">cim() – Clustered Image Maps</a>.


### Arrow plot
The arrow plot visualises the agreement between the samples across the different datasets. The arrow tail shows the position of the sample point spanned in the space of the first dataset and the tip of the arrow the position of the point in the last dataset. Any points along the arrow (means more than two datasets are being compared) are also visualized. In general, short arrows indicate a high agreement between the datasets contrary to long arrows. For more information please have a look at <a class='mixOmics-link' href="https://mixomics.org/graphics/plotarrow-2/" rel="noreferrer noopener" target="_blank">plotArrow() – Arrow plot</a>.

### Diablo plot
The diablo plot visualises the general correlation of the selected component taking into account all the different datasets.
For more information please have a look at <a class='mixOmics-link' href="https://www.rdocumentation.org/packages/mixOmics/versions/6.3.2/topics/plotDiablo" rel="noreferrer noopener" target="_blank">plotDiablo: Graphical output for the DIABLO framework</a>. 

### Circos plot
The circos plot visualises the correlations between the different features of the selected datasets. For more information please have a look at <a class='mixOmics-link' href="https://mixomics.org/graphics/circos/" rel="noreferrer noopener" target="_blank">circosPlot() – Circos plot</a>. 
The cutoff is an association threshold, not a p-value or FDR threshold. Links do not establish causality. DA significance is not currently overlaid on Circos.

### Relevance network graph
The relevance network graph visualises the same correlations between the different features of the selected datasets as the circos plot. Additionally, the network is interactive, so the user can focus on specific features (nodes) and interact with them. For more information about the calculation of the network please have a look at <a class='mixOmics-link' href="https://mixomics.org/graphics/network/" rel="noreferrer noopener" target="_blank">network() – Relevance Network Graph</a>.

