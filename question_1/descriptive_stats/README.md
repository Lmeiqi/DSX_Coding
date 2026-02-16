# descriptiveStats

`descriptiveStats` is an R package implementing a small set of robust
descriptive statistics functions with edge-case handling.

## Installation

```r
devtools::install("question_1/descriptive_stats")
library(descriptiveStats)
```

## Functions

- `calc_mean(x)`
- `calc_median(x)`
- `calc_mode(x)`
- `calc_q1(x)`
- `calc_q3(x)`
- `calc_iqr(x)`

## Edge-case behavior

- Non-numeric inputs throw a clear error.
- Empty vectors return `NA_real_`.
- `NA` values are ignored by default in all calculations.
- `calc_mode()` returns all tied modes; if all values are unique, it returns
  `numeric(0)` to indicate no statistical mode.
