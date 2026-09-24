class DictionaryItem {
  final String id;
  final String title;
  final String slug;
  final String description;
  final String category;
  final String? subcategory;
  final DictionaryOverview overview;
  final DictionaryClinicalInfo clinicalInfo;
  final List<DictionaryImage> images;
  final List<DictionaryReference> references;
  final List<DictionaryResearchPaper> researchPapers;
  final List<String> keywords;
  final List<String> relatedTopics;
  final int searchCount;
  final int viewCount;

  DictionaryItem({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.category,
    this.subcategory,
    required this.overview,
    required this.clinicalInfo,
    required this.images,
    required this.references,
    required this.researchPapers,
    required this.keywords,
    required this.relatedTopics,
    required this.searchCount,
    required this.viewCount,
  });

  factory DictionaryItem.fromJson(Map<String, dynamic> json) {
    return DictionaryItem(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'Clinical Concepts',
      subcategory: json['subcategory'],
      overview: DictionaryOverview.fromJson(Map<String, dynamic>.from(json['overview'] ?? {})),
      clinicalInfo: DictionaryClinicalInfo.fromJson(Map<String, dynamic>.from(json['clinicalInfo'] ?? {})),
      images: (json['images'] as List?)?.map((x) => DictionaryImage.fromJson(Map<String, dynamic>.from(x as Map))).toList() ?? [],
      references: (json['references'] as List?)?.map((x) => DictionaryReference.fromJson(Map<String, dynamic>.from(x as Map))).toList() ?? [],
      researchPapers: (json['researchPapers'] as List?)?.map((x) => DictionaryResearchPaper.fromJson(Map<String, dynamic>.from(x as Map))).toList() ?? [],
      keywords: List<String>.from(json['keywords'] ?? []),
      relatedTopics: List<String>.from(json['relatedTopics'] ?? []),
      searchCount: json['searchCount'] ?? 0,
      viewCount: json['viewCount'] ?? 0,
    );
  }
}

class DictionaryOverview {
  final String definition;
  final String classification;
  final List<String> synonyms;
  final List<String> icdCodes;

  DictionaryOverview({
    required this.definition,
    required this.classification,
    required this.synonyms,
    required this.icdCodes,
  });

  factory DictionaryOverview.fromJson(Map<String, dynamic> json) {
    return DictionaryOverview(
      definition: json['definition'] ?? '',
      classification: json['classification'] ?? '',
      synonyms: List<String>.from(json['synonyms'] ?? []),
      icdCodes: List<String>.from(json['icdCodes'] ?? []),
    );
  }
}

class DictionaryClinicalInfo {
  final List<String> symptoms;
  final List<String> causes;
  final List<String> diagnosis;
  final List<String> treatment;
  final List<String> complications;
  final List<String> prevention;

  // Drug-specific
  final List<String> brandNames;
  final String drugClass;
  final List<String> strength;
  final List<String> doseForms;
  final List<String> uses;
  final List<String> warnings;
  final List<String> contraindications;
  final List<String> sideEffects;
  final List<String> interactions;

  // Anatomy-specific
  final String origin;
  final String insertion;
  final String bloodSupply;
  final String nerveSupply;
  final List<String> functions;
  final String clinicalImportance;

  // Lab-specific
  final String normalRange;
  final String clinicalSignificance;
  final List<String> highValues;
  final List<String> lowValues;

  DictionaryClinicalInfo({
    required this.symptoms,
    required this.causes,
    required this.diagnosis,
    required this.treatment,
    required this.complications,
    required this.prevention,
    required this.brandNames,
    required this.drugClass,
    required this.strength,
    required this.doseForms,
    required this.uses,
    required this.warnings,
    required this.contraindications,
    required this.sideEffects,
    required this.interactions,
    required this.origin,
    required this.insertion,
    required this.bloodSupply,
    required this.nerveSupply,
    required this.functions,
    required this.clinicalImportance,
    required this.normalRange,
    required this.clinicalSignificance,
    required this.highValues,
    required this.lowValues,
  });

