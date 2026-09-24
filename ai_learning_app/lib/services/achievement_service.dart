import 'api_client.dart';

class AchievementService {
  static const String _base = '/api/achievements';

  static Future<Map<String, dynamic>> getMyAchievements() async => ApiClient.get('$_base');
  
  static Future<Map<String, dynamic>> unlockAchievement(String achievementId) async {
    return ApiClient.post('$_base/unlock', body: {'achievementId': achievementId});
  }
}
