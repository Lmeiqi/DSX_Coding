# Question 4.2: Visualizations using {ggplot2}

library(dplyr)
library(ggplot2)
library(pharmaverseadam)

adae <- pharmaverseadam::adae %>% filter(TRTEMFL == "Y")

# Plot 1: severity distribution by treatment
p1 <- adae %>%
  count(ACTARM, AESEV) %>%
  ggplot(aes(x = ACTARM, y = n, fill = AESEV)) +
  geom_col(position = "stack") +
  labs(
    title = "AE Severity Distribution by Treatment",
    x = "Treatment Arm",
    y = "Count"
  ) +
  theme_minimal()

ggsave("question_4_tlg/output/ae_severity_distribution.png", p1, width = 10, height = 6, dpi = 300)

# Plot 2: Top 10 frequent AEs with Wald 95% CI for incidence proportion
n_subj <- n_distinct(adae$USUBJID)

top_ae <- adae %>%
  distinct(USUBJID, AETERM) %>%
  count(AETERM, sort = TRUE) %>%
  slice_head(n = 10) %>%
  mutate(
    p = n / n_subj,
    se = sqrt((p * (1 - p)) / n_subj),
    lcl = pmax(0, p - 1.96 * se),
    ucl = pmin(1, p + 1.96 * se)
  )

p2 <- top_ae %>%
  ggplot(aes(x = reorder(AETERM, p), y = p)) +
  geom_point() +
  geom_errorbar(aes(ymin = lcl, ymax = ucl), width = 0.2) +
  coord_flip() +
  scale_y_continuous(labels = scales::percent_format()) +
  labs(
    title = "Top 10 Most Frequent AEs with 95% CI",
    x = "AE Term",
    y = "Incidence Proportion"
  ) +
  theme_minimal()

ggsave("question_4_tlg/output/top10_ae_ci.png", p2, width = 10, height = 6, dpi = 300)
