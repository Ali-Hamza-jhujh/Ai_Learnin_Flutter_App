const MIN_CHAPTER_WORDS = 200;

function wordCount(text) {
  const whitespaceSeparatedWords = text.trim().split(/\s+/).filter(Boolean).length;
  // Chinese does not normally use spaces. Counting CJK ideographs keeps the
  // chapter-size threshold meaningful for Simplified Chinese OCR output while
  // retaining ordinary word counts for the other supported languages.
  const cjkCharacters = (text.match(/[\u3400-\u9FFF]/g) || []).length;
  return Math.max(whitespaceSeparatedWords, cjkCharacters);
}

export function detectChapters(text) {
  if (!text || !text.trim()) {
    return [
      {
        title: "Full Document",
        startIndex: 0,
        endIndex: 0,
        wordCount: 0,
      },
    ];
  }

  const lines = text.split("\n");
  const headings = [];
  let currentIndex = 0;

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;

    const isChapter =
      // English
      /^chapter\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)/i.test(
        trimmed
      ) ||
      /^ch\.?\s*\d+/i.test(trimmed) ||
      // German
      /^(kapitel|abschnitt)\s*(\d+|[ivxlc]+)/i.test(trimmed) ||
      // Russian
      /^(глава|раздел)\s*[\dIVXLC]+/iu.test(trimmed) ||
      // Arabic (including Arabic-Indic digits)
      /^(الفصل|الباب)\s*[0-9٠-٩]+/u.test(trimmed) ||
      // Simplified Chinese: 第1章 / 第一章 / 第1节
      /^第\s*[0-9一二三四五六七八九十百千]+\s*[章节篇]/u.test(trimmed) ||
      // Numbered headings in all supported scripts.
      /^\d+\.\s+\S/u.test(trimmed) ||
      /^[IVXLC]+\.\s+\S/i.test(trimmed) ||
      (/^[A-Z][A-Z0-9\s\-:]{3,58}$/.test(trimmed) && trimmed.length < 60);

    // A standard Chinese heading such as "第一章" has exactly three
    // characters, while English headings are naturally longer.
    if (isChapter && trimmed.length >= 3 && trimmed.length < 100) {
      const position = text.indexOf(trimmed, currentIndex);
      if (position !== -1) {
        headings.push({ title: trimmed, startIndex: position });
        currentIndex = position + trimmed.length;
      }
    }
  }

  if (headings.length === 0) {
    return [
      {
        title: "Full Document",
        startIndex: 0,
        endIndex: text.length,
        wordCount: wordCount(text),
      },
    ];
  }

  const chapters = [];
  for (let i = 0; i < headings.length; i++) {
    const startIndex = headings[i].startIndex;
    const endIndex =
      i + 1 < headings.length
        ? headings[i + 1].startIndex
        : text.length;
    const slice = text.slice(startIndex, endIndex);
    const words = wordCount(slice);

    if (words >= MIN_CHAPTER_WORDS || chapters.length === 0) {
      chapters.push({
        title: headings[i].title,
        startIndex,
        endIndex,
        wordCount: words,
      });
    }
  }

  if (chapters.length === 0) {
    return [
      {
        title: "Full Document",
        startIndex: 0,
        endIndex: text.length,
        wordCount: wordCount(text),
      },
    ];
  }

  return chapters;
}

export function extractChapterText(fullText, chapter) {
  return fullText.slice(chapter.startIndex, chapter.endIndex).trim();
}

export function extractSelectedText(fullText, chapters, selectedTitles) {
  if (!selectedTitles || selectedTitles.length === 0) {
    return fullText;
  }

  const selected = chapters.filter((c) => selectedTitles.includes(c.title));
  if (selected.length === 0) return fullText;

  return selected
    .map((c) => extractChapterText(fullText, c))
    .filter(Boolean)
    .join("\n\n");
}
