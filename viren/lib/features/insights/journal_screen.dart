import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/providers/database_providers.dart';
import '../../core/database/providers/journal_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/design_tokens.dart';
import 'package:flutter/services.dart';
import '../../core/utils/pdf_export_service.dart';
import 'replay_screen.dart';
import 'widgets/insight_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// JournalScreen — The user's personal investment journal.
//
// Every insight the user stars (swipe right) appears here permanently.
// These are the moments worth remembering: a macro call that played out,
// a drawdown they held through, a pattern they noticed.
//
// Starred insights are never automatically dismissed or cleared.
// The user must manually remove them by tapping the un-star button.
// ─────────────────────────────────────────────────────────────────────────────

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  bool _exporting = false;

  Future<void> _exportJournal(
      BuildContext context, List<Alert> alerts) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final path = await PdfExportService.exportJournal(alerts);
      if (!context.mounted) return;

      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Try again.')),
        );
        return;
      }

      // Copy path to clipboard and show snackbar
      await Clipboard.setData(ClipboardData(text: path));
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignTokens.graphiteSurface,
          content: Text(
            'Exported to: $path\n(Path copied to clipboard)',
            style: TextStyle(
              color: DesignTokens.textHighContrast,
              fontSize: 12,
            ),
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: DesignTokens.obsidianTeal,
            onPressed: () {},
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final journalAsync = ref.watch(journalAlertsProvider);

    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        backgroundColor: DesignTokens.graphiteBase,
        elevation: 0,
        title: Text(
          'Journal',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Export button
          journalAsync.maybeWhen(
            data: (alerts) => alerts.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.ios_share_rounded,
                        color: DesignTokens.textMediumContrast),
                    tooltip: 'Export journal',
                    onPressed: () => _exportJournal(context, alerts),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: journalAsync.maybeWhen(
              data: (alerts) => Center(
                child: Text(
                  '${alerts.length} saved',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignTokens.textMediumContrast,
                      ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      body: journalAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) return _buildEmptyState(context);
          return _buildJournal(context, ref, alerts);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: DesignTokens.obsidianTeal,
          ),
        ),
        error: (_, __) => _buildEmptyState(context),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline_rounded,
            size: 48,
            color: DesignTokens.textMediumContrast.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Your journal is empty',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe right on any insight to save it here.\nThese become your personal investment record.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.textMediumContrast,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournal(
      BuildContext context, WidgetRef ref, List<Alert> alerts) {
    // Group by month for journal-style layout
    final byMonth = <String, List<Alert>>{};
    for (final a in alerts) {
      final key = DateFormat('MMMM yyyy').format(a.createdAt);
      byMonth.putIfAbsent(key, () => []).add(a);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final entry in byMonth.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
            child: Text(
              entry.key.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ...entry.value.map((alert) => _JournalCard(alert: alert)),
        ],
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReplayScreen()),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded,
                    size: 14,
                    color: DesignTokens.textMediumContrast),
                const SizedBox(width: 8),
                Text(
                  'View all history',
                  style: TextStyle(
                    color: DesignTokens.textMediumContrast,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 14,
                    color: DesignTokens.textMediumContrast
                        .withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ── Journal Card — like InsightCard but with un-star action ──────

class _JournalCard extends ConsumerWidget {
  final Alert alert;
  const _JournalCard({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key('journal_${alert.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: DesignTokens.ashGold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.bookmark_remove_rounded,
            color: DesignTokens.ashGold),
      ),
      onDismissed: (_) async {
        // Un-star: clear snoozedUntil back to null
        final db = ref.read(appDatabaseProvider);
        await (db.update(db.alerts)
              ..where((a) => a.id.equals(alert.id)))
            .write(AlertsCompanion(
          snoozedUntil: drift.Value(null),
        ));
      },
      child: InsightCard(
        alert: alert,
        isStarred: true,
        showAskViren: false,
      ),
    );
  }
}
