import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/insights/insight_worker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlertSettingsScreen — User preferences for Viren's intelligence system.
//
// Controls:
//   - Master toggle (enable/disable all background monitoring)
//   - Quiet hours (default 10 PM – 8 AM)
//   - Drawdown threshold (how far down before alerting)
//   - Which alert types are enabled
// ─────────────────────────────────────────────────────────────────────────────

class AlertSettingsScreen extends ConsumerStatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  ConsumerState<AlertSettingsScreen> createState() =>
      _AlertSettingsScreenState();
}

class _AlertSettingsScreenState
    extends ConsumerState<AlertSettingsScreen> {
  bool _monitoringEnabled = true;
  bool _quietHoursEnabled = true;
  int _quietFrom = 22; // 10 PM
  int _quietTo = 8; // 8 AM
  double _drawdownThreshold = 5.0; // 5%
  bool _priceAlertsEnabled = true;
  bool _newsAlertsEnabled = true;
  bool _macroAlertsEnabled = true;
  bool _patternAlertsEnabled = true;
  bool _behaviourAlertsEnabled = true;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monitoringEnabled =
          prefs.getBool('alerts_monitoring_enabled') ?? true;
      _quietHoursEnabled =
          prefs.getBool('alerts_quiet_hours_enabled') ?? true;
      _quietFrom = prefs.getInt('alerts_quiet_from') ?? 22;
      _quietTo = prefs.getInt('alerts_quiet_to') ?? 8;
      _drawdownThreshold =
          prefs.getDouble('alerts_drawdown_threshold') ?? 5.0;
      _priceAlertsEnabled =
          prefs.getBool('alerts_price_enabled') ?? true;
      _newsAlertsEnabled =
          prefs.getBool('alerts_news_enabled') ?? true;
      _macroAlertsEnabled =
          prefs.getBool('alerts_macro_enabled') ?? true;
      _patternAlertsEnabled =
          prefs.getBool('alerts_pattern_enabled') ?? true;
      _behaviourAlertsEnabled =
          prefs.getBool('alerts_behaviour_enabled') ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alerts_monitoring_enabled', _monitoringEnabled);
    await prefs.setBool('alerts_quiet_hours_enabled', _quietHoursEnabled);
    await prefs.setInt('alerts_quiet_from', _quietFrom);
    await prefs.setInt('alerts_quiet_to', _quietTo);
    await prefs.setDouble('alerts_drawdown_threshold', _drawdownThreshold);
    await prefs.setBool('alerts_price_enabled', _priceAlertsEnabled);
    await prefs.setBool('alerts_news_enabled', _newsAlertsEnabled);
    await prefs.setBool('alerts_macro_enabled', _macroAlertsEnabled);
    await prefs.setBool('alerts_pattern_enabled', _patternAlertsEnabled);
    await prefs.setBool('alerts_behaviour_enabled', _behaviourAlertsEnabled);
  }

  Future<void> _toggleMonitoring(bool value) async {
    setState(() => _monitoringEnabled = value);
    if (value) {
      await registerInsightWorker();
    } else {
      await cancelInsightWorker();
    }
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        backgroundColor: DesignTokens.graphiteBase,
        elevation: 0,
        title: Text(
          'Intelligence Settings',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: DesignTokens.obsidianTeal,
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              children: [
                // ── Master toggle ───────────────────────────
                _SectionHeader(title: 'Background Monitoring'),
                _SettingsCard(
                  child: SwitchListTile(
                    value: _monitoringEnabled,
                    onChanged: _toggleMonitoring,
                    activeTrackColor: DesignTokens.obsidianTeal,
                    title: Text(
                      'Enable Viren Intelligence',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: DesignTokens.textHighContrast),
                    ),
                    subtitle: Text(
                      'Scans for price alerts, relevant news, and '
                      'portfolio patterns every 15 minutes during market hours.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: DesignTokens.textMediumContrast),
                    ),
                  ),
                ),

                // ── Quiet Hours ─────────────────────────────
                const SizedBox(height: 16),
                _SectionHeader(title: 'Quiet Hours'),
                _SettingsCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _quietHoursEnabled,
                        onChanged: (v) {
                          setState(() => _quietHoursEnabled = v);
                          _save();
                        },
                        activeTrackColor: DesignTokens.obsidianTeal,
                        title: Text(
                          'Enable Quiet Hours',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color:
                                      DesignTokens.textHighContrast),
                        ),
                        subtitle: Text(
                          'Suppresses LOW and MEDIUM alerts during quiet period.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color:
                                      DesignTokens.textMediumContrast),
                        ),
                      ),
                      if (_quietHoursEnabled) ...[
                        const Divider(
                            color: Colors.white12, height: 1),
                        _TimePickerRow(
                          label: 'Quiet from',
                          hour: _quietFrom,
                          onChanged: (h) {
                            setState(() => _quietFrom = h);
                            _save();
                          },
                        ),
                        _TimePickerRow(
                          label: 'Quiet until',
                          hour: _quietTo,
                          onChanged: (h) {
                            setState(() => _quietTo = h);
                            _save();
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Thresholds ──────────────────────────────
                const SizedBox(height: 16),
                _SectionHeader(title: 'Alert Thresholds'),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Drawdown alert threshold',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color:
                                          DesignTokens.textHighContrast),
                            ),
                            Text(
                              '${_drawdownThreshold.toStringAsFixed(0)}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: DesignTokens.obsidianTeal,
                                      fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Slider(
                        value: _drawdownThreshold,
                        min: 2,
                        max: 15,
                        divisions: 13,
                        activeColor: DesignTokens.obsidianTeal,
                        inactiveColor:
                            Colors.white.withValues(alpha: 0.1),
                        onChanged: (v) {
                          setState(() => _drawdownThreshold = v);
                        },
                        onChangeEnd: (_) => _save(),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'Alert when a holding falls this far below your avg cost.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color:
                                      DesignTokens.textMediumContrast),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Alert type toggles ───────────────────────
                const SizedBox(height: 16),
                _SectionHeader(title: 'Intelligence Layers'),
                _SettingsCard(
                  child: Column(
                    children: [
                      _AlertTypeToggle(
                        label: 'Price Alerts',
                        subtitle:
                            'Drawdown, recovery, circuit breaker',
                        value: _priceAlertsEnabled,
                        onChanged: (v) {
                          setState(() => _priceAlertsEnabled = v);
                          _save();
                        },
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      _AlertTypeToggle(
                        label: 'News Intelligence',
                        subtitle: 'RSS feeds analysed by Qwen on-device',
                        value: _newsAlertsEnabled,
                        onChanged: (v) {
                          setState(() => _newsAlertsEnabled = v);
                          _save();
                        },
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      _AlertTypeToggle(
                        label: 'Macro Intelligence',
                        subtitle:
                            'RBI, SEBI, Fed events — daily, on-device',
                        value: _macroAlertsEnabled,
                        onChanged: (v) {
                          setState(() => _macroAlertsEnabled = v);
                          _save();
                        },
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      _AlertTypeToggle(
                        label: 'Pattern Detection',
                        subtitle:
                            'DCA signals, concentration drift, streaks',
                        value: _patternAlertsEnabled,
                        onChanged: (v) {
                          setState(() => _patternAlertsEnabled = v);
                          _save();
                        },
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      _AlertTypeToggle(
                        label: 'Behaviour Insights',
                        subtitle:
                            'Mirrors your own historical patterns back to you',
                        value: _behaviourAlertsEnabled,
                        onChanged: (v) {
                          setState(() => _behaviourAlertsEnabled = v);
                          _save();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DesignTokens.textMediumContrast,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

class _AlertTypeToggle extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AlertTypeToggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeTrackColor: DesignTokens.obsidianTeal,
      title: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: DesignTokens.textHighContrast),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: DesignTokens.textMediumContrast),
      ),
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  final String label;
  final int hour;
  final ValueChanged<int> onChanged;

  const _TimePickerRow({
    required this.label,
    required this.hour,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayHour = hour == 0
        ? '12 AM'
        : hour < 12
            ? '$hour AM'
            : hour == 12
                ? '12 PM'
                : '${hour - 12} PM';

    return ListTile(
      title: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: DesignTokens.textHighContrast),
      ),
      trailing: GestureDetector(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: hour, minute: 0),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(alwaysUse24HourFormat: false),
              child: child!,
            ),
          );
          if (picked != null) {
            onChanged(picked.hour);
          }
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: DesignTokens.obsidianTeal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            displayHour,
            style: TextStyle(
              color: DesignTokens.obsidianTeal,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
