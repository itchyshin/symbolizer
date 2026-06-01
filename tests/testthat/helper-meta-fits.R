# Helper fixtures for v0.22.1 phylogenetic multilevel meta-analysis
# tests. All three fixtures use the deterministic 164-effect subsample
# of thermal.csv shipped at inst/extdata/thermal_subset.csv. The
# species-grouping column is `phylogeny` (matches tree tip labels);
# `species_ID` is a numeric key and is NOT used.

.read_thermal_subset <- function() {
  csv_path <- system.file("extdata", "thermal_subset.csv",
                          package = "symbolizer")
  if (!nzchar(csv_path)) {
    csv_path <- "inst/extdata/thermal_subset.csv"   # dev-mode fallback
  }
  read.csv(csv_path, stringsAsFactors = FALSE)
}

.read_thermal_tree <- function() {
  testthat::skip_if_not_installed("ape")
  tree_path <- system.file("extdata", "thermal_subset_tree.tre",
                           package = "symbolizer")
  if (!nzchar(tree_path)) {
    tree_path <- "inst/extdata/thermal_subset_tree.tre"
  }
  ape::read.tree(tree_path)
}

fit_drmtmb_phylo_multilevel <- function() {
  testthat::skip_if_not_installed("drmTMB")
  dat  <- .read_thermal_subset()
  tree <- .read_thermal_tree()
  # Import drmTMB formula helpers into scope so formula markers (meta_V,
  # phylo) can be referenced without the :: prefix, which drmTMB's formula
  # parser does not support.
  bf      <- drmTMB::drm_formula
  meta_V  <- drmTMB::meta_V
  phylo   <- drmTMB::phylo
  drmTMB::drmTMB(
    bf(
      dARR ~ 1 + habitat +
              meta_V(V = Var_dARR) +
              phylo(1 | phylogeny, tree = tree) +
              (1 | study_ID),
      sigma ~ 1),
    family = stats::gaussian(),
    data   = dat
  )
}

fit_brms_phylo_meta <- function() {
  testthat::skip_if_not_installed("brms")
  testthat::skip_if_not_installed("ape")
  dat  <- .read_thermal_subset()
  tree <- .read_thermal_tree()
  A_phylo <- ape::vcv.phylo(tree, corr = TRUE)
  # brms addition terms (se, trials, etc.) are parsed inside bf() by brms
  # itself once the brms namespace is attached. Use the cached fit path so
  # the formula is read back from the .rds file rather than re-evaluated.
  brms::brm(
    brms::bf(dARR | se(sqrt(Var_dARR)) ~ 1 + habitat
                + (1 | study_ID)
                + (1 | gr(phylogeny, cov = mat))),
    data   = dat,
    data2  = list(mat = A_phylo),
    family = gaussian(),
    chains = 2L, iter = 1000L, warmup = 500L,
    refresh = 0L, silent = 2,
    file = "/tmp/fit_brms_phylo_meta_cache"
  )
}
