test_that("load_template('capabilities') returns a non-empty tibble", {
  tbl <- symbolizer:::load_template("capabilities")
  expect_s3_class(tbl, "tbl_df")
  expect_gt(nrow(tbl), 0L)
})

test_that("load_template() caches: second call returns the identical object", {
  first <- symbolizer:::load_template("capabilities")
  second <- symbolizer:::load_template("capabilities")
  expect_true(identical(first, second))
})

test_that("clear_template_cache() empties the cache", {
  # Warm the cache, then clear and confirm the env has no bindings.
  symbolizer:::load_template("capabilities")
  symbolizer:::clear_template_cache()
  expect_length(ls(envir = symbolizer:::.symbolizer_template_cache), 0L)
})

test_that("load_template() errors for a missing CSV", {
  expect_snapshot(
    error = TRUE,
    symbolizer:::load_template("definitely-does-not-exist")
  )
})

test_that("the relatedness (phylo) assumption block covers pedigree animal models", {
  tpl <- symbolizer:::load_template("assumption-templates")
  gloss <- names(tpl)[[5L]]  # the prose column
  phylo <- paste(tpl[tpl$requires %in% "phylo", ][[gloss]], collapse = " ")
  # the animal-model block (MCMCglmm / brms / drmTMB) reads A as a relatedness
  # matrix that is phylogenetic OR pedigree -- not species-only
  expect_match(phylo, "pedigree")
  expect_match(phylo, "relatedness")
  expect_match(phylo, "narrow-sense")        # heritability h^2 reading
  # phylolm / PGLS (phylo_marginal) is always species-level comparative: keep it
  marg <- paste(tpl[tpl$requires %in% "phylo_marginal", ][[gloss]], collapse = " ")
  expect_match(marg, "species")
  expect_false(grepl("pedigree", marg))
})
