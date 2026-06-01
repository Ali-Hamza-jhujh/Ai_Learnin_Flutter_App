import numpy as np
from collections import defaultdict
from typing import List, Dict, Any, Optional

# ══════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════

# Difficulty multiplier — harder tests count more toward prediction
DIFFICULTY_WEIGHT = {"easy": 0.7, "medium": 1.0, "hard": 1.3}

# Score thresholds
WEAK_THRESHOLD = 50      # below 50% = weak topic
AVERAGE_THRESHOLD = 65   # below 65% = needs improvement
STRONG_THRESHOLD = 80    # above 80% = strong topic


def _weighted_score(score: float, difficulty: str) -> float:
    """Normalize score by difficulty so hard tests aren't penalized unfairly."""
    weight = DIFFICULTY_WEIGHT.get(difficulty, 1.0)
    # Scale score up for hard tests — 60% on hard ≈ 78% normalized
    return min(score * weight, 100.0)


def _trend(scores: List[float]) -> str:
    """Detect if performance is improving, declining, or stable."""
    if len(scores) < 2:
        return "insufficient_data"
    # Simple linear regression slope
    x = np.arange(len(scores))
    slope = np.polyfit(x, scores, 1)[0]
    if slope > 3:
        return "improving"
    elif slope < -3:
        return "declining"
    return "stable"


def _grade(score: float) -> str:
    if score >= 85: return "A"
    if score >= 70: return "B"
    if score >= 55: return "C"
    if score >= 40: return "D"
    return "F"


def _prediction_message(predicted: float, trend: str) -> str:
    grade = _grade(predicted)
    trend_msg = {
        "improving": "Your performance is trending upward — keep it up!",
        "declining": "Your recent scores are dropping — increase study time.",
        "stable": "Your performance is consistent.",
        "insufficient_data": "Complete more tests for a more accurate prediction.",
    }.get(trend, "")

    if predicted >= 85:
        msg = f"Excellent! You are predicted to score around {predicted:.0f}% (Grade {grade})."
    elif predicted >= 65:
        msg = f"Good performance predicted — around {predicted:.0f}% (Grade {grade}). Review weak areas."
    elif predicted >= 40:
        msg = f"Predicted score is {predicted:.0f}% (Grade {grade}). Significant revision recommended."
    else:
        msg = f"At risk — predicted score is {predicted:.0f}% (Grade {grade}). Intensive study needed immediately."

    return f"{msg} {trend_msg}".strip()


# ══════════════════════════════════════════
# 1. EXAM SCORE PREDICTION
# ══════════════════════════════════════════

def predict_exam_score(
    results: List[Dict],
    target_subject: str,
    target_chapter: Optional[str] = "",
    education_level: Optional[str] = "undergraduate",
) -> Dict[str, Any]:
    """
    Predicts exam score for a given subject using weighted moving average
    with recency bias (recent tests matter more) and difficulty normalization.
    """

    # Filter results for the target subject
    subject_results = [
        r for r in results
        if r.get("subject", "").lower() == target_subject.lower()
    ]

    # If chapter specified, also include chapter-specific results
    if target_chapter:
        chapter_results = [
            r for r in subject_results
            if target_chapter.lower() in r.get("chapter", "").lower()
        ]
    else:
        chapter_results = subject_results

    # Fall back to all subject results if no chapter match
    base_results = chapter_results if chapter_results else subject_results

    # Fall back to ALL results if no subject match
    if not base_results:
        base_results = results

    if not base_results:
        return {
            "predictedScore": 0,
            "grade": "N/A",
            "confidence": "low",
            "message": "No test data available. Complete some tests first.",
            "trend": "insufficient_data",
            "basedOn": 0,
        }

    # Extract weighted scores (normalize by difficulty)
    weighted_scores = [
        _weighted_score(r["scorePercent"], r.get("difficulty", "medium"))
        for r in base_results
    ]

    n = len(weighted_scores)

    # Recency-weighted average — recent tests get higher weight
    # weights: [1, 2, 3, ..., n] so latest test has highest weight
    weights = np.arange(1, n + 1, dtype=float)
    weighted_avg = float(np.average(weighted_scores, weights=weights))

    # Clamp to valid range
    predicted = round(min(max(weighted_avg, 0), 100), 1)

    # Trend analysis on raw scores (not weighted)
    raw_scores = [r["scorePercent"] for r in base_results]
    trend = _trend(raw_scores)

    # Adjust prediction slightly based on trend
    if trend == "improving" and n >= 3:
        predicted = min(predicted + 3, 100)
    elif trend == "declining" and n >= 3:
        predicted = max(predicted - 3, 0)

    # Confidence level
    if n >= 5:
        confidence = "high"
    elif n >= 3:
        confidence = "medium"
    else:
        confidence = "low"

    return {
        "predictedScore": predicted,
        "grade": _grade(predicted),
        "confidence": confidence,
        "trend": trend,
        "message": _prediction_message(predicted, trend),
        "basedOn": n,
        "subjectAverage": round(float(np.mean(raw_scores)), 1),
    }


