import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/model_download_service.dart';
import '../../core/ai/model_setup_screen.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';
import '../../core/security/biometric_service.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/insights/storage_cleaner.dart';
import '../settings/style_guide_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricCapable = true;
  final _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkBiometricCapability();
  }

  Future<void> _checkBiometricCapability() async {
    final capable = await _biometricService.isDeviceBiometricCapable();
    if (mounted) {
      setState(() => _biometricCapable = capable);
    }
  }

  // Experience & Motion
  AnimationIntensity _intensity = AnimationPresets.intensity;

  static const _lockOptions = ['Immediately', '1 minute', '5 minutes', '15 minutes'];
  static const _insightFrequencyOptions = ['Minimal', 'Normal', 'Reflective'];

  // Appearance
  bool _useGoldAccent = false;
  double _fontScale = 1.0;
  bool _densecharts = false;

  // Cloud
  bool _simulatingBackup = false;

  void _runBackup() async {
    setState(() => _simulatingBackup = true);
    
    try {
      final syncService = ref.read(encryptedBackupServiceProvider);
      await syncService.pushToCloud();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, color: DesignTokens.obsidianTeal, size: 18),
              const SizedBox(width: 12),
              const Text('Vault successfully encrypted and synced to cloud.'),
            ]),
            backgroundColor: DesignTokens.graphiteSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(24),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: DesignTokens.crimsonWarning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _simulatingBackup = false);
    }
  }

  void _runRestore() async {
    setState(() => _simulatingBackup = true);
    try {
      final syncService = ref.read(encryptedBackupServiceProvider);
      final metadata = await syncService.pullFromCloud();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored ${metadata.tableCount} tables (${metadata.totalRows} rows) from cloud.'),
            backgroundColor: DesignTokens.obsidianTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: DesignTokens.crimsonWarning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _simulatingBackup = false);
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: DesignTokens.graphiteSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: DesignTokens.crimsonWarning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Wipe Local Data', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DesignTokens.crimsonWarning)),
                ),
              ]),
              const SizedBox(height: 16),
              Text(
                'This will permanently erase all holdings, trades, journal entries, and settings from this device.\n\nThis action is irreversible.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6, color: DesignTokens.textMediumContrast),
              ),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Cancel', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final db = ref.read(appDatabaseProvider);
                        await db.transaction(() async {
                          await db.delete(db.trades).go();
                          await db.delete(db.tradeReasons).go();
                          await db.delete(db.holdings).go();
                          await db.delete(db.alerts).go();
                          await db.delete(db.portfolioSnapshots).go();
                          await db.delete(db.behaviorMetrics).go();
                          await db.delete(db.confidenceMeter).go();
                          await db.delete(db.imports).go();
                          await db.delete(db.priceHistory).go();
                          await db.delete(db.integrityMetadata).go();
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('All local data wiped.'),
                              backgroundColor: DesignTokens.crimsonWarning,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              margin: const EdgeInsets.all(24),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Wipe failed: $e'),
                              backgroundColor: DesignTokens.crimsonWarning,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.crimsonWarning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Wipe Everything'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportSheet() {
    final holdingsAsync = ref.read(holdingsStreamProvider);
    final tradesAsync = ref.read(allTradesProvider);
    final alertsAsync = ref.read(activeAlertsProvider);

    final holdingsCount = holdingsAsync.value?.length ?? 0;
    final tradesCount = tradesAsync.value?.length ?? 0;
    final alertsCount = alertsAsync.value?.length ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignTokens.graphiteSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: DesignTokens.borderSubtle, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Export Preview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Your local vault in JSON format. No data leaves this device unless you explicitly share it.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, height: 1.4)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DesignTokens.graphiteBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DesignTokens.borderSubtle),
              ),
              child: Text(
                '{\n  "holdings": $holdingsCount,\n  "trades": $tradesCount,\n  "alerts": $alertsCount,\n  "exported_at": "${DateTime.now().toUtc().toIso8601String()}",\n  "version": "1.0.0"\n}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: DesignTokens.obsidianTeal,
                  height: 1.7,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share Export'),
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.obsidianTeal,
                  foregroundColor: DesignTokens.graphiteBase,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text('Settings', style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StyleGuideScreen())),
            child: Text('Style Guide', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
          )
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
        children: [

          // ─── Security & Access ───────────────────────────────────
          _SectionHeader(title: 'Security & Access'),
          _SettingsSection(children: [
            _SettingsTile(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric Lock',
              subtitle: _biometricCapable 
                  ? 'Require fingerprint or Face ID on app open and after background timeout. No data leaves device.' 
                  : 'No biometrics configured on this device',
              trailing: CupertinoSwitch(
                value: settings.biometricLock,
                onChanged: _biometricCapable ? (value) async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  if (value == true) {
                    final success = await _biometricService.enableBiometricLock();
                    if (success) {
                      settingsNotifier.setBiometricLock(true);
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Biometric lock enabled')),
                        );
                      }
                    } else {
                      settingsNotifier.setBiometricLock(false);
                    }
                  } else {
                    final success = await _biometricService.disableBiometricLock();
                    if (success) {
                      settingsNotifier.setBiometricLock(false);
                    } else {
                      settingsNotifier.setBiometricLock(true);
                    }
                  }
                } : null,
                activeTrackColor: DesignTokens.obsidianTeal,
              ),
            ),
            if (settings.biometricLock) ...[
              const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.timer_outlined,
                              color: DesignTokens.textHighContrast, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Lock After',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      )),
                              const SizedBox(height: 3),
                              Text(
                                'Lock the app after this much time in the background.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: DesignTokens.textMediumContrast,
                                      height: 1.4,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CupertinoSlidingSegmentedControl<int>(
                      groupValue: settings.lockTimeoutIndex,
                      backgroundColor: DesignTokens.graphiteBase,
                      thumbColor: DesignTokens.graphiteSurface,
                      children: {
                        for (int i = 0; i < _lockOptions.length; i++)
                          i: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            child: Text(
                              _lockOptions[i],
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      },
                      onValueChanged: (v) =>
                          settingsNotifier.setLockTimeoutIndex(v ?? 1),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            _SettingsTile(
              icon: Icons.smart_toy_outlined,
              title: 'Viren AI Model',
              subtitle: 'Re-download the local AI model if the assistant stops working.',
              onTap: () async {
                final ready = await ModelDownloadService.isModelReady();
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => Dialog(
                    backgroundColor: DesignTokens.graphiteSurface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ready ? 'AI Model Installed' : 'AI Model Not Found',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ready
                                ? 'Gemma 3 4B is installed and working. Re-download only if the assistant is behaving unexpectedly.'
                                : 'The AI model has not been downloaded yet. Download it to use the assistant.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: DesignTokens.textMediumContrast,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                if (ready) {
                                  await ModelDownloadService.deleteModel();
                                }
                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ModelSetupScreen(
                                      onComplete: () => Navigator.pop(context),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DesignTokens.obsidianTeal,
                                foregroundColor: DesignTokens.graphiteBase,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(ready ? 'Re-download Model' : 'Download Model'),
                            ),
                          ),
                          if (ready) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            _SettingsTile(
              icon: Icons.memory_rounded,
              title: 'Clear AI Memory',
              subtitle: 'Erase all conversation summaries that Viren recalls between chats.',
              iconColor: DesignTokens.crimsonWarning,
              onTap: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: DesignTokens.graphiteSurface,
                    title: Text('Clear all memories?',
                        style: TextStyle(color: DesignTokens.textHighContrast, fontSize: 16)),
                    content: Text(
                      'Viren will no longer recall summaries from previous conversations. This cannot be undone.',
                      style: TextStyle(color: DesignTokens.textMediumContrast, height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel',
                            style: TextStyle(color: DesignTokens.textMediumContrast)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Clear',
                            style: TextStyle(color: DesignTokens.crimsonWarning)),
                      ),
                    ],
                  ),
                ) ?? false;
                if (confirm) {
                  final db = ref.read(appDatabaseProvider);
                  await db.delete(db.assistantMemories).go();
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: const Text('AI memory cleared.'),
                        backgroundColor: DesignTokens.obsidianTeal,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.all(24),
                      ),
                    );
                  }
                }
              },
            ),
          ]),

          // ─── Intelligence Controls ────────────────────────────────
          _SectionHeader(title: 'Intelligence Controls'),
          _SettingsSection(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: DesignTokens.obsidianTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.tune_rounded, color: DesignTokens.textHighContrast, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alert Sensitivity', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(
                          settings.alertSensitivity < 0.7 ? 'Conservative — only high-certainty signals' : settings.alertSensitivity > 1.3 ? 'Observant — all detected patterns' : 'Balanced — curated signals',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: DesignTokens.obsidianTeal,
                      inactiveTrackColor: DesignTokens.borderSubtle,
                      thumbColor: DesignTokens.obsidianTeal,
                      overlayColor: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: settings.alertSensitivity,
                      min: 0,
                      max: 2,
                      divisions: 2,
                      onChanged: (v) => settingsNotifier.setAlertSensitivity(v),
                    ),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Conservative', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: DesignTokens.textMediumContrast)),
                    Text('Balanced', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: DesignTokens.textMediumContrast)),
                    Text('Observant', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: DesignTokens.textMediumContrast)),
                  ]),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lightbulb_outline_rounded,
                            color: DesignTokens.textHighContrast, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Insight Frequency',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    )),
                            const SizedBox(height: 3),
                            Text(
                              'How often Viren surfaces behavioral observations.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: DesignTokens.textMediumContrast,
                                    height: 1.4,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CupertinoSlidingSegmentedControl<int>(
                    groupValue: settings.insightFrequencyIndex,
                    backgroundColor: DesignTokens.graphiteBase,
                    thumbColor: DesignTokens.graphiteSurface,
                    children: {
                      for (int i = 0; i < _insightFrequencyOptions.length; i++)
                        i: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(
                            _insightFrequencyOptions[i],
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                        ),
                    },
                    onValueChanged: (v) =>
                        settingsNotifier.setInsightFrequencyIndex(v ?? 1),
                  ),
                ],
              ),
            ),
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            _SettingsTile(
              icon: Icons.visibility_off_outlined,
              title: 'Hide Low-Confidence Insights',
              subtitle: 'Only show insights with >70% confidence score.',
              trailing: CupertinoSwitch(
                value: settings.hideLowConfidence,
                onChanged: (v) => settingsNotifier.setHideLowConfidence(v),
                activeTrackColor: DesignTokens.obsidianTeal,
              ),
            ),
          ]),

          // ─── Experience & Motion ──────────────────────────────────
          _SectionHeader(title: 'Experience & Motion'),
          _SettingsSection(children: [
            _SettingsTile(
              icon: Icons.animation_rounded,
              title: 'Calm Mode',
              subtitle: 'Disables all non-essential animations, staggers, and parallax. Navigation remains smooth.',
              trailing: CupertinoSwitch(
                value: settings.isCalmMode,
                onChanged: (v) {
                  settingsNotifier.setCalmMode(v);
                  AnimationPresets.calmModeEnabled = v;
                },
                activeTrackColor: DesignTokens.obsidianTeal,
              ),
            ),
            if (!settings.isCalmMode) ...[
              const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: DesignTokens.obsidianTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.speed_rounded, color: DesignTokens.textHighContrast, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text('Animation Intensity', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    CupertinoSlidingSegmentedControl<AnimationIntensity>(
                      groupValue: _intensity,
                      backgroundColor: DesignTokens.graphiteBase,
                      thumbColor: DesignTokens.graphiteSurface,
                      children: {
                        AnimationIntensity.subtle: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('Subtle', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11))),
                        AnimationIntensity.balanced: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('Balanced', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11))),
                        AnimationIntensity.expressive: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('Expressive', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11))),
                      },
                      onValueChanged: (v) {
                        setState(() {
                          _intensity = v ?? AnimationIntensity.balanced;
                          AnimationPresets.intensity = _intensity;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ]),

          _SectionHeader(title: 'Offline & Cloud'),
          _SettingsSection(children: [
            _SettingsTile(
              icon: Icons.cloud_off_rounded,
              title: 'Offline Vault',
              subtitle: 'Viren is offline-first. All data lives on your device. This cannot be disabled.',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: DesignTokens.obsidianTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('Active', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.obsidianTeal, fontWeight: FontWeight.w600)),
              ),
            ),
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            _SettingsTile(
              icon: Icons.cloud_upload_rounded,
              title: 'Push Backup to Cloud',
              subtitle: 'Encrypts your vault with your local key and uploads it to Supabase.',
              trailing: _simulatingBackup
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: DesignTokens.obsidianTeal))
                : TextButton(
                    onPressed: _runBackup,
                    style: TextButton.styleFrom(foregroundColor: DesignTokens.obsidianTeal, padding: EdgeInsets.zero),
                    child: const Text('Push'),
                  ),
            ),
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            _SettingsTile(
              icon: Icons.cloud_download_rounded,
              title: 'Pull Backup from Cloud',
              subtitle: 'Downloads and decrypts the latest synced vault.',
              trailing: _simulatingBackup
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: DesignTokens.obsidianTeal))
                : TextButton(
                    onPressed: _runRestore,
                    style: TextButton.styleFrom(foregroundColor: DesignTokens.ashGold, padding: EdgeInsets.zero),
                    child: const Text('Pull'),
                  ),
            ),
          ]),

          // ─── Data & Control ───────────────────────────────────────
          _SectionHeader(title: 'Data & Control'),
          _SettingsSection(children: [
            _SettingsTile(
              icon: Icons.storage_rounded,
              title: 'Storage Used',
              trailing: null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 20, 16),
              child: Builder(
                builder: (context) {
                  final holdingsCount = ref.watch(holdingsStreamProvider).value?.length ?? 0;
                  final tradesCount = ref.watch(allTradesProvider).value?.length ?? 0;
                  final alertsCount = ref.watch(activeAlertsProvider).value?.length ?? 0;
                  final importsCount = ref.watch(importsStreamProvider).value?.length ?? 0;
                  final total = holdingsCount + tradesCount + alertsCount + importsCount;
                  final tradeFraction = total > 0 ? (holdingsCount + tradesCount) / total : 0.0;
                  final alertFraction = total > 0 ? alertsCount / total : 0.0;
                  final importFraction = total > 0 ? importsCount / total : 0.0;

                  return Column(
                    children: [
                      _StorageRow(label: 'Holdings & Trades', bytes: '${holdingsCount + tradesCount} records', fraction: tradeFraction),
                      const SizedBox(height: 8),
                      _StorageRow(label: 'Alerts', bytes: '$alertsCount records', fraction: alertFraction),
                      const SizedBox(height: 8),
                      _StorageRow(label: 'Imports', bytes: '$importsCount records', fraction: importFraction),
                    ],
                  );
                },
              ),
            ),
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            _SettingsTile(
              icon: Icons.cleaning_services_rounded,
              title: 'Smart Vault Cleanup',
              subtitle: 'Clear old price snapshots and insights. Keeps your notes intact.',
              onTap: () async {
                final db = ref.read(appDatabaseProvider);
                final cleaner = StorageCleaner(db);
                final messenger = ScaffoldMessenger.of(context);
                
                try {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Cleaning up old records...'), duration: Duration(seconds: 1)),
                  );
                  await cleaner.run();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Cleanup complete.'),
                        backgroundColor: DesignTokens.obsidianTeal,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Cleanup failed: $e'),
                        backgroundColor: DesignTokens.crimsonWarning,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            _SettingsTile(
              icon: Icons.file_download_outlined,
              title: 'Export Local Data',
              subtitle: 'Preview and share your vault as JSON.',
              onTap: _showExportSheet,
            ),
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            _SettingsTile(
              icon: Icons.delete_forever_rounded,
              title: 'Wipe All Local Data',
              iconColor: DesignTokens.crimsonWarning,
              titleColor: DesignTokens.crimsonWarning,
              onTap: _showResetDialog,
            ),
          ]),

          // ─── Appearance ───────────────────────────────────────────
          _SectionHeader(title: 'Appearance'),
          _SettingsSection(children: [
            _SettingsTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark Theme',
              subtitle: 'Viren is exclusively dark-mode. This cannot be changed.',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: DesignTokens.borderSubtle, borderRadius: BorderRadius.circular(12)),
                child: Text('Always On', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
              ),
            ),
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            _SettingsTile(
              icon: Icons.palette_outlined,
              title: 'Accent Emphasis',
              subtitle: _useGoldAccent ? 'Gold — milestones and achievements lead.' : 'Teal — actions and focus lead.',
              trailing: CupertinoSwitch(
                value: _useGoldAccent,
                onChanged: (v) => setState(() => _useGoldAccent = v),
                activeTrackColor: DesignTokens.ashGold,
              ),
            ),
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: DesignTokens.obsidianTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.text_fields_rounded, color: DesignTokens.textHighContrast, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Font Scale', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    Text('${(_fontScale * 100).round()}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
                  ],
                )),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: DesignTokens.obsidianTeal,
                    inactiveTrackColor: DesignTokens.borderSubtle,
                    thumbColor: DesignTokens.obsidianTeal,
                    trackHeight: 3,
                  ),
                  child: SizedBox(
                    width: 120,
                    child: Slider(value: _fontScale, min: 0.85, max: 1.2, divisions: 7, onChanged: (v) => setState(() => _fontScale = v)),
                  ),
                ),
              ]),
            ),
            const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
            _SettingsTile(
              icon: Icons.bar_chart_rounded,
              title: 'Dense Charts',
              subtitle: 'Compress chart height to show more data at once.',
              trailing: CupertinoSwitch(
                value: _densecharts,
                onChanged: (v) => setState(() => _densecharts = v),
                activeTrackColor: DesignTokens.obsidianTeal,
              ),
            ),
          ]),

          const SizedBox(height: 48),
          Center(
            child: Text(
              'Viren v1.0.0 — Offline, Private, Yours',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast.withValues(alpha: 0.5), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: DesignTokens.textMediumContrast,
          letterSpacing: 1.2,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Settings Section ─────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final List<Widget> children;
  const _SettingsSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(children: children),
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? DesignTokens.obsidianTeal).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? DesignTokens.textHighContrast, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: titleColor ?? DesignTokens.textHighContrast,
                    fontWeight: FontWeight.w500,
                  )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DesignTokens.textMediumContrast,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (trailing == null && onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: DesignTokens.textMediumContrast, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Storage Row ──────────────────────────────────────────────────────────────

class _StorageRow extends StatelessWidget {
  final String label;
  final String bytes;
  final double fraction;

  const _StorageRow({required this.label, required this.bytes, required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast))),
        Text(bytes, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: DesignTokens.graphiteBase,
              color: DesignTokens.obsidianTeal,
              minHeight: 4,
            ),
          ),
        ),
      ],
    );
  }
}
