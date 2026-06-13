# Interactive HTML widget for a model's factors and dummy coding

`as_html_factor_views()` renders a four-tab interactive widget that
walks a reader through the categorical structure of a fit: the coding
scheme (levels, reference, indicator columns), the per-group means, the
pairwise comparisons, and the interactions. It is the web-facing
companion to
[`explain_factors()`](https://itchyshin.github.io/symbolizer/reference/explain_factors.md).

Estimates are drawn in the Confidence-Eye grammar – a pale compatibility
region with a darker interval outline and a hollow point estimate; the
language is confidence/compatibility, never posterior. Tabs 2-4 need
emmeans; without it they show a short note.

## Usage

``` r
as_html_factor_views(x, id = "symfv", standalone = FALSE, file = NULL, ...)
```

## Arguments

- x:

  A
  [`symbolized_model`](https://itchyshin.github.io/symbolizer/reference/new_symbolized_model.md)
  (output of
  [`symbolize()`](https://itchyshin.github.io/symbolizer/reference/symbolize.md)).

- id:

  Character id stem for the widget's element ids. Default `"symfv"`.

- standalone:

  Logical; if `TRUE`, wrap the fragment in a self-contained HTML page
  (with a MathJax bootstrap) suitable for opening directly in a browser.
  Default `FALSE` (an embeddable fragment).

- file:

  Optional path; if given, the HTML is written there and returned
  invisibly instead of printed.

- ...:

  Reserved for future use.

## Value

A character vector (HTML), invisibly.

## See also

[`explain_factors()`](https://itchyshin.github.io/symbolizer/reference/explain_factors.md),
[`as_html_three_views()`](https://itchyshin.github.io/symbolizer/reference/as_html_three_views.md)

## Examples

``` r
d <- transform(mtcars, gear = factor(gear))
sym <- symbolize(lm(mpg ~ gear, data = d))
# write the interactive widget to a self-contained HTML file
html <- as_html_factor_views(sym, standalone = TRUE,
                             file = tempfile(fileext = ".html"))
```
