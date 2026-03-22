import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/security/key_manager.dart';
import 'core/database/app_database.dart';
import 'core/database/providers/database_providers.dart';
import 'core/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/market/market_knowledge_service.dart';

import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/insights/insight_worker.dart' as insights;
import 'core/insights/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables for Supabase
  await dotenv.load(fileName: ".env");

  // Initialize Supabase (Encrypted Backup Sync)
  await Supabase.initialize(
    url: dotenv.env['Project URL']?.replaceAll('"', '') ?? '',
    anonKey: dotenv.env['anon_public']?.replaceAll('"', '') ?? '',
  );

  // Initialize the security layer FIRST — no DB operation may happen before this.
  final keyManager = await KeyManager.initialize();

  // Open the persistent SQLite database.
  final database = AppDatabase();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize Background Sync (Workmanager + Notifications)
  // BackgroundSyncService superseded by AutoEmailSyncService

  // Initialize Market Knowledge for Assistant
  await MarketKnowledgeService.init();

  // --- Phase 1: Insights & Alerts Initialization ---
  
  // Initialize WorkManager for insights
  await Workmanager().initialize(
    insights.callbackDispatcher,
  );

  // Initialize notifications
  await NotificationService.initialize();

  // Register background insight worker
  await insights.registerInsightWorker();

  // Request notification permission (Android 13+)
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  // Create the global container BEFORE runApp.
  // This lets NotificationService write to Riverpod state
  // from its static tap callback (which has no BuildContext).
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      keyManagerProvider.overrideWithValue(keyManager),
      appDatabaseProvider.overrideWithValue(database),
    ],
  );
  NotificationService.setContainer(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VirenApp(),
    ),
  );
}
