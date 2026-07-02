export function buildPrompt({
  text,
  numMcqs = 10,
  difficulty = "medium",
  chapterTitles = [],
  summaryType = "normal",
  language = "en",
  generateNotes = true,
  generateMcqs = true,
}) {
  return `
You are an expert educational examiner and academic writer.
Your task is to analyze the provided study material and generate
high-quality exam preparation content.

PARAMETERS:
- MCQ count: ${numMcqs}
- Difficulty: ${difficulty} (easy=recall, medium=understanding, hard=application/analysis)
- Summary type: ${summaryType} (quick=5 bullets, normal=full notes, deep=detailed with examples)
- Chapters: ${chapterTitles.join(", ") || "Full document"}
- Output language: ${language}
- Generate notes: ${generateNotes}
- Generate MCQs: ${generateMcqs}

STRICT RULES:
- MCQ wrong options must be plausible — not obviously wrong
- Questions must test understanding, not just memorization
- Each question must have exactly one unambiguous correct answer
- Notes must be exam-focused and concise
- Deep summaries must include examples
- Do NOT include markdown formatting in the output
- Respond ONLY with the JSON object below — no preamble, no explanation

REQUIRED JSON FORMAT (respond with this exact structure):
{
  "mcqs": [
    {
      "question": "...",
      "options": ["A. ...", "B. ...", "C. ...", "D. ..."],
      "answer": "A",
      "explanation": "Why this answer is correct and others are wrong",
      "topic": "Chapter or topic this question covers"
    }
  ],
  "notes": [
    {
      "heading": "Topic Title",
      "content": "Detailed exam-focused explanation"
    }
  ],
  "detectedLanguage": "en",
  "difficulty": "${difficulty}"
}

STUDY MATERIAL:
${text}
`.trim();
}
