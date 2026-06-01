import 'dart:io';
import 'api_client.dart';

// ══════════════════════════════════════════
// AUTH SERVICE
// ══════════════════════════════════════════

class AuthService {
  static const String _base = '/api/auth';

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String educationLevel,
    required String subject,
    required String goal,
    String? profilePicture,
  }) async {
    return ApiClient.post('$_base/register', auth: false, body: {
      'name': name,
      'email': email,
      'password': password,
      'educationLevel': educationLevel,
      'subject': subject,
      'goal': goal,
      if (profilePicture != null) 'profilePicture': profilePicture,
    });
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await ApiClient.post('$_base/login', auth: false,
        body: {'email': email, 'password': password});
    if (res['token'] != null) await TokenManager.saveToken(res['token'] as String);
    if (res['user'] != null) await TokenManager.saveUser(res['user'] as Map<String, dynamic>);
    return res;
  }

  // Google login — sends Google ID token to backend
  // Backend verifies it and returns JWT
  static Future<Map<String, dynamic>> googleLogin({
    required String idToken,
    required String name,
    required String email,
    String? profilePicture,
  }) async {
    final res = await ApiClient.post('$_base/google', auth: false, body: {
      'idToken': idToken,
      'name': name,
      'email': email,
      if (profilePicture != null) 'profilePicture': profilePicture,
    });
    if (res['token'] != null) await TokenManager.saveToken(res['token'] as String);
    if (res['user'] != null) await TokenManager.saveUser(res['user'] as Map<String, dynamic>);
    return res;
  }

  static Future<void> logout() async => TokenManager.clear();

  static Future<Map<String, dynamic>> resendVerification(String email) async {
    return ApiClient.post('$_base/resend-verify', auth: false, body: {'email': email});
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    return ApiClient.post('$_base/forgot-password', auth: false, body: {'email': email});
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    return ApiClient.post('$_base/reset-password-api', auth: false,
        body: {'token': token, 'newPassword': newPassword});
  }

  static Future<bool> isLoggedIn() => TokenManager.isLoggedIn();
}

// ══════════════════════════════════════════
// NOTES SERVICE
// ══════════════════════════════════════════

class NotesService {
  static const String _base = '/api/notes';

  static Future<Map<String, dynamic>> scanPDF(File pdfFile) async {
    return ApiClient.uploadFile('$_base/scan', file: pdfFile, fileField: 'file');
  }

  static Future<Map<String, dynamic>> generateNotes({
    required File pdfFile,
    required String title,
    required String mode,
    String? subject,
    String? chapter,
    List<String>? chapters,
  }) async {
    return ApiClient.uploadFile('$_base/generate', file: pdfFile, fileField: 'file', fields: {
      'title': title,
      'mode': mode,
      if (subject != null) 'subject': subject,
      if (chapter != null) 'chapter': chapter,
      if (chapters != null) 'chapters': chapters.toString(),
    });
  }

  static Future<Map<String, dynamic>> getMyNotes() async => ApiClient.get('$_base/my-notes');
  static Future<Map<String, dynamic>> getNoteById(String id) async => ApiClient.get('$_base/my-notes/$id');

  static Future<Map<String, dynamic>> updateNote(String id, {required String title, String? subject}) async {
    return ApiClient.put('$_base/$id', body: {'title': title, if (subject != null) 'subject': subject});
  }

  static Future<Map<String, dynamic>> deleteNote(String id) async => ApiClient.delete('$_base/delete-notes/$id');
}

// ══════════════════════════════════════════
// MCQ SERVICE
// ══════════════════════════════════════════

class MCQService {
  static const String _base = '/api/mcq';

  static Future<Map<String, dynamic>> scanPDF(File pdfFile) async {
    return ApiClient.uploadFile('$_base/scan', file: pdfFile, fileField: 'file');
  }

  static Future<Map<String, dynamic>> generateMCQ({
    required File pdfFile,
    required String title,
    required String mode,
    String? subject,
    String? chapter,
    List<String>? chapters,
    int numQuestions = 10,
    String difficulty = 'medium',
  }) async {
    return ApiClient.uploadFile('$_base/generate', file: pdfFile, fileField: 'file', fields: {
      'title': title,
      'mode': mode,
      'numQuestions': numQuestions.toString(),
      'difficulty': difficulty,
      if (subject != null) 'subject': subject,
      if (chapter != null) 'chapter': chapter,
      if (chapters != null) 'chapters': chapters.toString(),
    });
  }

  static Future<Map<String, dynamic>> getMyMCQs() async => ApiClient.get('$_base/my-mcqs');
  static Future<Map<String, dynamic>> getMCQById(String id) async => ApiClient.get('$_base/my-mcqs/$id');

  static Future<Map<String, dynamic>> submitTest({
    required String mcqId,
    required List<Map<String, dynamic>> answers,
    int? timeTakenSeconds,
  }) async {
    return ApiClient.post('$_base/submit', body: {
      'mcqId': mcqId,
      'answers': answers,
      if (timeTakenSeconds != null) 'timeTakenSeconds': timeTakenSeconds,
    });
  }

  static Future<Map<String, dynamic>> getMyResults() async => ApiClient.get('$_base/my-results');
  static Future<Map<String, dynamic>> getResultById(String id) async => ApiClient.get('$_base/my-results/$id');
  static Future<Map<String, dynamic>> deleteMCQ(String id) async => ApiClient.delete('$_base/delete-mcq/$id');
}

// ══════════════════════════════════════════
// CHAT SERVICE
// ══════════════════════════════════════════

class ChatService {
  static const String _base = '/api/chat';

