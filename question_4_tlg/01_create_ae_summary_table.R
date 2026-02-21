# Question 4.1: AE Summary Table using {gtsummary}

# Load libraries & data -------------------------------------
library(dplyr)
library(gtsummary)
library(pharmaverseadam)

adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae

# Pre-processing --------------------------------------------
adae <- adae |>
  filter(
    # Treatment-emergent AE
    TRTEMFL == "Y",
  )

# Build table --------------------------------------------
tbl <- adae |>
  tbl_hierarchical(
    variables = c(AESOC, AETERM),
    by = ACTARM,
    id = USUBJID,
    denominator = adsl,
    overall_row = TRUE,
    label = "..ard_hierarchical_overall.." ~ "Treatment Emergent AEs"
  ) |> 
  sort_hierarchical()

# Build ard --------------------------------------------
ard <- gather_ard(tbl)
ard

# Save --------------------------------------------
gt_tbl <- as_gt(tbl)
gtsave(gt_tbl, "question_4_tlg/output/ae_summary_table.html")
