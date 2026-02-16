# Question 3: ADaM ADSL Dataset Creation

library(dplyr)
library(stringr)
library(admiral)
library(pharmaversesdtm)

adsl <- pharmaversesdtm::dm %>%
  mutate(
    AGEGR9 = case_when(
      AGE < 18 ~ "<18",
      AGE <= 50 ~ "18 - 50",
      AGE > 50 ~ ">50",
      TRUE ~ NA_character_
    ),
    AGEGR9N = case_when(
      AGE < 18 ~ 1,
      AGE <= 50 ~ 2,
      AGE > 50 ~ 3,
      TRUE ~ NA_real_
    ),
    ITTFL = if_else(!is.na(ARM) & ARM != "", "Y", "N")
  )

# Valid exposure records
ex_valid <- pharmaversesdtm::ex %>%
  mutate(
    EXDOSE_NUM = suppressWarnings(as.numeric(EXDOSE)),
    valid_dose = EXDOSE_NUM > 0 | (EXDOSE_NUM == 0 & str_detect(toupper(EXTRT), "PLACEBO")),
    ex_date = as.Date(substr(EXSTDTC, 1, 10)),
    ex_dttm = as.POSIXct(if_else(nchar(EXSTDTC) <= 10,
                                 paste0(EXSTDTC, "T00:00:00"),
                                 str_replace(EXSTDTC, "$", if_else(str_detect(EXSTDTC, "T\\d{2}:\\d{2}$"), ":00", ""))),
                         format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  ) %>%
  filter(valid_dose, !is.na(ex_date))

trt_first <- ex_valid %>%
  group_by(USUBJID) %>%
  summarise(TRTSDTM = min(ex_dttm, na.rm = TRUE), .groups = "drop")

# ABNSBPFL
abn_sbp <- pharmaversesdtm::vs %>%
  filter(VSTESTCD == "SYSBP", VSSTRESU == "mmHg") %>%
  mutate(VSSTRESN = suppressWarnings(as.numeric(VSSTRESN))) %>%
  group_by(USUBJID) %>%
  summarise(ABNSBPFL = if_else(any(VSSTRESN < 100 | VSSTRESN >= 140, na.rm = TRUE), "Y", "N"), .groups = "drop")

# Last alive date components
vitals_last <- pharmaversesdtm::vs %>%
  filter(!(is.na(VSSTRESN) & is.na(VSSTRESC))) %>%
  mutate(dt = as.Date(substr(VSDTC, 1, 10))) %>%
  group_by(USUBJID) %>%
  summarise(vs_last = max(dt, na.rm = TRUE), .groups = "drop")

ae_last <- pharmaversesdtm::ae %>%
  mutate(dt = as.Date(substr(AESTDTC, 1, 10))) %>%
  group_by(USUBJID) %>%
  summarise(ae_last = max(dt, na.rm = TRUE), .groups = "drop")

ds_last <- pharmaversesdtm::ds %>%
  mutate(dt = as.Date(substr(DSSTDTC, 1, 10))) %>%
  group_by(USUBJID) %>%
  summarise(ds_last = max(dt, na.rm = TRUE), .groups = "drop")

ex_last <- ex_valid %>%
  group_by(USUBJID) %>%
  summarise(ex_last = max(ex_date, na.rm = TRUE), .groups = "drop")

# Cardiac population flag
carpop <- pharmaversesdtm::ae %>%
  mutate(is_cardiac = toupper(AESOC) == "CARDIAC DISORDERS") %>%
  group_by(USUBJID) %>%
  summarise(CARPOPFL = if_else(any(is_cardiac, na.rm = TRUE), "Y", NA_character_), .groups = "drop")

adsl <- adsl %>%
  left_join(trt_first, by = "USUBJID") %>%
  left_join(abn_sbp, by = "USUBJID") %>%
  left_join(vitals_last, by = "USUBJID") %>%
  left_join(ae_last, by = "USUBJID") %>%
  left_join(ds_last, by = "USUBJID") %>%
  left_join(ex_last, by = "USUBJID") %>%
  left_join(carpop, by = "USUBJID") %>%
  rowwise() %>%
  mutate(LSTALVDT = max(c(vs_last, ae_last, ds_last, ex_last), na.rm = TRUE)) %>%
  ungroup() %>%
  select(-vs_last, -ae_last, -ds_last, -ex_last)

print(adsl, n = 20)

# Optional save
# write.csv(adsl, file = "question_3_adam/adsl.csv", row.names = FALSE)