  static Future<Map<String, dynamic>> newChat({
    required String title,
    String? subject,
    File? pdfFile,
  }) async {
    if (pdfFile != null) {
      return ApiClient.uploadFile('$_base/new', file: pdfFile, fileField: 'file',
          fields: {'title': title, if (subject != null) 'subject': subject});
    }
    return ApiClient.post('$_base/new', body: {'title': title, if (subject != null) 'subject': subject});
  }

  static Stream<String> sendMessageStream(String chatId, String message) {
    return ApiClient.streamPost('$_base/$chatId/message', body: {'message': message});
  }

  static Future<Map<String, dynamic>> sendMessage(String chatId, String message) async {
    return ApiClient.post('$_base/$chatId/message-simple', body: {'message': message});
  }

  static Future<Map<String, dynamic>> getMyChats() async => ApiClient.get('$_base/my-chats');
  static Future<Map<String, dynamic>> getChatById(String chatId) async => ApiClient.get('$_base/$chatId');
  static Future<Map<String, dynamic>> deleteChat(String chatId) async => ApiClient.delete('$_base/$chatId');
  static Future<Map<String, dynamic>> clearChat(String chatId) async => ApiClient.delete('$_base/$chatId/clear');
}

// ══════════════════════════════════════════
// YOUTUBE SERVICE
// ══════════════════════════════════════════

class YouTubeService {
  static const String _base = '/api/youtube';

  static Future<Map<String, dynamic>> searchVideos(String query, {int maxResults = 10, String? educationLevel}) async {
    return ApiClient.get('$_base/search', queryParams: {
      'q': query,
      'maxResults': maxResults.toString(),
      if (educationLevel != null) 'educationLevel': educationLevel,
    });
  }

  static Future<Map<String, dynamic>> getSuggestions() async => ApiClient.get('$_base/suggestions');
  static Future<Map<String, dynamic>> getVideoDetails(String videoId) async => ApiClient.get('$_base/video/$videoId');

  static Future<Map<String, dynamic>> saveVideo({
    required String videoId, required String title,
    String? channelName, String? thumbnail, String? url,
    String? duration, String? views, String? subject,
  }) async {
    return ApiClient.post('$_base/save', body: {
      'videoId': videoId, 'title': title,
      if (channelName != null) 'channelName': channelName,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (url != null) 'url': url,
      if (duration != null) 'duration': duration,
      if (views != null) 'views': views,
      if (subject != null) 'subject': subject,
    });
  }

  static Future<Map<String, dynamic>> getSavedVideos({String? subject}) async {
    return ApiClient.get('$_base/saved', queryParams: subject != null ? {'subject': subject} : null);
  }

  static Future<Map<String, dynamic>> unsaveVideo(String videoId) async => ApiClient.delete('$_base/saved/$videoId');

  static Future<Map<String, dynamic>> addNotesToVideo(String videoId, String notes) async {
    return ApiClient.patch('$_base/saved/$videoId/notes', body: {'notes': notes});
  }

  static Future<bool> isVideoSaved(String videoId) async {
    final res = await ApiClient.get('$_base/saved/check/$videoId');
    return res['isSaved'] as bool? ?? false;
  }
}

// ══════════════════════════════════════════
// ML SERVICE
// ══════════════════════════════════════════

class MLService {
  static const String _base = '/api/ml';

  static Future<Map<String, dynamic>> getDashboard({String? subject}) async {
    return ApiClient.get('$_base/dashboard', queryParams: subject != null ? {'subject': subject} : null);
  }

  static Future<Map<String, dynamic>> predictScore({required String targetSubject, String? targetChapter}) async {
    return ApiClient.post('$_base/predict', body: {
      'targetSubject': targetSubject,
      if (targetChapter != null) 'targetChapter': targetChapter,
    });
  }

  static Future<Map<String, dynamic>> getWeakTopics() async => ApiClient.get('$_base/weak-topics');
  static Future<Map<String, dynamic>> getPerformance() async => ApiClient.get('$_base/performance');
  static Future<Map<String, dynamic>> getRecommendations() async => ApiClient.get('$_base/recommendations');

  static Future<bool> isMLOnline() async {
    try {
      final res = await ApiClient.get('$_base/health');
      return res['mlService'] != null;
    } catch (_) {
      return false;
    }
  }
}

// ══════════════════════════════════════════
// PROFILE SERVICE
// ══════════════════════════════════════════

class ProfileService {
  static const String _base = '/api/profile';

  static Future<Map<String, dynamic>> getMyProfile() async => ApiClient.get('$_base/me');

  static Future<Map<String, dynamic>> updateProfile({
    String? name, String? educationLevel, String? subject,
    String? goal, String? profilePicture,
  }) async {
    return ApiClient.put('$_base/update', body: {
      if (name != null) 'name': name,
      if (educationLevel != null) 'educationLevel': educationLevel,
      if (subject != null) 'subject': subject,
      if (goal != null) 'goal': goal,
      if (profilePicture != null) 'profilePicture': profilePicture,
    });
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword, required String newPassword,
  }) async {
    return ApiClient.put('$_base/change-password',
        body: {'currentPassword': currentPassword, 'newPassword': newPassword});
  }

  static Future<Map<String, dynamic>> getXP() async => ApiClient.get('$_base/xp');
  static Future<Map<String, dynamic>> awardXP(String action) async => ApiClient.post('$_base/award-xp', body: {'action': action});

  static Future<Map<String, dynamic>> getLeaderboard({String? subject}) async {
    return ApiClient.get('$_base/leaderboard', queryParams: subject != null ? {'subject': subject} : null);
  }

  static Future<Map<String, dynamic>> getStats() async => ApiClient.get('$_base/stats');
}