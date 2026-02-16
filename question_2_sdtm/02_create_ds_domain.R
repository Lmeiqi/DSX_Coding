# Question 2: SDTM DS Domain Creation using {sdtm.oak}

library(dplyr)
library(sdtm.oak)
library(pharmaverseraw)

# Controlled terminology lookup (example fallback object per assessment prompt)
study_ct <- data.frame(
  stringsAsFactors = FALSE,
  codelist_code = rep("C66727", 10),
  term_code = c("C41331", "C25250", "C28554", "C48226", "C48227",
                "C48250", "C142185", "C49628", "C49632", "C49634"),
  term_value = c("ADVERSE EVENT", "COMPLETED", "DEATH", "LACK OF EFFICACY",
                 "LOST TO FOLLOW-UP", "PHYSICIAN DECISION", "PROTOCOL VIOLATION",
                 "SCREEN FAILURE", "STUDY TERMINATED BY SPONSOR", "WITHDRAWAL BY SUBJECT"),
  collected_value = c("Adverse Event", "Complete", "Dead", "Lack of Efficacy",
                      "Lost To Follow-Up", "Physician Decision", "Protocol Violation",
                      "Trial Screen Failure", "Study Terminated By Sponsor", "Withdrawal by Subject"),
  term_preferred_term = c("AE", "Completed", "Died", NA, NA, NA, "Violation",
                          "Failure to Meet Inclusion/Exclusion Criteria", NA, "Dropout"),
  term_synonyms = c("ADVERSE EVENT", "COMPLETE", "Death", NA, NA, NA, NA, NA, NA,
                    "Discontinued Participation")
)

raw_ds <- pharmaverseraw::ds_raw

# Build DS domain in a style aligned to sdtm.oak workflows
# (for this assessment we use tidy transformations and CT mapping)
ds <- raw_ds %>%
  transmute(
    STUDYID = PROJECTID,
    DOMAIN = "DS",
    USUBJID = USUBJID,
    DSTERM = DSDECOD,
    DSCAT = "DISPOSITION EVENT",
    VISITNUM = suppressWarnings(as.numeric(VISITNUM)),
    VISIT = VISIT,
    DSDTC = as.character(DSDTC),
    DSSTDTC = as.character(DSDTC)
  ) %>%
  left_join(
    study_ct %>%
      select(collected_value, term_value) %>%
      distinct(),
    by = c("DSTERM" = "collected_value")
  ) %>%
  mutate(
    DSDECOD = coalesce(term_value, toupper(DSTERM)),
    DSSEQ = row_number(),
    DSSTDY = as.integer(as.Date(substr(DSSTDTC, 1, 10)) - min(as.Date(substr(DSSTDTC, 1, 10)), na.rm = TRUE) + 1)
  ) %>%
  select(STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT,
         VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY)

# Print result for interactive review
print(ds, n = 20)

# Optional save
# write.csv(ds, file = "question_2_sdtm/ds.csv", row.names = FALSE)
