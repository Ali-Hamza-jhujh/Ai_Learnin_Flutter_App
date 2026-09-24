import 'api_client.dart';

class GroupService {
  static const String _base = '/api/groups';

  static Future<Map<String, dynamic>> getMyGroups() async {
    return ApiClient.get('$_base');
  }

  static Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
    String? subject,
  }) async {
    return ApiClient.post('$_base/create', body: {
      'name': name,
      if (description != null) 'description': description,
      if (subject != null) 'subject': subject,
    });
  }

  static Future<Map<String, dynamic>> joinGroup(String inviteCode) async {
    return ApiClient.post('$_base/join', body: {'inviteCode': inviteCode});
  }

  static Future<Map<String, dynamic>> getGroupDetails(String groupId) async {
    return ApiClient.get('$_base/$groupId');
  }

  static Future<Map<String, dynamic>> postMessage(String groupId, String text) async {
    return ApiClient.post('$_base/$groupId/message', body: {'text': text});
  }

  static Future<Map<String, dynamic>> shareNote(String groupId, String noteId) async {
    return ApiClient.post('$_base/$groupId/share/note', body: {'noteId': noteId});
  }

  static Future<Map<String, dynamic>> shareMcq(String groupId, String mcqId) async {
    return ApiClient.post('$_base/$groupId/share/mcq', body: {'mcqId': mcqId});
  }

  static Future<Map<String, dynamic>> removeNote(String groupId, String noteId) async {
    return ApiClient.delete('$_base/$groupId/remove/note/$noteId');
  }

  static Future<Map<String, dynamic>> removeMcq(String groupId, String mcqId) async {
    return ApiClient.delete('$_base/$groupId/remove/mcq/$mcqId');
  }

  static Future<Map<String, dynamic>> deleteMessage(String groupId, String messageId) async {
    return ApiClient.delete('$_base/$groupId/message/$messageId');
  }

  static Future<Map<String, dynamic>> removeUser(String groupId, String userId) async {
    return ApiClient.delete('$_base/$groupId/user/$userId');
  }

  static Future<Map<String, dynamic>> deleteGroup(String groupId) async {
    return ApiClient.delete('$_base/$groupId');
  }
}
