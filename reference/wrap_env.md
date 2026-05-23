# Wrap aligned LaTeX equation lines in a chosen environment

A generalisation of
[`wrap_aligned()`](https://itchyshin.github.io/symbolizer/reference/wrap_aligned.md)
that takes an arbitrary LaTeX environment name (e.g. `"aligned"`,
`"align*"`, `"gather"`).

## Usage

``` r
wrap_env(lines, env)
```

## Arguments

- lines:

  Character vector of LaTeX equation lines.

- env:

  LaTeX environment name. Single non-empty string.

## Value

A single string containing `\\begin{env} ... \\end{env}`.
