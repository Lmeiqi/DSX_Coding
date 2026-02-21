#' Validate Numeric Input
#'
#' Internal helper function to validate that an object is numeric.
#'
#' @param x A vector expected to be numeric.
#' @return Invisibly returns `TRUE` when validation passes.
validate_numeric_input <- function(x) {
  if (!is.numeric(x)) {
    stop("`x` must be a numeric vector.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Calculate Arithmetic Mean
#'
#' Computes the arithmetic mean of a numeric vector.
#'
#' @param x A numeric vector.
#' @return A numeric scalar mean, or `NA_real_` for empty input.
#' @examples
#' calc_mean(c(1, 2, 3, 4))
#' calc_mean(c(1, NA, 3))
#' @export
calc_mean <- function(x) {
  validate_numeric_input(x)
  if (length(x) == 0) return(NA_real_)
  mean(x, na.rm = TRUE)
}

#' Calculate Median
#'
#' Computes the median of a numeric vector.
#'
#' @param x A numeric vector.
#' @return A numeric scalar median, or `NA_real_` for empty input.
#' @examples
#' calc_median(c(1, 2, 3, 4))
#' calc_median(c(1, NA, 3))
#' @export
calc_median <- function(x) {
  validate_numeric_input(x)
  if (length(x) == 0) return(NA_real_)
  stats::median(x, na.rm = TRUE)
}

#' Calculate Mode
#'
#' Computes the statistical mode(s) of a numeric vector.
#' Returns all tied mode values in ascending order.
#' Returns `numeric(0)` if there is no mode (all values are unique).
#'
#' @param x A numeric vector.
#' @return A numeric vector of mode value(s), `numeric(0)` if no mode,
#'   or `NA_real_` for empty/all-`NA` input.
#' @examples
#' calc_mode(c(1, 2, 2, 3))
#' calc_mode(c(1, 1, 2, 2, 3))
#' calc_mode(c(1, 2, 3))
#' @export
calc_mode <- function(x) {
  validate_numeric_input(x)
  if (length(x) == 0) return(NA_real_)
  
  x_non_na <- x[!is.na(x)]
  if (length(x_non_na) == 0) return(NA_real_)
  
  tab <- table(x_non_na)
  max_count <- max(tab)
  if (max_count <= 1) return(numeric(0))
  
  as.numeric(names(tab)[tab == max_count])
}

#' Calculate First Quartile (Q1)
#'
#' Computes the first quartile (25th percentile) of a numeric vector.
#'
#' @param x A numeric vector.
#' @return A numeric scalar Q1, or `NA_real_` for empty input.
#' @examples
#' calc_q1(c(1, 2, 3, 4, 5))
#' calc_q1(c(1, NA, 3, 4))
#' @export
calc_q1 <- function(x) {
  validate_numeric_input(x)
  if (length(x) == 0) return(NA_real_)
  stats::quantile(x, probs = 0.25, na.rm = TRUE, names = FALSE, type = 7)
}

#' Calculate Third Quartile (Q3)
#'
#' Computes the third quartile (75th percentile) of a numeric vector.
#'
#' @param x A numeric vector.
#' @return A numeric scalar Q3, or `NA_real_` for empty input.
#' @examples
#' calc_q3(c(1, 2, 3, 4, 5))
#' calc_q3(c(1, NA, 3, 4))
#' @export
calc_q3 <- function(x) {
  validate_numeric_input(x)
  if (length(x) == 0) return(NA_real_)
  stats::quantile(x, probs = 0.75, na.rm = TRUE, names = FALSE, type = 7)
}

#' Calculate Interquartile Range (IQR)
#'
#' Computes the interquartile range, defined as `Q3 - Q1`.
#'
#' @param x A numeric vector.
#' @return A numeric scalar IQR, or `NA_real_` for empty input.
#' @examples
#' calc_iqr(c(1, 2, 3, 4, 5))
#' calc_iqr(c(1, NA, 3, 4, 5))
#' @export
calc_iqr <- function(x) {
  validate_numeric_input(x)
  if (length(x) == 0) return(NA_real_)
  calc_q3(x) - calc_q1(x)
}
