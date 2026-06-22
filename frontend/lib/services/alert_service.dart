import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../demo/demo_mode.dart';
import '../demo/demo_data.dart';
import '../models/alert.dart';
import 'supabase_service.dart';

class AlertService extends ChangeNotifier {
  List<Alert> _alerts = [];
  List<Alert> get alerts => _alerts;

  SupabaseClient get _client => SupabaseService.instance.client;

  Future<List<Alert>> fetchAlerts() async {
    if (DemoMode.active) {
      _alerts = List.from(DemoData.alerts);
      notifyListeners();
      return _alerts;
    }
    final data = await _client
        .from('alerts')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    _alerts = (data as List).map((e) => Alert.fromJson(e)).toList();
    notifyListeners();
    return _alerts;
  }

  Future<List<Alert>> fetchOpenAlerts() async {
    if (DemoMode.active) {
      return _alerts.where((a) => a.status == 'open' || a.status == 'acknowledged').toList();
    }
    final data = await _client
        .from('alerts')
        .select()
        .inFilter('status', ['open', 'acknowledged'])
        .order('created_at', ascending: false);
    return (data as List).map((e) => Alert.fromJson(e)).toList();
  }

  Future<void> insertAlert(Map<String, dynamic> data) async {
    if (DemoMode.active) {
      notifyListeners();
      return;
    }
    await _client.from('alerts').insert(data);
    notifyListeners();
  }

  Future<void> acknowledgeAlert(String alertId) async {
    if (DemoMode.active) {
      _updateAlertStatus(alertId, 'acknowledged');
      return;
    }
    await _client
        .from('alerts')
        .update({'status': 'acknowledged'})
        .eq('id', alertId);
    await fetchAlerts();
  }

  Future<void> resolveAlert(String alertId) async {
    if (DemoMode.active) {
      _updateAlertStatus(alertId, 'resolved', resolvedAt: DateTime.now());
      return;
    }
    await _client.from('alerts').update({
      'status': 'resolved',
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', alertId);
    await fetchAlerts();
  }

  void _updateAlertStatus(String alertId, String newStatus, {DateTime? resolvedAt}) {
    final idx = DemoData.alerts.indexWhere((a) => a.id == alertId);
    if (idx == -1) return;
    final old = DemoData.alerts[idx];
    DemoData.alerts[idx] = Alert(
      id: old.id,
      vehicleId: old.vehicleId,
      driverId: old.driverId,
      tripId: old.tripId,
      transactionId: old.transactionId,
      alertType: old.alertType,
      severity: old.severity,
      status: newStatus,
      title: old.title,
      description: old.description,
      aiConfidence: old.aiConfidence,
      resolvedBy: resolvedAt != null ? 'demo-admin' : old.resolvedBy,
      resolvedAt: resolvedAt ?? old.resolvedAt,
      createdAt: old.createdAt,
    );
    _alerts = List.from(DemoData.alerts);
    notifyListeners();
  }

  RealtimeChannel subscribeToAlerts(Function(List<Alert>) onUpdate) {
    if (DemoMode.active) {
      // Return a no-op channel — demo data doesn't need realtime.
      return _client.channel('demo-noop');
    }
    final channel = _client
        .channel('alerts-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (_) async {
            final updated = await fetchAlerts();
            onUpdate(updated);
          },
        )
        .subscribe();
    return channel;
  }

  int get openAlertCount =>
      _alerts.where((a) => a.status == 'open').length;
}
