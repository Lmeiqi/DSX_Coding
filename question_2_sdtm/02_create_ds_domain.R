# Question 2: SDTM DS Domain Creation using {sdtm.oak}
#
# Objective:
#   Create SDTM DS with variables:
#   STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT,
#   VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY
#
# Inputs:
#   - pharmaverseraw::ds_raw
#   - Study CT from:
#     https://github.com/pharmaverse/examples/blob/main/metadata/sdtm_ct.csv
#
# Notes aligned to aCRF mapping:
#   - If OTHERSP is populated: map OTHERSP to DSDECOD and DSTERM; DSCAT = "OTHER EVENT"
#   - Else DSDECOD comes from raw DSDECOD; DSTERM comes from raw DSTERM
#   - If (non-OTHERSP) DSDECOD is Randomized: DSCAT = "PROTOCOL MILESTONE"
#     else DSCAT = "DISPOSITION EVENT"
#   - DSSDAT -> DSSTDTC (ISO8601 date)
#   - DSDTCOL + DSTMCOL -> DSDTC (ISO8601 datetime when time exists)

library(dplyr)
library(stringr)
library(readr)
library(sdtm.oak)
library(pharmaverseraw)

ct_url <- "https://raw.githubusercontent.com/pharmaverse/examples/main/metadata/sdtm_ct.csv"

# --- Helpers -----------------------------------------------------------------

normalize_text <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- NA_character_
  out <- toupper(trimws(x))
  out[out %in% c("", "NA")] <- NA_character_
  out
}

blank_to_na <- function(x) {
  y <- as.character(x)
  y[trimws(y) == ""] <- NA_character_
  y
}

to_iso_date <- function(x) {
  x <- blank_to_na(x)
  # Supports common date forms and keeps NA when unparsable.
  suppressWarnings(as.character(as.Date(x)))
}

to_iso_datetime <- function(date_part, time_part) {
  d <- to_iso_date(date_part)
  t <- blank_to_na(time_part)

  # Normalize collected time forms such as "9:5", "09:05", "09:05:11".
  t <- ifelse(!is.na(t) & str_detect(t, "^\\d{1,2}:\\d{1,2}$"), paste0(t, ":00"), t)
  t <- ifelse(!is.na(t) & str_detect(t, "^\\d{1,2}$"), paste0(sprintf("%02d", as.integer(t)), ":00:00"), t)

  # Pad hour/minute/second components when needed.
  pad_hms <- function(val) {
    if (is.na(val)) return(NA_character_)
    parts <- strsplit(val, ":", fixed = TRUE)[[1]]
    parts <- c(parts, rep("00", max(0, 3 - length(parts))))
    parts <- parts[1:3]
    parts <- sprintf("%02d", suppressWarnings(as.integer(parts)))
    if (any(is.na(parts))) return(NA_character_)
    paste(parts, collapse = ":")
  }

  t <- vapply(t, pad_hms, character(1))
  ifelse(!is.na(d) & !is.na(t), paste0(d, "T", t), d)
}

# --- Load inputs --------------------------------------------------------------

raw_ds <- pharmaverseraw::ds_raw

study_ct <- tryCatch(
  readr::read_csv(ct_url, show_col_types = FALSE),
  error = function(e) {
    warning("Could not read CT from URL. Continuing without DSDECOD CT mapping: ", conditionMessage(e))
    NULL
  }
)

# Restrict CT to DS reason codelist and keep collected_value -> term_value mapping
ct_ds <- NULL
if (!is.null(study_ct)) {
  needed_cols <- c("codelist_code", "collected_value", "term_value")
  if (all(needed_cols %in% names(study_ct))) {
    ct_ds <- study_ct %>%
      filter(codelist_code == "C66727") %>%
      transmute(
        collected_value_norm = normalize_text(collected_value),
        term_value = normalize_text(term_value)
      ) %>%
      distinct()
  }
}

# --- Derivation ---------------------------------------------------------------

# Accept common raw naming variants from examples/aCRF labels.
raw_names <- names(raw_ds)

pick_col <- function(primary, fallback = character()) {
  candidates <- c(primary, fallback)
  hit <- candidates[candidates %in% raw_names]
  if (length(hit) == 0) return(rep(NA_character_, nrow(raw_ds)))
  raw_ds[[hit[[1]]]]
}

work <- tibble(
  STUDYID_RAW = pick_col("STUDYID", c("PROJECTID")),
  USUBJID = pick_col("USUBJID"),
  VISITNUM = pick_col("VISITNUM"),
  VISIT = pick_col("VISIT"),
  DSDECOD_RAW = pick_col("DSDECOD"),
  DSTERM_RAW = pick_col("DSTERM"),
  OTHERSP = pick_col("OTHERSP"),
  DSSDAT = pick_col("DSSDAT"),
  DSDTCOL = pick_col("DSDTCOL"),
  DSTMCOL = pick_col("DSTMCOL")
) %>%
  mutate(
    STUDYID = coalesce(as.character(STUDYID_RAW), as.character(STUDYID_RAW)),
    OTHERSP = blank_to_na(OTHERSP),

    DSTERM = if_else(!is.na(OTHERSP), OTHERSP, blank_to_na(DSTERM_RAW)),
    DSDECOD_INPUT = if_else(!is.na(OTHERSP), OTHERSP, blank_to_na(DSDECOD_RAW)),

    DSDECOD_INPUT_NORM = normalize_text(DSDECOD_INPUT),
    DSDECOD = DSDECOD_INPUT_NORM,

    DSCAT = case_when(
      !is.na(OTHERSP) ~ "OTHER EVENT",
      DSDECOD_INPUT_NORM == "RANDOMIZED" ~ "PROTOCOL MILESTONE",
      TRUE ~ "DISPOSITION EVENT"
    ),

    DSSTDTC = to_iso_date(DSSDAT),
    DSDTC = to_iso_datetime(DSDTCOL, DSTMCOL)
  )

# Apply CT mapping when available (collected_value -> controlled term_value)
if (!is.null(ct_ds)) {
  work <- work %>%
    left_join(ct_ds, by = c("DSDECOD_INPUT_NORM" = "collected_value_norm")) %>%
    mutate(DSDECOD = coalesce(term_value, DSDECOD_INPUT_NORM)) %>%
    select(-term_value)
}

# Final DS with sequencing and study day from first DSSTDTC by subject.
ds <- work %>%
  mutate(
    STUDYID = as.character(STUDYID),
    DOMAIN = "DS",
    VISITNUM = suppressWarnings(as.numeric(VISITNUM))
  ) %>%
  group_by(USUBJID) %>%
  arrange(DSSTDTC, DSDTC, .by_group = TRUE) %>%
  mutate(
    DSSEQ = row_number(),
    refdt = if (all(is.na(DSSTDTC))) as.Date(NA) else min(as.Date(DSSTDTC), na.rm = TRUE),
    DSSTDY = as.integer(as.Date(DSSTDTC) - refdt + 1)
  ) %>%
  ungroup() %>%
  mutate(
    DSTERM = blank_to_na(DSTERM)
  ) %>%
  select(
    STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT,
    VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY
  )

print(ds, n = 50)

# Optional export
# readr::write_csv(ds, "question_2_sdtm/ds.csv", na = "")
