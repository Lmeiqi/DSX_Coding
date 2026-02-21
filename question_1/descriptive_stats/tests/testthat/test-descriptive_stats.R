test_that("mean and median work as expected", {
  expect_equal(calc_mean(c(1, 2, 3)), 2)
  expect_equal(calc_median(c(1, 2, 3, 4)), 2.5)
  expect_equal(calc_mean(c(1, NA, 3)), 2)
})

test_that("mode handles ties and no mode", {
  expect_equal(calc_mode(c(1, 2, 2, 3)), 2)
  expect_equal(calc_mode(c(1, 1, 2, 2, 3)), c(1, 2))
  expect_equal(calc_mode(c(1, 2, 3)), numeric(0))
})

test_that("quartiles and iqr are computed", {
  x <- c(1, 2, 3, 4, 5, 6, 7, 8)
  expect_equal(calc_q1(x), as.numeric(quantile(x, 0.25, names = FALSE)))
  expect_equal(calc_q3(x), as.numeric(quantile(x, 0.75, names = FALSE)))
  expect_equal(calc_iqr(x), IQR(x))
})

test_that("edge cases are handled", {
  x<-vector()
  expect_true(is.na(calc_mean(numeric(0))))
  expect_true(is.na(calc_mode(c(NA_real_, NA_real_))))
  expect_error(calc_mean(c("a", "b")), "numeric vector")
  expect_error(calc_mean(x))
})
