enum AIErrorType {
  freeTrialExhausted,
  allProvidersExhausted,
  offlineUnavailable,
  noConnectivity,
  invalidResponse,
}

class AIException implements Exception {
  final AIErrorType type;
  final String message;
  final List<dynamic>? skipped;

  AIException({
    required this.type,
    this.message = '',
    this.skipped,
  });

  @override
  String toString() => message.isNotEmpty ? message : type.name;
}

class AppException implements Exception {
  final String message;
  final int? statusCode;

  AppException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
