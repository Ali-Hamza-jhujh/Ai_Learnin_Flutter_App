import axios from "axios";
import prisma from "../prisma.js";

// Helper to query RxNorm
async function checkRxNorm(term) {
  try {
    const response = await axios.get(`https://rxnav.nlm.nih.gov/REST/rxcui.json`, {
      params: { name: term },
      timeout: 4000,
    });
    if (response.data?.idGroup?.rxnormId) {
      return true;
    }
    // Approximate term fallback for brand names (Disprin, Panadol, etc.)
    const approxRes = await axios.get(`https://rxnav.nlm.nih.gov/REST/approximateTerm.json`, {
      params: { term, maxEntries: 1 },
      timeout: 4000,
    });
    if (approxRes.data?.approximateGroup?.candidate?.[0]?.rxcui) {
      return true;
    }
  } catch (error) {
    // Ignore and proceed
  }
  return false;
}

// Helper to check Wikipedia categories for keywords
async function checkWikipediaCategory(term) {
  try {
    const response = await axios.get("https://en.wikipedia.org/w/api.php", {
      params: {
        action: "query",
        titles: term,
        prop: "categories",
        cllimit: 30,
        format: "json",
        redirects: 1
      },
      timeout: 4000,
    });

    const pages = response.data?.query?.pages;
    if (pages) {
      const pageId = Object.keys(pages)[0];
      if (pageId !== "-1" && pages[pageId].categories) {
        const categories = pages[pageId].categories.map(c => c.title.toLowerCase());
        
        const checks = [
          { keywords: ["disease", "syndrome", "disorder", "infection", "cancers", "tumors", "pathology"], category: "Diseases" },
          { keywords: ["drug", "medication", "pharmacology", "analgesic", "antibiotic", "hormone", "medicine", "pharmaceutical", "agent", "inhibitor", "agonist", "antagonist", "anti-inflammatory", "anti-infective", "antipyretic"], category: "Drugs" },
          { keywords: ["anatomy", "organs", "muscles", "nerves", "bones", "cardiovascular", "brain", "limbs"], category: "Anatomy" },
          { keywords: ["physiology", "homeostasis", "digestion", "metabolism"], category: "Physiology" },
          { keywords: ["biochemistry", "enzymes", "proteins", "lipids", "amino acids"], category: "Biochemistry" },
          { keywords: ["histology", "tissues", "cells"], category: "Histology" },
          { keywords: ["medical procedure", "surgery", "therapy", "diagnosis", "imaging"], category: "Procedures" },
          { keywords: ["blood test", "biomarker", "urine test", "clinical chemistry"], category: "Lab Values" }
        ];

        for (const check of checks) {
          if (categories.some(cat => check.keywords.some(kw => cat.includes(kw)))) {
            return check.category;
          }
        }
      }
    }
  } catch (e) {
    // ignore
  }
  return null;
}

