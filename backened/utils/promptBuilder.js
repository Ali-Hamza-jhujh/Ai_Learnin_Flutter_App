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
  const noteInstruction = (() => {
    switch (summaryType) {
      case "quick":
        return "Notes MUST consist of exactly 5 concise, high-impact, exam-focused bullet points (using • or - for each point). Keep it very brief.";
      case "deep":
        return "Notes MUST be highly detailed, explaining key concepts thoroughly, defining terminology, and including illustrative examples.";
      default:
        return "Notes MUST be well-structured, clear, concise, and exam-focused study guides.";
    }
  })();

  return `
You are an expert educational examiner and academic writer.
Your task is to analyze the provided study material and generate
high-quality exam preparation content.

PARAMETERS:
- MCQ count: ${numMcqs}
- Difficulty: ${difficulty} (easy=recall, medium=understanding, hard=application/analysis)
- Summary type: ${summaryType}
- Chapters: ${chapterTitles.join(", ") || "Full document"}
- Output language: ${language}
- Generate notes: ${generateNotes}
- Generate MCQs: ${generateMcqs}

STRICT RULES:
- MCQ wrong options must be plausible — not obviously wrong
- Questions must test understanding, not just memorization
- Each question must have exactly one unambiguous correct answer
- Notes format rule: ${noteInstruction}
- Do NOT wrap the JSON response in markdown code blocks (do not use \`\`\`json ... \`\`\` formatting). Respond ONLY with the raw, valid JSON object.
- Within the JSON string fields, you may use standard punctuation and formatting (such as bullet points, hyphens, or newlines) to format the notes nicely.

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

