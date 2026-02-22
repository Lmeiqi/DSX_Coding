"""
=============================================================================
Question 5: Clinical Data API using FastAPI
=============================================================================
Purpose  : RESTful API to query adverse event data and compute risk scores
Input    : adae.csv (exported from pharmaverseadam::adae)
Endpoints:
  GET  /                          - Welcome message
  POST /ae-query                  - Dynamic cohort filtering
  GET  /subject-risk/{subject_id} - Subject safety risk score

Run locally:
  uvicorn main:app --reload
=============================================================================
"""

from __future__ import annotations

from enum import Enum
from typing import List, Optional

import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# ── App initialisation ────────────────────────────────────────────────────────
app = FastAPI(
    title="Clinical Trial Data API",
    description="API for querying adverse event data and computing patient risk scores.",
    version="1.0.0",
)

# ── Load data at startup ──────────────────────────────────────────────────────
# Expects adae.csv in the same directory.  Export from R:
#   write.csv(pharmaverseadam::adae, "question_5_api/adae.csv", row.names = FALSE)
try:
    _df = pd.read_csv("adae.csv")
except FileNotFoundError:
    # Fallback: try relative path for running from repo root
    _df = pd.read_csv("question_5_api/adae.csv")

# Normalise column names (strip whitespace, upper-case for safety)
_df.columns = [c.strip() for c in _df.columns]

# Ensure key columns exist; add placeholders if missing (for demo robustness)
_required_cols = {"USUBJID", "AESEV", "ACTARM", "AETERM", "AESOC", "TRTEMFL"}
_missing = _required_cols - set(_df.columns)
if _missing:
    raise RuntimeError(f"adae.csv is missing required columns: {_missing}")

print(f"[API] Loaded adae.csv — {len(_df)} rows, {_df['USUBJID'].nunique()} subjects")


# ── Severity weights ──────────────────────────────────────────────────────────
_SEVERITY_WEIGHTS = {
    "MILD": 1,
    "MODERATE": 3,
    "SEVERE": 5,
}

_RISK_THRESHOLDS = {
    "Low": (None, 5),
    "Medium": (5, 15),
    "High": (15, None),
}


def _assign_risk_category(score: int) -> str:
    """Map a total risk score to a risk category string."""
    if score < 5:
        return "Low"
    elif score < 15:
        return "Medium"
    else:
        return "High"


# ── Pydantic models ───────────────────────────────────────────────────────────

class AEQueryRequest(BaseModel):
    """Request body for the /ae-query endpoint.

    All fields are optional; omitting a field means 'no filter on that dimension'.
    """

    severity: Optional[List[str]] = None
    """List of severity values to include, e.g. ["MILD", "MODERATE"]."""

    treatment_arm: Optional[str] = None
    """Single treatment arm to filter on, e.g. "Placebo"."""

    model_config = {"json_schema_extra": {
        "examples": [{"severity": ["MILD", "MODERATE"], "treatment_arm": "Placebo"}]
    }}


class AEQueryResponse(BaseModel):
    record_count: int
    unique_subjects: List[str]


class RiskScoreResponse(BaseModel):
    subject_id: str
    risk_score: int
    risk_category: str


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/", summary="Health check / welcome message")
def root():
    """Returns a JSON welcome message confirming the API is running."""
    return {"message": "Clinical Trial Data API is running"}


@app.post(
    "/ae-query",
    response_model=AEQueryResponse,
    summary="Dynamic AE cohort filtering",
)
def ae_query(request: AEQueryRequest):
    """Filter the AE dataset dynamically based on severity and/or treatment arm.

    Fields omitted from the request body are ignored (all records retained for
    that dimension).

    Returns the count of matching records and the list of unique USUBJIDs.
    """
    filtered = _df.copy()

    # Apply severity filter (case-insensitive)
    if request.severity:
        upper_sev = [s.upper() for s in request.severity]
        filtered = filtered[filtered["AESEV"].str.upper().isin(upper_sev)]

    # Apply treatment arm filter (case-insensitive partial or full match)
    if request.treatment_arm:
        filtered = filtered[
            filtered["ACTARM"].str.upper() == request.treatment_arm.upper()
        ]

    unique_subjects = sorted(filtered["USUBJID"].dropna().unique().tolist())

    return AEQueryResponse(
        record_count=len(filtered),
        unique_subjects=unique_subjects,
    )


@app.get(
    "/subject-risk/{subject_id}",
    response_model=RiskScoreResponse,
    summary="Compute patient safety risk score",
)
def subject_risk(subject_id: str):
    """Calculate the Safety Risk Score for a given subject.

    - MILD AEs contribute 1 point each.
    - MODERATE AEs contribute 3 points each.
    - SEVERE AEs contribute 5 points each.

    Risk categories:
    - Low    : Total score < 5
    - Medium : 5 <= Total score < 15
    - High   : Total score >= 15

    Returns HTTP 404 if the subject_id is not found in the dataset.
    """
    subj_df = _df[_df["USUBJID"] == subject_id]

    if subj_df.empty:
        raise HTTPException(
            status_code=404,
            detail=f"Subject '{subject_id}' not found in the dataset.",
        )

    risk_score = int(
        subj_df["AESEV"]
        .str.upper()
        .map(_SEVERITY_WEIGHTS)
        .fillna(0)
        .sum()
    )

    return RiskScoreResponse(
        subject_id=subject_id,
        risk_score=risk_score,
        risk_category=_assign_risk_category(risk_score),
    )


# ── Entry point for direct execution ──────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
