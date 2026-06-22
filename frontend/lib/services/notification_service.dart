import 'package:flutter/foundation.dart';
import '../demo/demo_mode.dart';
import '../models/notification_item.dart';
import 'api_client.dart';

class NotificationService extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  List<NotificationItem> get notifications => _notifications;

  bool _loading = false;
  bool get loading => _loading;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetch(String userId, {bool seeAll = false}) async {
    if (DemoMode.active) {
      _notifications = [];
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      final response = await ApiClient.instance.get('/notifications', query: {'pageSize': '100'});
      final list = response['data'] as List;
      _notifications = list.map((e) => NotificationItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // keep existing list on error
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1 || _notifications[idx].isRead) return;
    if (!DemoMode.active) {
      await ApiClient.instance.patch('/notifications/$id/read');
    }
    _notifications[idx] = _copyWithRead(_notifications[idx], true);
    notifyListeners();
  }

  Future<void> markAllAsRead(String userId) async {
    if (!DemoMode.active) {
      await ApiClient.instance.patch('/notifications/read-all');
    }
    _notifications = _notifications.map((n) => _copyWithRead(n, true)).toList();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  // No-op: backend now handles budget threshold notifications server-side.
  Future<void> notifyOnce({
    required String userId,
    required String title,
    required String message,
    required String type,
    required String category,
    required String priority,
    required String dedupeKey,
  }) async {}

  NotificationItem _copyWithRead(NotificationItem n, bool read) =>
      NotificationItem(
        id: n.id,
        userId: n.userId,
        title: n.title,
        message: n.message,
        type: n.type,
        category: n.category,
        priority: n.priority,
        relatedId: n.relatedId,
        isRead: read,
        createdAt: n.createdAt,
      );
}
