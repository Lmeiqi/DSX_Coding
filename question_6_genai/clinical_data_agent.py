import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List

import pandas as pd


@dataclass
class LLMOutput:
    target_column: str
    filter_value: str


class ClinicalTrialDataAgent:
    """Simple LLM-style agent with optional mocked parser for schema-aware querying."""

    schema_description = {
        "AESEV": "Severity of adverse event (MILD, MODERATE, SEVERE)",
        "AETERM": "Reported adverse event term (e.g., Headache)",
        "AESOC": "Body system / system organ class (e.g., Cardiac disorders)",
        "ACTARM": "Actual treatment arm",
    }

    def __init__(self, data_path: Path):
        self.df = pd.read_csv(data_path)

    def parse_question(self, question: str) -> LLMOutput:
        """Parse natural language to structured output (mocked fallback logic)."""
        q = question.strip()
        q_upper = q.upper()

        if any(word in q_upper for word in ["SEVERITY", "INTENSITY", "MILD", "MODERATE", "SEVERE"]):
            for sev in ["SEVERE", "MODERATE", "MILD"]:
                if sev in q_upper:
                    return LLMOutput(target_column="AESEV", filter_value=sev)
            return LLMOutput(target_column="AESEV", filter_value="MODERATE")

        if any(word in q_upper for word in ["CARDIAC", "SKIN", "DISORDERS", "SYSTEM"]):
            match = re.search(r"(cardiac|skin|gastrointestinal|nervous)", q, flags=re.IGNORECASE)
            value = match.group(1) if match else "Cardiac"
            return LLMOutput(target_column="AESOC", filter_value=value)

        term_match = re.search(r"had\s+(.+?)\s*(adverse|events|event|$)", q, flags=re.IGNORECASE)
        if term_match:
            return LLMOutput(target_column="AETERM", filter_value=term_match.group(1).strip())

        return LLMOutput(target_column="AETERM", filter_value=q)

    def execute_query(self, parsed: LLMOutput) -> Dict[str, List[str]]:
        col = parsed.target_column
        val = parsed.filter_value

        if col not in self.df.columns:
            raise ValueError(f"Column '{col}' not found in dataset")

        matches = self.df[self.df[col].astype(str).str.contains(re.escape(val), case=False, na=False)]
        subjects = sorted(matches["USUBJID"].dropna().unique().tolist())
        return {
            "target_column": col,
            "filter_value": val,
            "unique_subject_count": len(subjects),
            "subjects": subjects,
        }


def _to_json(result: dict) -> str:
    return json.dumps(result, indent=2)


if __name__ == "__main__":
    data_path = Path(__file__).resolve().parent / "adae.csv"
    agent = ClinicalTrialDataAgent(data_path)

    queries = [
        "Give me the subjects who had adverse events of Moderate severity",
        "Which subjects had Headache adverse events?",
        "Show me patients with Cardiac disorders",
    ]

    for q in queries:
        parsed = agent.parse_question(q)
        result = agent.execute_query(parsed)
        print(f"\nQuestion: {q}")
        print(_to_json(result))
