# Question 4.3: AE Listings using {gtsummary}

library(dplyr)
library(gt)
library(pharmaverseadam)

adae_listing <- pharmaverseadam::adae %>%
  filter(TRTEMFL == "Y") %>%
  arrange(USUBJID, ASTDT) %>%
  select(USUBJID, ACTARM, AETERM, AESEV, AEREL, ASTDT, AENDT)

listing_tbl <- gt::gt(adae_listing)

gt::gtsave(listing_tbl, "question_4_tlg/output/ae_listings.html")
