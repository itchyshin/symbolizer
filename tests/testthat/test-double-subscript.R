# KaTeX rejects double subscripts: `y_{ij}_{1}` ("Double subscript at
# position ..."). The three-views worked-row and stacked-matrix blocks append
# an observation / dimension subscript to the response symbol. For a response
# symbol that already carries a subscript -- the gllvm multi-trait `y_{ij}` --
# that append must wrap the base in a group, `{y_{ij}}_{1}`, so the index is a
# single subscript on the whole symbol. `subscriptable_base()` does the wrap.

test_that("subscriptable_base wraps a symbol that already has a subscript", {
  # gllvm multi-trait response: must be wrapped so the appended index is legal.
  expect_identical(subscriptable_base("y_{ij}"), "{y_{ij}}")
  # bare single-char subscript also wraps (y_i + _{1} would double-subscript).
  expect_identical(subscriptable_base("y_i"), "{y_i}")
})

test_that("subscriptable_base leaves subscript-free symbols untouched", {
  expect_identical(subscriptable_base("\\mathbf{y}"), "\\mathbf{y}")
  expect_identical(subscriptable_base("\\log(\\mathbf{y})"), "\\log(\\mathbf{y})")
})

test_that("subscriptable_base treats an escaped underscore as a literal, not a subscript", {
  # \mathbf{body\_mass}: the `\_` is a literal underscore inside the name, NOT
  # a subscript operator, so the symbol does not need wrapping.
  expect_identical(subscriptable_base("\\mathbf{body\\_mass}"),
                   "\\mathbf{body\\_mass}")
})

test_that("appending an index to a wrapped base yields a single (legal) subscript", {
  # The concrete KaTeX-error fragment was `y_{ij}_{1}`; the fix produces
  # `{y_{ij}}_{1}` (group + one subscript), which KaTeX parses cleanly.
  expect_identical(paste0(subscriptable_base("y_{ij}"), "_{1}"), "{y_{ij}}_{1}")
  expect_false(grepl("y_\\{ij\\}_\\{", paste0(subscriptable_base("y_{ij}"), "_{1}")))
})
