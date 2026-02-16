# Question 4.1: AE Summary Table using {gtsummary}

library(dplyr)
library(gtsummary)
library(gt)
library(pharmaverseadam)

adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl

teae <- adae %>%
  filter(TRTEMFL == "Y") %>%
  distinct(USUBJID, ACTARM, AETERM)

ae_summary <- teae %>%
  tbl_cross(
    row = AETERM,
    col = ACTARM,
    percent = "column"
  ) %>%
  bold_labels()

gt_tbl <- as_gt(ae_summary)

gtsave(gt_tbl, "question_4_tlg/output/ae_summary_table.html")
