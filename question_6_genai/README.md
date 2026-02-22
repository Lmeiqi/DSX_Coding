# Question 6: GenAI Clinical Data Assistant

A natural-language query agent that translates free-text questions into Pandas filters on the AE dataset. Uses an LLM (OpenAI via LangChain) to map user intent to the correct column and value — no hard-coded rules needed when an API key is provided.

---

## File Structure

```
question_6_genai/
├── agent.py          # ClinicalTrialDataAgent class + 3 example queries
├── requirements.txt  # Python package dependencies
└── README.md         # This file
```

The agent reads `adae.csv` from `question_5_api/` — no separate copy needed.

---

## Setup

**1. Install dependencies**
```bash
cd question_6_genai
pip install -r requirements.txt
```

**2. (Optional) Set your OpenAI API key**
```bash
export OPENAI_API_KEY="sk-..."
```

If no key is set, the agent automatically falls back to a rule-based mock parser. The full Prompt → Parse → Execute pipeline still runs — only the LLM call is replaced.

**3. Run the agent**
```bash
python agent.py
```

---

## How It Works

The agent follows a 3-step pipeline for every question:

```
User question
     │
     ▼
1. PROMPT  — question + dataset schema sent to LLM
     │
     ▼
2. PARSE   — LLM returns structured JSON:
             {"target_column": "AESEV", "filter_value": "MODERATE", "match_type": "exact"}
     │
     ▼
3. EXECUTE — Pandas filter applied to adae DataFrame
             → returns subject count + list of USUBJIDs
```

---

## Dataset Schema

The agent understands the following columns from `adae.csv`:

| Column    | Description                          | Example values                                  |
|-----------|--------------------------------------|-------------------------------------------------|
| `USUBJID` | Unique subject identifier            | `01-701-1015`                                   |
| `AETERM`  | Reported term for the adverse event  | `DIZZINESS`, `APPLICATION SITE ERYTHEMA`        |
| `AESOC`   | Primary system organ class           | `CARDIAC DISORDERS`, `NERVOUS SYSTEM DISORDERS` |
| `AESEV`   | Severity / intensity                 | `MILD`, `MODERATE`, `SEVERE`                    |
| `AEREL`   | Causality / relationship to drug     | `PROBABLE`, `POSSIBLE`, `REMOTE`, `NONE`        |
| `ACTARM`  | Actual treatment arm                 | `Placebo`, `Xanomeline High Dose`, `Xanomeline Low Dose` |

---

## Example Queries

The following 3 queries run automatically when you execute `python agent.py`:

**Query 1 — Filter by severity**
```
Question : Give me the subjects who had Adverse events of Moderate severity
Filter   : {"target_column": "AESEV", "filter_value": "MODERATE", "match_type": "exact"}
```

**Query 2 — Filter by body system (SOC)**
```
Question : Which patients experienced cardiac adverse events?
Filter   : {"target_column": "AESOC", "filter_value": "CARDIAC DISORDERS", "match_type": "exact"}
```

**Query 3 — Filter by AE term**
```
Question : Show me subjects who had a headache
Filter   : {"target_column": "AETERM", "filter_value": "HEADACHE", "match_type": "contains"}
```

**Output format for each query:**
```
Question  : Give me the subjects who had Adverse events of Moderate severity
Filter    : {'target_column': 'AESEV', 'filter_value': 'MODERATE', 'match_type': 'exact'}
Subjects  : 127
First IDs : ['01-701-1015', '01-701-1023', '01-701-1028', '01-701-1034', '01-701-1047']...
```

---

## Using the Agent in Your Own Code

```python
from agent import ClinicalTrialDataAgent
import pandas as pd

df = pd.read_csv("question_5_api/adae.csv")
agent = ClinicalTrialDataAgent(df=df)

result = agent.ask("Show me subjects with severe adverse events")
print(result["subject_count"])   # number of matching subjects
print(result["subject_ids"])     # list of USUBJIDs
print(result["parsed_filter"])   # the JSON filter the LLM produced
```

---

## With vs Without OpenAI API Key

| | With API Key | Without API Key |
|---|---|---|
| LLM | OpenAI GPT-4o-mini via LangChain | Rule-based mock parser |
| Flexibility | Handles any free-text question | Handles common patterns (severity, SOC, term) |
| Pipeline | Full Prompt → Parse → Execute | Full Prompt → Parse → Execute |
| Output format | Identical | Identical |

---

## Dependencies

```
langchain>=0.2.0
langchain-openai>=0.1.0
openai>=1.30.0
pandas>=2.0.0
```

Install with:
```bash
pip install -r requirements.txt
```
