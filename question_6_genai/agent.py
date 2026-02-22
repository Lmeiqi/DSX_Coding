"""
=============================================================================
Question 6: GenAI Clinical Data Assistant (LLM & LangChain)
=============================================================================
Purpose  : Natural-language to Pandas query translator for AE data
           Uses an LLM to map free-text questions → structured filter JSON
           then executes the filter on the adae DataFrame.

Input    : adae.csv (same file as Question 5)
Key classes:
  ClinicalTrialDataAgent  - Wraps LLM prompt + parse + execute logic

Usage:
  python agent.py

NOTE: Set OPENAI_API_KEY environment variable to use real OpenAI responses.
      When the key is missing the code falls back to a rule-based mock so
      the full Prompt → Parse → Execute pipeline remains demonstrable.
=============================================================================
"""

from __future__ import annotations

import json
import os
import re
from typing import Optional

import pandas as pd

# ── Optional LangChain / OpenAI imports (graceful fallback) ───────────────────
try:
    from langchain_openai import ChatOpenAI
    from langchain_core.prompts import ChatPromptTemplate
    from langchain_core.output_parsers import StrOutputParser
    _LANGCHAIN_AVAILABLE = True
except ImportError:
    _LANGCHAIN_AVAILABLE = False

# ── 1. Load AE dataset ────────────────────────────────────────────────────────
try:
    _df = pd.read_csv("adae.csv")
except FileNotFoundError:
    _df = pd.read_csv("question_5_api/adae.csv")

_df.columns = [c.strip() for c in _df.columns]

# ── 2. Dataset schema description (passed to LLM) ─────────────────────────────
SCHEMA_DESCRIPTION = """
You are a clinical data assistant that filters an adverse event (AE) dataset.
The dataset has the following relevant columns:

| Column   | Description                                       | Example values                 |
|----------|---------------------------------------------------|-------------------------------|
| USUBJID  | Unique subject identifier                         | "01-701-1015"                  |
| AETERM   | Reported term for the adverse event               | "DIZZINESS", "HEADACHE"        |
| AESOC    | Primary system organ class (body system)          | "CARDIAC DISORDERS", "SKIN..." |
| AESEV    | Severity or intensity of the AE                   | "MILD", "MODERATE", "SEVERE"   |
| AEREL    | Causality / relationship to study drug            | "POSSIBLE", "PROBABLE", "NONE" |
| ACTARM   | Actual treatment arm                              | "Placebo", "Xanomeline High Dose" |
| AESTDTC  | Start date of the AE (ISO 8601)                   | "2012-08-05"                   |
| TRTEMFL  | Treatment-emergent flag                           | "Y" or missing                 |

Your job is to parse a user's natural-language question and return a JSON object with:
  - "target_column": the column name to filter on (one of: AETERM, AESOC, AESEV, AEREL, ACTARM)
  - "filter_value": the value to match (as a string, upper-cased where appropriate)
  - "match_type": "exact" or "contains" (use "contains" for partial keyword searches)

Respond ONLY with a valid JSON object and nothing else.  Example:
{"target_column": "AESEV", "filter_value": "MODERATE", "match_type": "exact"}
"""

# ── 3. Mock LLM (rule-based fallback) ────────────────────────────────────────

def _mock_llm_parse(question: str) -> dict:
    """Rule-based parser that mimics an LLM response.

    Maps common clinical question patterns to the correct column + value.
    Used when OPENAI_API_KEY is not set or LangChain is not installed.
    """
    q = question.lower()

    # Severity / intensity keywords
    if any(w in q for w in ["severity", "intensity", "severe", "mild", "moderate"]):
        for sev in ("SEVERE", "MODERATE", "MILD"):
            if sev.lower() in q:
                return {"target_column": "AESEV", "filter_value": sev, "match_type": "exact"}
        return {"target_column": "AESEV", "filter_value": "MODERATE", "match_type": "exact"}

    # Body system / SOC keywords
    soc_keywords = {
        "cardiac": "CARDIAC DISORDERS",
        "heart": "CARDIAC DISORDERS",
        "skin": "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
        "dermat": "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
        "nervous": "NERVOUS SYSTEM DISORDERS",
        "gastrointestinal": "GASTROINTESTINAL DISORDERS",
        "gi": "GASTROINTESTINAL DISORDERS",
    }
    for kw, soc_val in soc_keywords.items():
        if kw in q:
            return {"target_column": "AESOC", "filter_value": soc_val, "match_type": "exact"}

    # Specific AE term (fall-through: assume AETERM contains keyword)
    # Extract likely term: noun-ish word after "had" / "with" / "experiencing"
    patterns = [r"(?:had|with|experienced?|reported?)\s+([a-z\s]+?)(?:\s+adverse|\s+ae|\s*$)",
                r"(?:adverse event[s]? of?|ae[s]? (?:called|named|termed)?)\s+([a-z\s]+?)(?:\s+ae|\s*$)"]
    for pat in patterns:
        m = re.search(pat, q)
        if m:
            term_guess = m.group(1).strip().upper()
            if len(term_guess) > 2:
                return {"target_column": "AETERM", "filter_value": term_guess, "match_type": "contains"}

    # Default fallback
    return {"target_column": "AETERM", "filter_value": "", "match_type": "contains"}