# ══════════════════════════════════════════
# 2. WEAK TOPIC DETECTION
# ══════════════════════════════════════════

def detect_weak_topics(results: List[Dict]) -> List[Dict[str, Any]]:
    """
    Groups results by subject+chapter and calculates
    average score. Returns topics below the weak threshold,
    sorted by severity (worst first).
    """

    # Group scores by subject → chapter
    topic_scores: Dict[str, Dict[str, List[float]]] = defaultdict(lambda: defaultdict(list))

    for r in results:
        subject = r.get("subject", "Unknown")
        chapter = r.get("chapter", "General")
        score = r.get("scorePercent", 0)
        topic_scores[subject][chapter].append(score)

    weak_topics = []

    for subject, chapters in topic_scores.items():
        for chapter, scores in chapters.items():
            avg = float(np.mean(scores))
            attempts = len(scores)
            trend = _trend(scores)

            if avg < WEAK_THRESHOLD:
                severity = "critical" if avg < 30 else "weak"
            elif avg < AVERAGE_THRESHOLD:
                severity = "needs_improvement"
            else:
                continue  # strong topic — skip

            weak_topics.append({
                "subject": subject,
                "chapter": chapter,
                "averageScore": round(avg, 1),
                "attempts": attempts,
                "severity": severity,
                "trend": trend,
                "grade": _grade(avg),
                "suggestion": _topic_suggestion(subject, chapter, avg, trend),
            })

    # Sort: critical first, then by lowest score
    weak_topics.sort(key=lambda t: (
        0 if t["severity"] == "critical" else
        1 if t["severity"] == "weak" else 2,
        t["averageScore"]
    ))

    return weak_topics


def _topic_suggestion(subject: str, chapter: str, avg: float, trend: str) -> str:
    if avg < 30:
        return f"Critical: Re-study {chapter} from scratch. Consider watching video lectures."
    elif avg < 50:
        return f"Weak: Practice more {chapter} MCQs and review your notes."
    elif trend == "declining":
        return f"Your {chapter} scores are dropping — revisit recent material."
    else:
        return f"Needs improvement in {chapter}. Focus study sessions here."


# ══════════════════════════════════════════
# 3. PERFORMANCE ANALYSIS
# ══════════════════════════════════════════

