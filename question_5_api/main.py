"""
=============================================================================
Question 5: Clinical Data API (FastAPI)
=============================================================================
Purpose  : RESTful API serving clinical trial AE data
Input    : adae.csv
Endpoints:
  GET  /                            - Welcome message
  POST /ae-query                    - Dynamic cohort filtering
  GET  /subject-risk/{subject_id}   - Subject safety risk score

Run locally:
  uvicorn main:app --reload
=============================================================================
"""

from typing import List, Optional

import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Clinical Trial Data API",
    version="1.0.0",
)

# ── Load data at startup ──────────────────────────────────────────────────────
try:
    df = pd.read_csv("adae.csv")
except FileNotFoundError:
    df = pd.read_csv("question_5_api/adae.csv")

print(f"Loaded {len(df)} records, {df['USUBJID'].nunique()} subjects")

# ── Severity weights for risk score ──────────────────────────────────────────
SEVERITY_WEIGHTS = {"MILD": 1, "MODERATE": 3, "SEVERE": 5}

# ── Pydantic models ───────────────────────────────────────────────────────────

class AEQueryRequest(BaseModel):
    severity: Optional[List[str]] = None
    treatment_arm: Optional[str] = None

class AEQueryResponse(BaseModel):
    record_count: int
    unique_subjects: List[str]

class RiskScoreResponse(BaseModel):
    subject_id: str
    risk_score: int
    risk_category: str

# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {"message": "Clinical Trial Data API is running"}


@app.post("/ae-query", response_model=AEQueryResponse)
def ae_query(request: AEQueryRequest):
    """Filter AE data by severity and/or treatment arm.
    Omitting a field means no filter is applied on that dimension.
    """
    filtered = df.copy()

    if request.severity:
        upper_sev = [s.upper() for s in request.severity]
        filtered = filtered[filtered["AESEV"].str.upper().isin(upper_sev)]

    if request.treatment_arm:
        filtered = filtered[
            filtered["ACTARM"].str.upper() == request.treatment_arm.upper()
        ]

    unique_subjects = sorted(filtered["USUBJID"].dropna().unique().tolist())

    return AEQueryResponse(
        record_count=len(filtered),
        unique_subjects=unique_subjects,
    )


@app.get("/subject-risk/{subject_id}", response_model=RiskScoreResponse)
def subject_risk(subject_id: str):
    """Calculate a safety risk score for a given subject.
    MILD=1, MODERATE=3, SEVERE=5.
    Low: <5 | Medium: 5-14 | High: >=15
    Returns 404 if subject_id not found.
    """
    subj_df = df[df["USUBJID"] == subject_id]

    if subj_df.empty:
        raise HTTPException(
            status_code=404,
            detail=f"Subject '{subject_id}' not found in the dataset.",
        )

    risk_score = int(
        subj_df["AESEV"]
        .str.upper()
        .map(SEVERITY_WEIGHTS)
        .fillna(0)
        .sum()
    )

    if risk_score < 5:
        risk_category = "Low"
    elif risk_score < 15:
        risk_category = "Medium"
    else:
        risk_category = "High"

    return RiskScoreResponse(
        subject_id=subject_id,
        risk_score=risk_score,
        risk_category=risk_category,
    )