export async function detectCategory(term) {
  const normalized = term.trim().toLowerCase();

  // 1. Keyword / Suffix Detection Engine (Rule-based) - FAST & SPECIFIC
  const rules = [
    {
      category: "Diseases",
      suffixes: ["itis", "osis", "pathy", "oma", "emia", "iasis", "megaly", "malacia", "plegia", "paresis"],
      keywords: ["disease", "syndrome", "disorder", "fever", "infection", "cancer", "carcinoma", "sarcoma", "lymphoma", "melanoma", "diabetes", "hypertension", "hepatitis", "tuberculosis", "pneumonia", "asthma", "migraine", "depression", "schizophrenia", "arthritis", "dementia", "stroke", "leukemia", "anemia", "malaria", "measles", "mumps", "rubella", "cholera", "typhoid", "dengue", "ebola", "rabies", "tetanus", "diphtheria", "pertussis", "polio", "chickenpox", "smallpox", "plague", "anthrax", "sepsis", "meningitis", "encephalitis", "influenza", "covid", "sars", "mers", "hiv", "aids", "syphilis", "gonorrhea", "chlamydia", "herpes", "epilepsy", "parkinson", "alzheimer", "sclerosis", "lupus", "psoriasis", "eczema", "gout"]
    },
    {
      category: "Drugs",
      suffixes: ["prin", "terol", "pril", "statin", "olol", "epam", "caine", "cillin", "cycline", "romycin", "floxin", "floxacin", "mab", "nib", "asone", "ide", "tine", "xine", "pam", "lam", "dine", "mine", "zine", "phen", "fen", "tin", "zole", "nazole", "prazole", "sartan", "gliflozin", "gliptin", "drine", "stat"],
      keywords: [
        "disprin", "aspirin", "ibuprofen", "paracetamol", "acetaminophen", "metformin", "insulin", "penicillin", "amoxicillin", "atorvastatin", "lisinopril", "albuterol", "diazepam", "morphine", "fentanyl", "warfarin", "heparin",
        "panadol", "crocin", "calpol", "tylenol", "advil", "motrin", "aleve", "nurofen", "brufen", "voltaren", "augmentin", "doliprane", "claritin", "zyrtec", "allegra", "benadryl", "nexium", "prilosec", "zantac", "lipitor", "crestor", "plavix", "humira", "keytruda", "opdivo", "revlimid", "eliquis", "xarelto", "januvia", "victoza", "ozempic", "mounjaro", "wegovy", "saxenda",
        "medication", "medicine", "pill", "tablet", "capsule", "injection", "syrup", "antibiotic", "analgesic", "antipyretic", "antidepressant", "antihistamine"
      ]
    },
    {
      category: "Anatomy",
      suffixes: [],
      keywords: ["nerve", "muscle", "artery", "vein", "ligament", "tendon", "cortex", "lobe", "gland", "bone", "cartilage", "joint", "fascicle", "nucleus", "gyrus", "sulcus", "tract", "ventricle", "atrium", "capillary", "bronchus", "alveolus", "epithelium", "organ", "tunic", "sinus", "plexus", "node", "fascia", "spinal", "cerebral", "cardiac", "renal", "hepatic", "gastric"]
    },
    {
      category: "Procedures",
      suffixes: ["ectomy", "otomy", "plasty", "scopy", "centesis", "stomy", "ography", "graphy", "metry"],
      keywords: ["ecg", "ekg", "electrocardiogram", "mri", "ct scan", "ultrasound", "x-ray", "biopsy", "graft", "resection", "infusion", "transfusion", "intubation", "bypass", "endoscopy", "colonoscopy", "suture", "hemodialysis", "catheterization"]
    },
    {
      category: "Lab Values",
      suffixes: [],
      keywords: ["level", "concentration", "hba1c", "count", "pressure", "hematocrit", "hemoglobin", "cholesterol", "triglycerides", "bilirubin", "creatinine", "urea", "ph", "osmolarity", "titre", "t3", "t4", "tsh", "sodium", "potassium", "calcium", "chloride", "troponin", "amylase", "lipase", "glucose", "ldl", "hdl", "wbc", "rbc", "platelets"]
    },
    {
      category: "Biochemistry",
      suffixes: ["ase", "ose"],
      keywords: ["metabolism", "pathway", "respiration", "glycolysis", "krebs", "phosphorylation", "synthesis", "transduction", "enzyme", "kinase", "hormone", "receptor", "dna", "rna", "atp", "nadp", "protein", "peptide", "lipid", "cholesterol", "steroid", "nucleotide"]
    },
    {
      category: "Physiology",
      suffixes: [],
      keywords: ["cycle", "homeostasis", "digestion", "circulation", "filtration", "secretion", "absorption", "excretion", "reflex", "potential", "depolarization", "repolarization", "systole", "diastole", "peristalsis", "ventilation"]
    }
  ];

  for (const rule of rules) {
    if (rule.suffixes.some(s => normalized.endsWith(s))) {
      return rule.category;
    }
    // Bidirectional match: "migrain" doesn't include "migraine", but "migraine" includes "migrain"
    if (rule.keywords.some(k => normalized.includes(k) || (normalized.length >= 4 && k.includes(normalized)))) {
      return rule.category;
    }
  }

  // 2. Local Database Check
  const localMatch = await prisma.dictionaryItem.findFirst({
    where: {
      title: { equals: normalized, mode: "insensitive" },
    },
  });
  if (localMatch) {
    return localMatch.category;
  }

  // 3. Wikipedia Category Mapping (before RxNorm to avoid false drug matches)
  const wikiCategory = await checkWikipediaCategory(term);
  if (wikiCategory) return wikiCategory;

  // 4. RxNorm Check (Direct + Approximate)
  const isDrug = await checkRxNorm(normalized);
  if (isDrug) return "Drugs";

  // 5. ICD Code Pattern Check (Medline Plus ICD Detection)
  const icdPattern = /^[a-z]\d{2}(\.\d{1,4})?$/i;
  if (icdPattern.test(normalized)) {
    return "Diseases";
  }

  // 6. Fallback
  return "Clinical Concepts";
}
