# load_template() errors for a missing CSV

    Code
      symbolizer:::load_template("definitely-does-not-exist")
    Condition
      Error in `symbolizer:::load_template()`:
      ! Template 'definitely-does-not-exist.csv' not found in installed extdata.
      i If running with `devtools::load_all()`, check 'inst/extdata/'.