  factory DictionaryClinicalInfo.fromJson(Map<String, dynamic> json) {
    return DictionaryClinicalInfo(
      symptoms: List<String>.from(json['symptoms'] ?? []),
      causes: List<String>.from(json['causes'] ?? []),
      diagnosis: List<String>.from(json['diagnosis'] ?? []),
      treatment: List<String>.from(json['treatment'] ?? []),
      complications: List<String>.from(json['complications'] ?? []),
      prevention: List<String>.from(json['prevention'] ?? []),
      brandNames: List<String>.from(json['brandNames'] ?? []),
      drugClass: json['drugClass'] ?? '',
      strength: List<String>.from(json['strength'] ?? []),
      doseForms: List<String>.from(json['doseForms'] ?? []),
      uses: List<String>.from(json['uses'] ?? []),
      warnings: List<String>.from(json['warnings'] ?? []),
      contraindications: List<String>.from(json['contraindications'] ?? []),
      sideEffects: List<String>.from(json['sideEffects'] ?? []),
      interactions: List<String>.from(json['interactions'] ?? []),
      origin: json['origin'] ?? '',
      insertion: json['insertion'] ?? '',
      bloodSupply: json['bloodSupply'] ?? '',
      nerveSupply: json['nerveSupply'] ?? '',
      functions: List<String>.from(json['functions'] ?? []),
      clinicalImportance: json['clinicalImportance'] ?? '',
      normalRange: json['normalRange'] ?? '',
      clinicalSignificance: json['clinicalSignificance'] ?? '',
      highValues: List<String>.from(json['highValues'] ?? []),
      lowValues: List<String>.from(json['lowValues'] ?? []),
    );
  }
}

class DictionaryImage {
  final String url;
  final String thumbnailUrl;
  final String mediumUrl;
  final String caption;
  final String creator;
  final String license;
  final String source;

  DictionaryImage({
    required this.url,
    required this.thumbnailUrl,
    required this.mediumUrl,
    required this.caption,
    required this.creator,
    required this.license,
    required this.source,
  });

  factory DictionaryImage.fromJson(Map<String, dynamic> json) {
    return DictionaryImage(
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? json['thumbnail'] ?? '',
      mediumUrl: json['mediumUrl'] ?? json['medium'] ?? '',
      caption: json['caption'] ?? 'Medical illustration',
      creator: json['creator'] ?? '',
      license: json['license'] ?? '',
      source: json['source'] ?? '',
    );
  }
}

class DictionaryReference {
  final String title;
  final String source;
  final String url;
  final String type;

  DictionaryReference({
    required this.title,
    required this.source,
    required this.url,
    required this.type,
  });

  factory DictionaryReference.fromJson(Map<String, dynamic> json) {
    return DictionaryReference(
      title: json['title'] ?? '',
      source: json['source'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? 'reference',
    );
  }
}

class DictionaryResearchPaper {
  final String pubmedId;
  final String title;
  final String authors;
  final String journal;
  final String volume;
  final String issue;
  final String pages;
  final String pubDate;
  final String abstract;
  final String doi;
  final String url;

  DictionaryResearchPaper({
    required this.pubmedId,
    required this.title,
    required this.authors,
    required this.journal,
    required this.volume,
    required this.issue,
    required this.pages,
    required this.pubDate,
    required this.abstract,
    required this.doi,
    required this.url,
  });

  factory DictionaryResearchPaper.fromJson(Map<String, dynamic> json) {
    return DictionaryResearchPaper(
      pubmedId: json['pubmedId'] ?? '',
      title: json['title'] ?? '',
      authors: json['authors'] ?? '',
      journal: json['journal'] ?? '',
      volume: json['volume'] ?? '',
      issue: json['issue'] ?? '',
      pages: json['pages'] ?? '',
      pubDate: json['pubDate'] ?? '',
      abstract: json['abstract'] ?? '',
      doi: json['doi'] ?? '',
      url: json['url'] ?? '',
    );
  }
}
