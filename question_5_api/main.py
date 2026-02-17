from pathlib import Path
from typing import List, Optional

import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

DATA_PATH = Path(__file__).resolve().parent / "adae.csv"

app = FastAPI(title="Clinical Trial Data API")


class AEQueryRequest(BaseModel):
    severity: Optional[List[str]] = None
    treatment_arm: Optional[str] = None


def load_data() -> pd.DataFrame:
    if not DATA_PATH.exists():
        raise FileNotFoundError(f"Missing input file: {DATA_PATH}")
    return pd.read_csv(DATA_PATH)


@app.get("/")
def root():
    return {"message": "Clinical Trial Data API is running"}


@app.post("/ae-query")
def ae_query(payload: AEQueryRequest):
    df = load_data()

    if payload.severity:
      df = df[df["AESEV"].isin([s.upper() for s in payload.severity])]

    if payload.treatment_arm:
      df = df[df["ACTARM"].str.upper() == payload.treatment_arm.upper()]

    unique_subjects = sorted(df["USUBJID"].dropna().unique().tolist())
    return {
        "count": int(len(df)),
        "unique_subject_count": int(len(unique_subjects)),
        "subjects": unique_subjects,
    }


@app.get("/subject-risk/{subject_id}")
def subject_risk(subject_id: str):
    df = load_data()
    sdf = df[df["USUBJID"] == subject_id]
    if sdf.empty:
        raise HTTPException(status_code=404, detail=f"subject_id '{subject_id}' not found")

    weights = {"MILD": 1, "MODERATE": 3, "SEVERE": 5}
    score = int(sdf["AESEV"].astype(str).str.upper().map(weights).fillna(0).sum())

    if score < 5:
        category = "Low"
    elif score < 15:
        category = "Medium"
    else:
        category = "High"

    return {
        "subject_id": subject_id,
        "risk_score": score,
        "risk_category": category,
    }
