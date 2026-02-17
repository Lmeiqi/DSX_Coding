# Question 2: SDTM DS Domain Creation using {sdtm.oak}
#
# This script follows a Pharmaverse/sdtm.oak style workflow and applies
# the requested derivation rules for DS.
#
# Required output variables:
# STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT,
# VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY

library(dplyr)
library(stringr)
library(readr)
library(sdtm.oak)
library(pharmaverseraw)
library(pharmaversesdtm)

ct_url <- "https://raw.githubusercontent.com/pharmaverse/examples/main/metadata/sdtm_ct.csv"

#--- helper functions ----------------------------------------------------------
blank_to_na <- function(x) {
  x <- as.character(x)
  x[trimws(x) == ""] <- NA_character_
  x
}

norm_chr <- function(x) {
  x <- blank_to_na(x)
  toupper(trimws(x))
}

mk_iso_dtc <- function(dtc_date, dtc_time) {
  d <- blank_to_na(dtc_date)
  t <- blank_to_na(dtc_time)

  # Normalize flexible collected time to HH:MM(:SS)
  t <- ifelse(!is.na(t) & str_detect(t, "^\\d{1,2}$"), sprintf("%02d:00:00", as.integer(t)), t)
  t <- ifelse(!is.na(t) & str_detect(t, "^\\d{1,2}:\\d{1,2}$"), paste0(t, ":00"), t)

  normalize_hms <- function(v) {
    if (is.na(v)) return(NA_character_)
    p <- strsplit(v, ":", fixed = TRUE)[[1]]
    p <- c(p, rep("00", 3L - length(p)))[1:3]
    nums <- suppressWarnings(as.integer(p))
    if (any(is.na(nums))) return(NA_character_)
    sprintf("%02d:%02d:%02d", nums[1], nums[2], nums[3])
  }

  t <- vapply(t, normalize_hms, character(1))

  # try common incoming date patterns from raw ds
  d_iso <- suppressWarnings(as.character(as.Date(d, format = "%m-%d-%Y")))
  d_iso <- ifelse(is.na(d_iso), suppressWarnings(as.character(as.Date(d, format = "%m/%d/%Y"))), d_iso)
  d_iso <- ifelse(is.na(d_iso), suppressWarnings(as.character(as.Date(d))), d_iso)

  ifelse(!is.na(d_iso) & !is.na(t), paste0(d_iso, "T", t), d_iso)
}

#--- input data ----------------------------------------------------------------

ds_raw <- pharmaverseraw::ds_raw %>%
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  )

study_ct <- readr::read_csv(ct_url, show_col_types = FALSE)

required_cols <- c(
  "STUDY", "PATNUM", "INSTANCE", "IT.DSTERM", "IT.DSDECOD", "OTHERSP",
  "DSDTCOL", "DSTMCOL", "IT.DSSDAT"
)
missing_cols <- setdiff(required_cols, names(ds_raw))
if (length(missing_cols) > 0) {
  stop("Missing required columns in pharmaverseraw::ds_raw: ", paste(missing_cols, collapse = ", "))
}

# DS controlled terminology mapping for reason codelist C66727
ct_ds <- study_ct %>%
  filter(codelist_code == "C66727") %>%
  transmute(
    collected_value_norm = norm_chr(collected_value),
    term_value = norm_chr(term_value)
  ) %>%
  distinct()

#--- build domain with sdtm.oak assignments -----------------------------------

ds <- tibble(
  oak_id = ds_raw$oak_id,
  STUDYID = ds_raw$STUDY,
  DOMAIN = "DS",
  USUBJID = paste0("01-", ds_raw$PATNUM)
) %>%
  # VISIT from INSTANCE using CT
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISIT",
    ct_spec = study_ct,
    ct_clst = "VISIT",
    id_vars = oak_id_vars()
  ) %>%
  # VISITNUM from INSTANCE using CT
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISITNUM",
    ct_spec = study_ct,
    ct_clst = "VISITNUM",
    id_vars = oak_id_vars()
  ) %>%
  # IT.DSSDAT -> DSSTDTC using assign_datetime
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSDAT",
    tgt_var = "DSSTDTC",
    raw_fmt = c("m/d/y", "m-d-y", "Y-m-d"),
    id_vars = oak_id_vars()
  ) %>%
  left_join(
    ds_raw %>%
      transmute(
        oak_id,
        DSTERM_SRC = blank_to_na(.data[["IT.DSTERM"]]),
        DSDECOD_SRC = blank_to_na(.data[["IT.DSDECOD"]]),
        OTHERSP_SRC = blank_to_na(OTHERSP),
        DSDTCOL_SRC = DSDTCOL,
        DSTMCOL_SRC = DSTMCOL
      ),
    by = "oak_id"
  ) %>%
  mutate(
    # A/B logic requested:
    DSTERM = if_else(!is.na(OTHERSP_SRC), OTHERSP_SRC, DSTERM_SRC),
    DSDECOD_RAW = if_else(!is.na(OTHERSP_SRC), OTHERSP_SRC, DSDECOD_SRC),
    DSDECOD_RAW_NORM = norm_chr(DSDECOD_RAW)
  ) %>%
  left_join(ct_ds, by = c("DSDECOD_RAW_NORM" = "collected_value_norm")) %>%
  mutate(
    # map term_value when ds_raw value equals collected_value
    DSDECOD = coalesce(term_value, DSDECOD_RAW_NORM),
    # C logic requested:
    DSCAT = case_when(
      !is.na(OTHERSP_SRC) ~ "OTHER EVENT",
      norm_chr(DSDECOD_SRC) == "RANDOMIZED" ~ "PROTOCOL MILESTONE",
      TRUE ~ "DISPOSITION EVENT"
    ),
    # DSDTC from DSDTCOL + DSTMCOL
    DSDTC = mk_iso_dtc(DSDTCOL_SRC, DSTMCOL_SRC)
  ) %>%
  select(-DSTERM_SRC, -DSDECOD_SRC, -OTHERSP_SRC, -DSDTCOL_SRC, -DSTMCOL_SRC,
         -DSDECOD_RAW, -DSDECOD_RAW_NORM, -term_value)

# Sequence within subject by term
# (as requested: rec_vars = c("USUBJID", "DSTERM"))
ds <- ds %>%
  derive_seq(
    tgt_var = "DSSEQ",
    rec_vars = c("USUBJID", "DSTERM")
  )

# Derive study day from DSSTDTC using DM.RFSTDTC
# DM from pharmaversesdtm package

ds <- ds %>%
  derive_study_day(
    dm_domain = pharmaversesdtm::dm,
    tgdt = "DSSTDTC",
    refdt = "RFSTDTC",
    study_day_var = "DSSTDY"
  )

# Final variable order
ds <- ds %>%
  select(
    STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT,
    VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY
  )

print(ds, n = 100)

# Optional export
# readr::write_csv(ds, "question_2_sdtm/ds.csv", na = "")
