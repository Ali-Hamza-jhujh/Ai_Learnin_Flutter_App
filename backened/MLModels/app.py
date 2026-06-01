from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
import os

from predict import (
    predict_exam_score,
    detect_weak_topics,
    analyze_performance,
    get_study_recommendations,
)

# ══════════════════════════════════════════
# APP SETUP
# ══════════════════════════════════════════

app = FastAPI(
    title="StudyAI ML Service",
    description="Exam prediction, weak topic detection, performance analysis",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Node.js backend calls this internally
    allow_methods=["*"],
    allow_headers=["*"],
)

# ══════════════════════════════════════════
# REQUEST / RESPONSE MODELS
# ══════════════════════════════════════════

class TestResult(BaseModel):
    subject: str
    chapter: str
    totalQuestions: int
    correctAnswers: int
    wrongAnswers: int
    skippedAnswers: int
    scorePercent: float
    timeTakenSeconds: Optional[int] = 0
    difficulty: Optional[str] = "medium"  # easy | medium | hard

class PerformanceRequest(BaseModel):
    # List of all test results for a user
    results: List[TestResult]
    educationLevel: Optional[str] = "undergraduate"

class PredictionRequest(BaseModel):
    # All past test results for the user
    results: List[TestResult]
    # The subject/chapter to predict for
    targetSubject: str
    targetChapter: Optional[str] = ""
    educationLevel: Optional[str] = "undergraduate"

# ══════════════════════════════════════════
# ROUTES
# ══════════════════════════════════════════

@app.get("/")
def root():
    return {
        "message": "StudyAI ML Service is running 🤖",
        "endpoints": {
            "health": "/health",
            "predict": "/predict",
            "weak-topics": "/weak-topics",
            "performance": "/performance",
            "recommendations": "/recommendations",
        }
    }

@app.get("/health")
def health():
    return {"status": "ok", "service": "StudyAI ML Service"}

# ─── EXAM SCORE PREDICTION ────────────────
#
# Given past test results, predicts what score
# the user is likely to get in an upcoming exam.
#
@app.post("/predict")
def predict(req: PredictionRequest):
    try:
        if len(req.results) == 0:
            raise HTTPException(
                status_code=400,
                detail="At least one test result is required for prediction"
            )

        result = predict_exam_score(
            results=[r.dict() for r in req.results],
            target_subject=req.targetSubject,
            target_chapter=req.targetChapter,
            education_level=req.educationLevel,
        )

        return {"prediction": result}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ─── WEAK TOPIC DETECTION ─────────────────
#
# Finds which subjects/chapters the user
# consistently scores poorly in.
#
@app.post("/weak-topics")
def weak_topics(req: PerformanceRequest):
    try:
        if len(req.results) == 0:
            raise HTTPException(
                status_code=400,
                detail="At least one test result is required"
            )

        topics = detect_weak_topics([r.dict() for r in req.results])
        return {"weakTopics": topics}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ─── PERFORMANCE ANALYSIS ─────────────────
#
# Full breakdown — trends, averages, best/worst
# subjects, improvement over time.
#
@app.post("/performance")
def performance(req: PerformanceRequest):
    try:
        if len(req.results) == 0:
            raise HTTPException(
                status_code=400,
                detail="At least one test result is required"
            )

        analysis = analyze_performance([r.dict() for r in req.results])
        return {"analysis": analysis}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ─── STUDY RECOMMENDATIONS ────────────────
#
# Based on weak topics + performance, returns
# a prioritized list of what to study next.
#
@app.post("/recommendations")
def recommendations(req: PerformanceRequest):
    try:
        if len(req.results) == 0:
            raise HTTPException(
                status_code=400,
                detail="At least one test result is required"
            )

        recs = get_study_recommendations([r.dict() for r in req.results])
        return {"recommendations": recs}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ══════════════════════════════════════════
# START
# ══════════════════════════════════════════

if __name__ == "__main__":
    port = int(os.environ.get("ML_PORT", 8000))
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=True)