# ── 4. ClinicalTrialDataAgent ─────────────────────────────────────────────────

class ClinicalTrialDataAgent:
    """Translates natural-language clinical questions into Pandas filters.

    Workflow:
        1. Prompt  – Construct a schema-aware prompt for the LLM.
        2. Parse   – Extract structured JSON from the LLM response.
        3. Execute – Apply the Pandas filter and return matching subjects.
    """

    def __init__(
        self,
        df: pd.DataFrame,
        openai_api_key: Optional[str] = None,
        model_name: str = "gpt-4o-mini",
    ) -> None:
        self._df = df
        self._api_key = openai_api_key or os.getenv("OPENAI_API_KEY")
        self._use_llm = _LANGCHAIN_AVAILABLE and bool(self._api_key)

        if self._use_llm:
            self._llm = ChatOpenAI(
                model=model_name,
                api_key=self._api_key,
                temperature=0,
            )
            self._prompt = ChatPromptTemplate.from_messages([
                ("system", SCHEMA_DESCRIPTION),
                ("human", "{question}"),
            ])
            self._chain = self._prompt | self._llm | StrOutputParser()
            print("[Agent] Using OpenAI LLM via LangChain.")
        else:
            print("[Agent] OpenAI key not found — using rule-based mock LLM.")

    # ── Step 1+2: Prompt → Parse ────────────────────────────────────────────
    def _parse_question(self, question: str) -> dict:
        """Send question to LLM (or mock) and parse the JSON response."""
        if self._use_llm:
            raw_response = self._chain.invoke({"question": question})
            # Strip markdown fences if present
            raw_response = re.sub(r"```(?:json)?|```", "", raw_response).strip()
            try:
                parsed = json.loads(raw_response)
            except json.JSONDecodeError as exc:
                raise ValueError(
                    f"LLM returned non-JSON output: {raw_response}"
                ) from exc
        else:
            parsed = _mock_llm_parse(question)

        # Validate structure
        required_keys = {"target_column", "filter_value", "match_type"}
        if not required_keys.issubset(parsed.keys()):
            raise ValueError(f"LLM output missing required keys. Got: {parsed}")

        return parsed

    # ── Step 3: Execute filter ──────────────────────────────────────────────
    def _execute_filter(self, parsed: dict) -> pd.DataFrame:
        """Apply the parsed filter to the AE DataFrame."""
        col        = parsed["target_column"]
        value      = parsed["filter_value"]
        match_type = parsed.get("match_type", "exact")

        if col not in self._df.columns:
            raise ValueError(f"Column '{col}' not found in dataset.")

        col_series = self._df[col].fillna("").astype(str).str.upper()
        value_upper = value.strip().upper()

        if match_type == "contains":
            mask = col_series.str.contains(value_upper, regex=False)
        else:  # exact
            mask = col_series == value_upper

        return self._df[mask]

    # ── Public interface ────────────────────────────────────────────────────
    def ask(self, question: str) -> dict:
        """Full pipeline: natural-language question → result dict.

        Returns:
            dict with keys:
              - question       : original question
              - parsed_filter  : the structured filter the LLM produced
              - subject_count  : number of unique matching subjects
              - subject_ids    : sorted list of matching USUBJIDs
        """
        print(f"\n[Agent] Question : {question}")

        parsed  = self._parse_question(question)
        print(f"[Agent] Filter   : {parsed}")

        results = self._execute_filter(parsed)
        unique_subjects = sorted(results["USUBJID"].dropna().unique().tolist())

        output = {
            "question": question,
            "parsed_filter": parsed,
            "subject_count": len(unique_subjects),
            "subject_ids": unique_subjects,
        }
        print(f"[Agent] Subjects : {output['subject_count']} found")
        return output


# ── 5. Test script ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    agent = ClinicalTrialDataAgent(df=_df)

    example_questions = [
        "Give me the subjects who had Adverse events of Moderate severity",
        "Which patients experienced cardiac adverse events?",
        "Show me subjects who had a headache",
    ]

    print("\n" + "=" * 65)
    print("  ClinicalTrialDataAgent — Example Query Results")
    print("=" * 65)

    for q in example_questions:
        result = agent.ask(q)
        print(f"\nQuestion  : {result['question']}")
        print(f"Filter    : {result['parsed_filter']}")
        print(f"Subjects  : {result['subject_count']}")
        preview = result["subject_ids"][:5]
        if result["subject_ids"]:
            print(f"First IDs : {preview}{'...' if len(result['subject_ids']) > 5 else ''}")
        print("-" * 65)
