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

#--- input data ----------------------------------------------------------------

ds_raw <- pharmaverseraw::ds_raw %>%
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  )

study_ct <- readr::read_csv(ct_url, show_col_types = FALSE)


#--- build KEY variables -----------------------------------

ds_raw<-ds_raw %>% 
  mutate(
  DSTERM = toupper(trimws(if_else(!is.na(OTHERSP), OTHERSP, IT.DSTERM))),
  DSDECOD = toupper(trimws(if_else(!is.na(OTHERSP), OTHERSP, IT.DSDECOD))),
  DSCAT = case_when(
    !is.na(OTHERSP) ~ "OTHER EVENT",
    is.na(OTHERSP) & IT.DSDECOD == "Randomized" ~ "PROTOCOL MILESTONE",
    is.na(OTHERSP) & IT.DSDECOD != "Randomized" ~ "DISPOSITION EVENT"
  )
)
  #--- build domain with sdtm.oak assignments -----------------------------------

ds<- 
  # Map DSDECOD using assign_ct
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "DSDECOD",
    tgt_var = "DSDECOD",
    ct_spec = study_ct,
    ct_clst = "C66727",
    id_vars = oak_id_vars()
  ) %>%
  # Map DSTERM using assign_ct
  assign_no_ct(
    raw_dat = ds_raw,
    raw_var = "DSTERM",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  )%>%
  # Map DSCAT using assign_ct
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "DSCAT",
    tgt_var = "DSCAT",
    ct_spec = study_ct,
    ct_clst = "C74558",
    id_vars = oak_id_vars()
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
  # IT.DSSTDAT -> DSSTDTC using assign_datetime
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSTDAT",
    tgt_var = "DSSTDTC",
    raw_fmt = c("m-d-y"),
    id_vars = oak_id_vars()
  ) %>%
  # DSDTCOL & DSTMCOL -> DSDTC using assign_datetime
  assign_datetime(
    tgt_var = "DSDTC",
    raw_dat = ds_raw,
    raw_var = c("DSDTCOL", "DSTMCOL"),
    raw_fmt = c("m-d-y", "H:M")
  ) 

ds <- ds %>%
  dplyr::mutate(
    STUDYID = ds_raw$STUDY,
    DOMAIN = "DS",
    USUBJID = paste0("01-", ds_raw$PATNUM),
    VISITNUM=as.numeric(stringr::str_extract(VISITNUM, "\\d+\\.?\\d*"))
    ) %>% 
  arrange(USUBJID, DSSTDTC, VISITNUM) %>%
  # Sequence within subject by dsdecod
  derive_seq(
    tgt_var = "DSSEQ",
    rec_vars = c("USUBJID", "DSSTDTC", "DSDECOD")
  ) %>%
  # Derive study day from DSSTDTC using DM.RFSTDTC
  derive_study_day(
    sdtm_in = .,
    dm_domain = dm,
    tgdt = "DSSTDTC",
    refdt = "RFSTDTC",
    study_day_var = "DSSTDY"
  )


# Final variable order
ds <- ds %>%
  select(
    STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT, VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY
  )

# Optional export
# readr::write_csv(ds, "question_2_sdtm/ds.csv", na = "")
