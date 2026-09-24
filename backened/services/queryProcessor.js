// Query Processor Service
// Extracts medical terms, removes stop words, detects intent

const STOP_WORDS = new Set([
  'what', 'is', 'are', 'the', 'a', 'an', 'and', 'or', 'but', 'of', 'in', 'on', 'at', 'to', 'for',
  'by', 'from', 'with', 'as', 'can', 'could', 'should', 'would', 'may', 'might', 'must', 'shall',
  'will', 'do', 'does', 'did', 'have', 'has', 'had', 'be', 'been', 'being', 'am', 'i', 'me',
  'you', 'he', 'she', 'it', 'we', 'they', 'my', 'your', 'his', 'her', 'our', 'their', 'this',
  'that', 'these', 'those', 'which', 'who', 'whom', 'why', 'where', 'when', 'how', 'about',
  'all', 'each', 'every', 'both', 'few', 'more', 'most', 'other', 'some', 'such', 'no', 'nor',
  'not', 'only', 'own', 'same', 'so', 'than', 'too', 'very', 'tell', 'show', 'give', 'provide',
  'explain', 'define', 'describe', 'list', 'discuss', 'name', 'mention'
]);

const INTENT_KEYWORDS = {
  symptoms: ['symptoms', 'sign', 'signs', 'manifestation', 'clinical', 'present', 'presentation'],
  treatment: ['treatment', 'treat', 'therapy', 'cure', 'medicine', 'medication', 'heal', 'manage', 'management'],
  causes: ['cause', 'causes', 'caused', 'reason', 'etiology', 'risk', 'factor'],
  definition: ['definition', 'define', 'what', 'meaning', 'definition', 'is', 'are'],
  diagnosis: ['diagnosis', 'diagnose', 'diagnostic', 'test', 'examine', 'identify'],
  prevention: ['prevent', 'prevention', 'avoid', 'reduce', 'risk'],
  complications: ['complication', 'complications', 'consequence', 'effect', 'side'],
  sideEffects: ['side effect', 'sideeffect', 'adverse', 'reaction', 'toxicity'],
  drugInfo: ['drug', 'medication', 'medicine', 'pill', 'tablet', 'inject', 'prescription'],
  dosage: ['dose', 'dosage', 'how much', 'strength', 'concentration'],
  contraindications: ['contraindication', 'contraindicated', 'should not', 'should not take'],
  interactions: ['interaction', 'interaction', 'combined', 'together', 'mix'],
};

const CATEGORY_KEYWORDS = {
  Diseases: ['disease', 'disorder', 'illness', 'condition', 'syndrome', 'infection', 'virus', 'bacterial'],
  Drugs: ['drug', 'medication', 'medicine', 'pill', 'tablet', 'injection', 'antibiotic', 'vaccine'],
  Anatomy: ['bone', 'muscle', 'nerve', 'organ', 'tissue', 'system', 'vessel', 'artery', 'vein'],
  Physiology: ['function', 'process', 'system', 'regulate', 'control', 'response'],
  Pharmacology: ['drug', 'medication', 'pharmaceutical', 'mechanism', 'action', 'receptor'],
  'Lab Values': ['test', 'value', 'level', 'count', 'result', 'hemoglobin', 'glucose', 'cholesterol'],
  'Clinical Concepts': ['diagnosis', 'syndrome', 'clinical', 'presentation', 'manifestation'],
};

export const processQuery = (userQuery) => {
  const query = userQuery.toLowerCase().trim();
  
  // Remove stop words
  const words = query
    .split(/\s+/)
    .filter(word => !STOP_WORDS.has(word.replace(/[^\w]/g, '')))
    .filter(word => word.length > 2);

  // Extract main medical term (usually the longest meaningful phrase)
  const mainTerm = words.join(' ') || userQuery;

  // Detect user intent
  const intent = detectIntent(query);

  // Detect category
  const category = detectCategoryFromQuery(query);

  return {
    originalQuery: userQuery,
    processedQuery: mainTerm,
    keywords: words,
    intent,
    category,
    searchTerms: [...words, mainTerm], // Multiple search attempts
  };
};

const detectIntent = (query) => {
  const intents = [];

  for (const [intentType, keywords] of Object.entries(INTENT_KEYWORDS)) {
    if (keywords.some(keyword => query.includes(keyword))) {
      intents.push(intentType);
    }
  }

  // If no specific intent detected, assume definition
  if (intents.length === 0) {
    intents.push('definition');
  }

  return intents;
};

const detectCategoryFromQuery = (query) => {
  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    if (keywords.some(keyword => query.includes(keyword))) {
      return category;
    }
  }
  return null; // Category detector will handle this
};

export const extractMedicalTerms = (query) => {
  // Simple extraction - can be enhanced with medical NLP later
  const processed = processQuery(query);
  return {
    term: processed.processedQuery,
    keywords: processed.keywords,
    intent: processed.intent,
    suggestedCategory: processed.category,
  };
};

export default processQuery;
