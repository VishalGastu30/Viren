import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../navigation/deep_link_service.dart';
import '../database/enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService — Local device notifications for Viren insights.
//
// No FCM. No server. Completely private.
// All notifications are local, generated on-device.
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static ProviderContainer? _container;

  // Viren's signature vibration patterns.
  // Designed to be recognisable and distinct from default Android vibrations.
  // Pattern: [delay, vibrate, pause, vibrate, ...]  in milliseconds.

  // Critical: Three sharp pulses — urgent, impossible to miss
  static const _vibrationCritical = [0, 80, 60, 80, 60, 300];

  // Warning: Two medium pulses — "pay attention"
  static const _vibrationWarning = [0, 120, 80, 120];

  // Info/Success: One gentle long pulse — "here's something"
  static const _vibrationInfo = [0, 200];

  /// Called once from main() with the global ProviderContainer.
  /// Required for notification tap → deep link navigation.
  static void setContainer(ProviderContainer container) {
    _container = container;
  }

  static const _channelId = 'viren_insights';
  static const _channelName = 'Viren Insights';
  static const _channelDesc =
      'Price alerts, news, and portfolio intelligence from Viren';

  /// Call once at app startup in main().
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create the notification channel (Android 8+)
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Sends a notification for a new alert.
  /// Maps AlertSeverity to Android notification importance.
  static Future<void> showAlertNotification({
    required int id,
    required String title,
    required String body,
    required AlertSeverity severity,
    String? payload, // deep link route
    String? alertId,
    AppDatabase? db,
  }) async {
    if (!_initialized) await initialize();

    // Respect quiet hours — suppress ALL alerts except CRITICAL during quiet period
    if (await isQuietHours() && severity != AlertSeverity.critical) {
      return;
    }

    final importance = _severityToImportance(severity);
    final priority = _severityToPriority(severity);

    // Select vibration pattern based on severity
    final vibrationPattern = switch (severity) {
      AlertSeverity.critical => _vibrationCritical,
      AlertSeverity.warning  => _vibrationWarning,
      _                      => _vibrationInfo,
    };

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: importance,
      priority: priority,
      ticker: 'Viren',
      styleInformation: BigTextStyleInformation(body),
      // Each alert gets its own notification — no grouping
      vibrationPattern: Int64List.fromList(vibrationPattern),
      enableVibration: true,
      playSound: true,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: payload,
    );

    // Mark as notified in DB so flush doesn't re-send it
    if (alertId != null && db != null) {
      try {
        final alert = await (db.select(db.alerts)
              ..where((a) => a.id.equals(alertId)))
            .getSingleOrNull();
        if (alert != null) {
          final data = {
            ...jsonDecode(alert.triggerData) as Map<String, dynamic>,
            'notified': true,
          };
          await (db.update(db.alerts)
                ..where((a) => a.id.equals(alertId)))
              .write(AlertsCompanion(
            triggerData: Value(jsonEncode(data)),
          ));
        }
      } catch (_) {}
    }
  }

  /// Sends a grouped summary notification when multiple alerts fire.
  static Future<void> showGroupSummary(int count, {String? body}) async {
    if (!_initialized) await initialize();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      setAsGroupSummary: true,
      groupKey: 'viren_insights_group',
    );
    await _plugin.show(
      id: 0, // summary always uses id 0
      title: 'Viren — $count new insights',
      body: body ?? 'Tap to view your portfolio updates',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: '/insights',
    );
  }

  /// Deep link handler — navigates to the payload route on notification tap.
  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // 400ms delay: lets the widget tree finish mounting if app was
    // cold-started by the notification tap
    Future.delayed(const Duration(milliseconds: 400), () {
      final container = _container;
      if (container == null) return;

      final DeepLinkTarget target;

      if (payload.startsWith('/holdings/')) {
        // Go to Holdings tab (Phase 4 can add individual holding detail)
        target = const DeepLinkTarget(tab: kTabHoldings);
      } else if (payload == '/insights') {
        target = const DeepLinkTarget(tab: kTabInsights);
      } else if (payload.startsWith('/assistant/')) {
        final message = Uri.decodeComponent(
            payload.replaceFirst('/assistant/', ''));
        target = DeepLinkTarget(tab: kTabAssistant, payload: message);
      } else {
        target = const DeepLinkTarget(tab: kTabInsights);
      }

      container.read(deepLinkProvider.notifier).navigate(target);
    });
  }

  static Importance _severityToImportance(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:
        return Importance.max;
      case AlertSeverity.warning:
        return Importance.high;
      case AlertSeverity.info:
      case AlertSeverity.success:
        return Importance.defaultImportance;
    }
  }

  static Priority _severityToPriority(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:
        return Priority.max;
      case AlertSeverity.warning:
        return Priority.high;
      case AlertSeverity.info:
      case AlertSeverity.success:
        return Priority.defaultPriority;
    }
  }

  /// Reads quiet hours from SharedPreferences (set in AlertSettingsScreen).
  /// Falls back to 22:00–08:00 if prefs not yet configured.
  static Future<bool> isQuietHours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('alerts_quiet_hours_enabled') ?? true;
      if (!enabled) return false;

      final from = prefs.getInt('alerts_quiet_from') ?? 22;
      final to   = prefs.getInt('alerts_quiet_to')   ?? 8;
      final hour = DateTime.now().hour;

      // Spans midnight (e.g. from=22, to=8): quiet if hour>=22 OR hour<8
      if (from > to) return hour >= from || hour < to;
      // Does not span midnight (e.g. from=1, to=6)
      return hour >= from && hour < to;
    } catch (_) {
      return false; // fail open — never suppress on read error
    }
  }
}