def analyze_performance(results: List[Dict]) -> Dict[str, Any]:
    """
    Full performance breakdown — overall stats, per-subject
    breakdown, time analysis, improvement trends.
    """

    if not results:
        return {}

    all_scores = [r["scorePercent"] for r in results]
    all_times = [r.get("timeTakenSeconds", 0) for r in results]

    # ── Overall stats ──
    overall = {
        "totalTests": len(results),
        "averageScore": round(float(np.mean(all_scores)), 1),
        "highestScore": round(float(np.max(all_scores)), 1),
        "lowestScore": round(float(np.min(all_scores)), 1),
        "overallTrend": _trend(all_scores),
        "overallGrade": _grade(float(np.mean(all_scores))),
        "averageTimeSecs": round(float(np.mean(all_times)), 0) if any(all_times) else 0,
        "passRate": round(
            len([s for s in all_scores if s >= 50]) / len(all_scores) * 100, 1
        ),
    }

    # ── Per-subject breakdown ──
    subject_data: Dict[str, List[float]] = defaultdict(list)
    for r in results:
        subject_data[r.get("subject", "Unknown")].append(r["scorePercent"])

    subjects = []
    for subject, scores in subject_data.items():
        avg = float(np.mean(scores))
        subjects.append({
            "subject": subject,
            "averageScore": round(avg, 1),
            "totalTests": len(scores),
            "highestScore": round(float(np.max(scores)), 1),
            "lowestScore": round(float(np.min(scores)), 1),
            "trend": _trend(scores),
            "grade": _grade(avg),
            "status": (
                "strong" if avg >= STRONG_THRESHOLD else
                "average" if avg >= AVERAGE_THRESHOLD else
                "weak"
            ),
        })

    subjects.sort(key=lambda s: s["averageScore"], reverse=True)

    # ── Best and worst ──
    best_subject = subjects[0] if subjects else None
    worst_subject = subjects[-1] if subjects else None

    # ── Score over time (last 10 tests) ──
    recent = results[-10:]
    score_history = [
        {
            "index": i + 1,
            "subject": r.get("subject", ""),
            "chapter": r.get("chapter", ""),
            "score": r["scorePercent"],
        }
        for i, r in enumerate(recent)
    ]

    # ── Difficulty breakdown ──
    diff_data: Dict[str, List[float]] = defaultdict(list)
    for r in results:
        diff_data[r.get("difficulty", "medium")].append(r["scorePercent"])

    difficulty_breakdown = {
        diff: round(float(np.mean(scores)), 1)
        for diff, scores in diff_data.items()
    }

    return {
        "overall": overall,
        "subjects": subjects,
        "bestSubject": best_subject,
        "worstSubject": worst_subject,
        "scoreHistory": score_history,
        "difficultyBreakdown": difficulty_breakdown,
    }


# ══════════════════════════════════════════
# 4. STUDY RECOMMENDATIONS
# ══════════════════════════════════════════

def get_study_recommendations(results: List[Dict]) -> List[Dict[str, Any]]:
    """
    Combines weak topic detection + performance analysis
    to produce a prioritized study plan.
    """

    weak = detect_weak_topics(results)
    analysis = analyze_performance(results)

    recommendations = []
    priority = 1

    # Priority 1 — critical weak topics
    for topic in weak:
        if topic["severity"] == "critical":
            recommendations.append({
                "priority": priority,
                "type": "urgent_revision",
                "subject": topic["subject"],
                "chapter": topic["chapter"],
                "reason": f"Critical weakness — average score {topic['averageScore']}%",
                "action": f"Re-study {topic['chapter']} completely. Generate new notes and practice MCQs.",
                "estimatedStudyHours": 4,
            })
            priority += 1

    # Priority 2 — weak topics (not critical)
    for topic in weak:
        if topic["severity"] == "weak":
            recommendations.append({
                "priority": priority,
                "type": "focused_practice",
                "subject": topic["subject"],
                "chapter": topic["chapter"],
                "reason": f"Weak area — average score {topic['averageScore']}%",
                "action": f"Practice {topic['chapter']} MCQs on medium difficulty. Review your notes.",
                "estimatedStudyHours": 2,
            })
            priority += 1

    # Priority 3 — declining subjects
    for subject_data in analysis.get("subjects", []):
        if subject_data["trend"] == "declining" and subject_data["status"] != "weak":
            recommendations.append({
                "priority": priority,
                "type": "prevent_decline",
                "subject": subject_data["subject"],
                "chapter": "General",
                "reason": f"{subject_data['subject']} scores are declining recently",
                "action": f"Revisit recent {subject_data['subject']} material and take a practice test.",
                "estimatedStudyHours": 1,
            })
            priority += 1

    # Priority 4 — needs improvement topics
    for topic in weak:
        if topic["severity"] == "needs_improvement":
            recommendations.append({
                "priority": priority,
                "type": "improvement",
                "subject": topic["subject"],
                "chapter": topic["chapter"],
                "reason": f"Needs improvement — average score {topic['averageScore']}%",
                "action": f"Take one more test on {topic['chapter']} to push above 65%.",
                "estimatedStudyHours": 1,
            })
            priority += 1

    # If everything is strong — general recommendation
    if not recommendations:
        recommendations.append({
            "priority": 1,
            "type": "maintenance",
            "subject": "All subjects",
            "chapter": "General",
            "reason": "Great performance across all topics!",
            "action": "Try harder difficulty MCQs to challenge yourself further.",
            "estimatedStudyHours": 1,
        })

    return recommendations