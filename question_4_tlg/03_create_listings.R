# =============================================================================
# Question 4 - Part 3: Clinical Trial AE Listing
# =============================================================================
# Purpose : Detailed listing of treatment-emergent AEs per subject
#
# Package : {gt} for rendering
#           Manual repeat-suppression logic in dplyr matches the screenshot
#           exactly — this is standard practice in clinical programming when
#           no dedicated listing package handles multi-column suppression.
# Discussion: {gtsummary} is only useful when generating descriptive table instead of listing? 
#
# Repeat suppression (matching screenshot precisely):
#   USUBJID -> blank on rows 2..n within the same subject
#   ACTARM  -> blank on rows 2..n within the same subject
#   AETERM  -> blank on CONSECUTIVE duplicate rows within the same subject
#              (e.g. ERYTHEMA x3 -> shown once, then blank x2)
#
# Input  : pharmaverseadam::adae
# Output : question_4_tlg/ae_listings.html
# =============================================================================

# ---- 0. Load packages -------------------------------------------------------
library(pharmaverseadam)
library(dplyr)
library(gt)

# ---- 1. Load and prepare data -----------------------------------------------
adae <- pharmaverseadam::adae

listing_raw <- adae |>
  filter(TRTEMFL == "Y") |>
  filter(!grepl("screen failure", ACTARM, ignore.case = TRUE)) |>
  mutate(
    AESTDT = substr(AESTDTC, 1, 10),
    AEENDT = if_else(
      is.na(AEENDTC) | AEENDTC == "",
      "NA",
      substr(AEENDTC, 1, 10)
    )
  ) |>
  arrange(USUBJID, AESTDT, AETERM) |>
  select(USUBJID, ACTARM, AETERM, AESEV, AEREL, AESTDT, AEENDT)

# ---- 2. Apply repeat-suppression logic --------------------------------------
#
# Rule 1 - USUBJID: show only on first row per subject
# Rule 2 - ACTARM : show only on first row per subject (same logic as USUBJID)
# Rule 3 - AETERM : show only when value CHANGES compared to the previous row
#                   within the same subject (consecutive duplicate suppression)
#
# We also track is_first_subj to draw a separator line between subject blocks.

listing_display <- listing_raw |>
  group_by(USUBJID) |>
  mutate(
    subj_rn = row_number(),
    
    # Rule 1 & 2: USUBJID and ACTARM blank after first row per subject
    USUBJID_disp = if_else(subj_rn == 1L, USUBJID, ""),
    ACTARM_disp  = if_else(subj_rn == 1L, ACTARM,  ""),
    
    # Rule 3: AETERM blank when same as previous row within this subject
    # lag() gives the previous row's value; if it matches, blank it out
    AETERM_prev  = lag(AETERM, default = ""),
    AETERM_disp  = if_else(AETERM == AETERM_prev, "", AETERM),
    
    # Flag first row of each subject for top-border styling
    is_first_subj = (subj_rn == 1L)
  ) |>
  ungroup() |>
  select(
    `Unique Subject Identifier`           = USUBJID_disp,
    `Description of Actual Arm`           = ACTARM_disp,
    `Reported Term for the Adverse Event` = AETERM_disp,
    `Severity/Intensity`                  = AESEV,
    `Causality`                           = AEREL,
    `Start Date/Time of Adverse Event`    = AESTDT,
    `End Date/Time of Adverse Event`      = AEENDT,
    is_first_subj
  )

# ---- 3. Build GT table ------------------------------------------------------
gt_listing <- listing_display |>
  select(-is_first_subj) |>
  gt() |>
  
  # Title and subtitle
  tab_header(
    title    = "Listing of Treatment-Emergent Adverse Events by Subject",
    subtitle = "Excluding Screen Failure Patients"
  ) |>
  
  # Column labels
  cols_label(
    `Unique Subject Identifier`           = "Unique Subject Identifier",
    `Description of Actual Arm`           = "Description of Actual Arm",
    `Reported Term for the Adverse Event` = "Reported Term for the Adverse Event",
    `Severity/Intensity`                  = "Severity/Intensity",
    `Causality`                           = "Causality",
    `Start Date/Time of Adverse Event`    = "Start Date/Time of Adverse Event",
    `End Date/Time of Adverse Event`      = "End Date/Time of Adverse Event"
  ) |>
  
  # Column widths
  cols_width(
    `Unique Subject Identifier`           ~ px(148),
    `Description of Actual Arm`           ~ px(140),
    `Reported Term for the Adverse Event` ~ px(250),
    `Severity/Intensity`                  ~ px(100),
    `Causality`                           ~ px(88),
    `Start Date/Time of Adverse Event`    ~ px(180),
    `End Date/Time of Adverse Event`      ~ px(180)
  ) |>
  
  cols_align(align = "left") |>
  
  # Global styling: clean monospaced clinical listing appearance
  tab_options(
    heading.title.font.size           = 11,
    heading.subtitle.font.size        = 10,
    heading.align                     = "left",
    heading.background.color          = "white",
    heading.border.bottom.color       = "black",
    heading.border.bottom.width       = px(1),
    # heading.border.top.style          = "hidden",
    column_labels.font.size           = 10,
    # column_labels.font.weight         = "bold",
    column_labels.border.top.color    = "black",
    column_labels.border.top.width    = px(1),
    column_labels.border.bottom.color = "black",
    column_labels.border.bottom.width = px(1),
    column_labels.background.color    = "white",
    column_labels.border.lr.style     = "hidden",
    data_row.padding                  = px(1),
    table.font.size                   = 10,
    table.font.names                  = "Courier New, Courier, monospace",
    table.border.top.style            = "hidden",
    table.border.bottom.style         = "hidden",
    table_body.border.bottom.style    = "hidden",
    table_body.hlines.style           = "none"
  ) |>
  
  # Normal weight monospaced body text
  tab_style(
    style     = cell_text(weight = "normal", size = px(10),
                          font  = "Courier New, Courier, monospace"),
    locations = cells_body()
  ) |>
  
  # Bold USUBJID and ACTARM on the first row of each subject block
  # tab_style(
  #   style     = cell_text(weight = "bold"),
  #   locations = cells_body(
  #     columns = c(`Unique Subject Identifier`, `Description of Actual Arm`),
  #     rows    = `Unique Subject Identifier` != ""
  #   )
  # ) |>
  
  # Thin top border separating each new subject block
  # tab_style(
  #   style     = cell_borders(sides = "top", color = "grey70", weight = px(1)),
  #   locations = cells_body(rows = listing_display$is_first_subj)
  # ) |>
  
  # Mute "NA" end dates in grey
  # tab_style(
  #   style     = cell_text(color = "grey55"),
  #   locations = cells_body(
  #     columns = `End Date/Time of Adverse Event`,
  #     rows    = `End Date/Time of Adverse Event` == "NA"
  #   )
  # ) |>
  
  # Footnote
  tab_footnote(
    footnote  = paste0("Listing sorted by Unique Subject Identifier and ",
                       "Start Date/Time of Adverse Event."),
    locations = cells_column_labels(
      columns = `Start Date/Time of Adverse Event`
    )
  )

# ---- 4. Save output ---------------------------------------------------------
gtsave(gt_listing, filename = "question_4_tlg/output/ae_listings.html")
message("AE listings saved to question_4_tlg/ae_listings.html")