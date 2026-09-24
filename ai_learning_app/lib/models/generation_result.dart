import 'mcq_model.dart';
import 'note_model.dart';

class GenerationResult {
  final List<MCQ> mcqs;
  final List<Note> notes;
  final String provider;
  final List<String> attempted;
  final bool isOffline;
  final bool isFreeGeneration;
  final bool fromCache;
  final String? warning;
  final String? savedContentId;

  GenerationResult({
    required this.mcqs,
    required this.notes,
    required this.provider,
    this.attempted = const [],
    this.isOffline = false,
    this.isFreeGeneration = false,
    this.fromCache = false,
    this.warning,
    this.savedContentId,
  });

  factory GenerationResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> body = (json['data'] as Map<String, dynamic>?) ?? 
                                      (json['result'] as Map<String, dynamic>?) ?? 
                                      json;

    final rawMcqs = (body['mcqs'] as List?) ?? (json['mcqs'] as List?) ?? [];
    final rawNotes = (body['notes'] as List?) ?? (json['notes'] as List?) ?? [];
    final rawAttempted = json['attempted'] as List? ?? [];

    return GenerationResult(
      mcqs: rawMcqs.map((e) => MCQ.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      notes: rawNotes.map((e) => Note.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      provider: json['provider']?.toString() ?? 'unknown',
      attempted: rawAttempted.map((e) => e.toString()).toList(),
      isOffline: json['isOffline'] == true,
      isFreeGeneration: json['isFreeGeneration'] == true || json['provider']?.toString().contains('free') == true,
      fromCache: json['fromCache'] == true || json['cached'] == true,
      warning: json['warning']?.toString(),
      savedContentId: (json['data'] as Map?)?['_id']?.toString(),
    );
  }
}
