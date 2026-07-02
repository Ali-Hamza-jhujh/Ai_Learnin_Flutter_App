const MIN_CHAPTER_WORDS = 200;

function wordCount(text) {
  return text.trim().split(/\s+/).filter(Boolean).length;
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
      /^chapter\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)/i.test(
        trimmed
      ) ||
      /^ch\.?\s*\d+/i.test(trimmed) ||
      /^\d+\.\s+[A-Z]/.test(trimmed) ||
      /^[IVXLC]+\.\s+[A-Z]/.test(trimmed) ||
      (/^[A-Z][A-Z0-9\s\-:]{3,58}$/.test(trimmed) && trimmed.length < 60);

    if (isChapter && trimmed.length > 3 && trimmed.length < 100) {
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
