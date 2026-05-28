# Builds a 250-effect / 35-species deterministic subsample of the
# thermal.csv dataset from itchyshin/location-scale_meta-analysis,
# for use in vignettes/symbolizer-meta-analysis.Rmd Widget 2 and the
# tests/testthat/helper-meta-fits.R fixtures. Reproducible via the
# seed below.
#
# NOTE: thermal.csv uses numeric species_ID keys; tree tips are labelled
# by unique_name (underscore-separated genus_species). We sample on
# unique_name and keep its numeric species_ID intact in the output.

suppressMessages({
  library(ape)
  library(dplyr)
})

set.seed(20260528L)

# Fetch the canonical CSV + tree
src_url   <- "https://raw.githubusercontent.com/itchyshin/location-scale_meta-analysis/main/data"
csv_dest  <- tempfile(fileext = ".csv")
tree_dest <- tempfile(fileext = ".tre")
download.file(file.path(src_url, "thermal.csv"),    csv_dest)
download.file(file.path(src_url, "phylo_tree.tre"), tree_dest)

dat_full  <- read.csv(csv_dest, stringsAsFactors = FALSE)
tree_full <- ape::read.tree(tree_dest)

# unique_name matches tree tip labels (intersect = 137 of 138 tips)
species_pool <- intersect(unique(dat_full$unique_name), tree_full$tip.label)
species_keep <- sample(species_pool, 35L)

dat_sub <- dat_full %>%
  filter(unique_name %in% species_keep) %>%
  # Drop rows with zero sampling variance (cause boundary collapse on
  # the drmTMB fit; the Pottier data has a few rows where Var_dARR is
  # effectively zero -- these are not interpretable in a meta-analytic
  # likelihood).
  filter(Var_dARR > 1e-6) %>%
  group_by(unique_name) %>%
  slice_sample(n = 10L, replace = FALSE) %>%   # up to 10 effects per species (groups smaller than 10 use all rows)
  ungroup() %>%
  arrange(study_ID, unique_name)
if (nrow(dat_sub) > 250L) dat_sub <- dat_sub[seq_len(250L), ]

# Rename for the article + tests (phylogeny is the convention that
# matches the tree tip labels), and SUBSET to only the columns the
# vignette + tests use. Keeps the committed CSV small (5 columns) and
# clean (no NA-padded rows from the wider Pottier dataset).
dat_sub <- dat_sub %>%
  mutate(phylogeny = unique_name) %>%
  select(dARR, Var_dARR, phylogeny, study_ID, habitat)
dat_sub <- dat_sub[complete.cases(dat_sub), ]

tree_sub <- ape::keep.tip(tree_full, species_keep)
tree_sub <- ape::chronos(tree_sub, lambda = 1)

dir.create("inst/extdata", showWarnings = FALSE, recursive = TRUE)
write.csv(dat_sub, "inst/extdata/thermal_subset.csv", row.names = FALSE)
ape::write.tree(tree_sub, "inst/extdata/thermal_subset_tree.tre")

cat(sprintf("Wrote %d effects across %d species across %d studies.\n",
            nrow(dat_sub),
            length(unique(dat_sub$phylogeny)),
            length(unique(dat_sub$study_ID))))
