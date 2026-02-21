# Question 4.2: Visualizations using {ggplot2}

library(dplyr)
library(ggplot2)
library(pharmaverseadam)

adae <- pharmaverseadam::adae

# Plot 1: severity distribution by treatment
p1 <- adae %>%
  count(ACTARM, AESEV) %>%
  ggplot(aes(x = ACTARM, y = n, fill = AESEV)) +
  geom_col(position = "stack") +
  labs(
    title = "AE Severity Distribution by Treatment",
    x = "Treatment Arm",
    y = "Count of AEs"
  ) +
  theme(
    # --- Text Sizing ---
    plot.title = element_text(size = 10),      # Main Title
    axis.title = element_text(size = 8),       # "Treatment Arm" and "Count of AEs"
    axis.text = element_text(size = 7),        # Words under bars and Y-axis numbers
    
    # --- Legend Sizing ---
    legend.title = element_text(size = 8),     # The word "AESEV"
    legend.text = element_text(size = 7),      # The severity levels (Mild, Moderate, etc.)
    legend.key.size = unit(0.4, "cm")          # Shrinks the actual colored boxes in legend
    )
p1

ggsave("question_4_tlg/output/ae_severity_distribution.png", p1, width = 10, height = 6, dpi = 300)

# Plot 2: Top 10 most frequent AEs with 95% CI for incidence rates
n_subj <- n_distinct(adae$USUBJID)

top_ae <- adae %>%
  distinct(USUBJID, AETERM) %>%
  count(AETERM, sort = TRUE) %>%
  slice_head(n = 10) %>%
  rowwise() %>% # test runs for each AE term
  mutate(
    p = n / n_subj,
    bt = list(stats::binom.test(n, n_subj, conf.level = 0.95)),
    lcl = bt$conf.int[1],
    ucl = bt$conf.int[2]
  ) %>%
  ungroup()

subtitle_txt <- sprintf(
  "n = %d subjects; 95%% Clopper–Pearson CIs",
  n_subj
)

p2 <- top_ae %>%
  ggplot(aes(x = reorder(AETERM, p), y = p)) +
  geom_point(size=3) +
  geom_errorbar(aes(ymin = lcl, ymax = ucl), width = 0.2) +
  coord_flip() +
  scale_y_continuous(labels = scales::percent_format()) +
  labs(
    title = "Top 10 Most Frequent Adverse Events",
    subtitle = subtitle_txt,
    y = "Percentage of Patients (%)",
    x=NULL
  ) 

ggsave("question_4_tlg/output/top10_ae_ci.png", p2, width = 10, height = 6, dpi = 300)
