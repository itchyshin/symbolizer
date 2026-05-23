# Insert an alignment marker before `=` or `\\sim`

Inserts a single `&` immediately before the first `=` (not part of `\=`)
or the first `\sim` token in a LaTeX equation line. Used to add
`aligned`-style alignment markers to the lines carried by
`x$components`.

## Usage

``` r
align_at(line)
```

## Arguments

- line:

  A character string (one LaTeX equation line, no outer math
  delimiters).

## Value

The line with `&` inserted before the alignment point. If no `=` or
`\sim` is found the line is returned unchanged.
