# OmicsHarbor

**OmicsHarbor** is Paul Zierep's extended multi-omics analysis workspace, **based on Holomics**. This derivative adds Galaxy integration, an expanded mixOmics workbench, covariate-aware differential association interfaces, guided project setup and worked examples. It is not an official release or endorsement by the original Holomics authors. Backend installation does not imply completion of method-specific validation.

The harbour icon represents three omics layers converging in a shared analysis workspace.

## Fork development

**Paul Zierep** ([@paulzierep](https://github.com/paulzierep)) develops the
OmicsHarbor extensions on
[`omicsharbor-development`](https://github.com/paulzierep/Holomics/tree/omicsharbor-development).
See the [fork README](https://github.com/paulzierep/Holomics/blob/omicsharbor-development/README.md)
for installation, capabilities and known limitations. Report fork-specific
problems to the [fork issue tracker](https://github.com/paulzierep/Holomics/issues).
The separate `galaxy-it-adaptations` branch packages original Holomics with
minimal Galaxy integration; it is not an OmicsHarbor release.

## Original Holomics authors
Holomics was developed by Katharina Munk and Eva M. Molin. Additionally, Lisa Ziemba supported with mixOmics implementation and Günter Brader contributed by giving feedback during the development process.

## How to cite
Please credit OmicsHarbor's development by Paul Zierep, the underlying Holomics publication below, and the statistical packages actually used. Record software versions and analysis settings. No separate OmicsHarbor publication is currently declared.

Munk, K., Ilina, D., Ziemba, L., Brader, G. & Molin, E.M. (2024). Holomics - a user-friendly R shiny application for multi-omics data integration and analysis<br>
[doi:10.1186/s12859-024-05719-4](https://doi.org/10.1186/s12859-024-05719-4)

# License
OmicsHarbor retains the upstream package's GPL (>= 3) license and original attribution. The internal R package remains named `Holomics` for compatibility with existing launchers and project files; OmicsHarbor is the user-facing application name.
