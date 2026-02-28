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

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        keyManagerProvider.overrideWithValue(keyManager),
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const VirenApp(),
    ),
  );
}
