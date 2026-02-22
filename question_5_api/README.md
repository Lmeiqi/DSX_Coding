# Question 5: Clinical Data API (FastAPI)

A simple RESTful API that serves clinical trial AE data, supports dynamic cohort filtering, and calculates patient safety risk scores.

---

## Setup

**1. Install dependencies**
```bash
cd question_5_api
pip install -r requirements.txt
```

**2. Run the API**
```bash
uvicorn main:app --reload
```

API runs at `http://127.0.0.1:8000`  
Interactive docs at `http://127.0.0.1:8000/docs`

---

## Endpoints

### `GET /`
Returns a welcome message confirming the API is running.

```bash
curl http://127.0.0.1:8000/
```
```json
{"message": "Clinical Trial Data API is running"}
```

---

### `POST /ae-query`
Filter AE records by severity and/or treatment arm. Both fields are optional — omit either to include all values for that dimension.

**Request body:**
```json
{
  "severity": ["MILD", "MODERATE"],
  "treatment_arm": "Placebo"
}
```

```bash
curl -X POST http://127.0.0.1:8000/ae-query \
  -H "Content-Type: application/json" \
  -d '{"severity": ["MILD", "MODERATE"], "treatment_arm": "Placebo"}'
```

**Response:**
```json
{
  "record_count": 293,
  "unique_subjects": ["01-701-1015", "01-701-1023", "..."]
}
```

---

### `GET /subject-risk/{subject_id}`
Calculates a safety risk score for a subject based on their AE severities.

| Severity | Points |
|----------|--------|
| MILD     | 1      |
| MODERATE | 3      |
| SEVERE   | 5      |

| Score  | Category |
|--------|----------|
| < 5    | Low      |
| 5 – 14 | Medium   |
| ≥ 15   | High     |

```bash
curl http://127.0.0.1:8000/subject-risk/01-701-1015
```

**Response:**
```json
{
  "subject_id": "01-701-1015",
  "risk_score": 3,
  "risk_category": "Low"
}
```

Returns `404` if the subject is not found.
