# DSX Data Scientist Coding Assessment Solutions

This repository contains solutions for all six assessment questions, organized by question.

## Repository Structure

- `question_1/descriptive_stats/`: R package `descriptiveStats` with documented functions and tests.
- `question_2_sdtm/02_create_ds_domain.R`: SDTM DS creation script.
- `question_3_adam/create_adsl.R`: ADSL derivation script using SDTM input.
- `question_4_tlg/`: TLG scripts for AE summary table, visualizations, and listings.
- `question_5_api/`: FastAPI clinical data API implementation.
- `question_6_genai/`: GenAI clinical data assistant implementation.

## Notes

- Scripts assume required R/Python packages are installed.
- `adae.csv` is expected in `question_5_api/` and `question_6_genai/` for Python questions.

## Quick Start

### R
Install required packages (example):

```r
install.packages(c("admiral", "sdtm.oak", "gt", "ggplot2", "gtsummary", "dplyr", "stringr"))
```

### Python API

```bash
cd question_5_api
pip install fastapi uvicorn pandas
uvicorn main:app --reload
```

### GenAI Assistant

```bash
cd question_6_genai
python clinical_data_agent.py
```
