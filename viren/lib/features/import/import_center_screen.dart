import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';

import '../../core/theme/design_tokens.dart';
import '../../core/auth/auth_service.dart';
import '../../core/ingestion/email/email_import_service.dart';
import '../../core/ingestion/email/gmail_smoke_test.dart';
import '../../core/ingestion/csv_import_service.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/ingestion/broker_templates.dart';
import '../import/column_mapping_screen.dart';
import '../import/manual_trade_entry_screen.dart';
class ImportCenterScreen extends ConsumerStatefulWidget {
  const ImportCenterScreen({super.key});

  @override
  ConsumerState<ImportCenterScreen> createState() => _ImportCenterScreenState();
}

class _ImportCenterScreenState extends ConsumerState<ImportCenterScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String? _scanStatusMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startScanning([String? statusMessage]) {
    setState(() {
      _isScanning = true;
      _scanStatusMessage = statusMessage;
    });
    _pulseController.repeat(reverse: true);
  }

  void _stopScanning() {
    if (mounted) {
      setState(() {
        _isScanning = false;
        _scanStatusMessage = null;
      });
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: DesignTokens.obsidianTeal),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.obsidianTeal))),
          ],
        ),
        backgroundColor: DesignTokens.graphiteSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(24),
      ),
    );
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: DesignTokens.crimsonWarning),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.crimsonWarning))),
          ],
        ),
        backgroundColor: DesignTokens.graphiteSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(24),
      ),
    );
  }

  // ── CSV File Import ──────────────────────────────────────────────────────────

  Future<void> _uploadStatement() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;

      _startScanning('Reading CSV file...');

      final csvText = await File(file.path!).readAsString();
      final csvService = ref.read(csvImportServiceProvider);

      // Step 1-2: Parse and detect template
      final rows = csvService.parseRawCsv(csvText);
      if (rows.isEmpty) {
        _stopScanning();
        _showErrorSnack('CSV file is empty.');
        return;
      }

      setState(() => _scanStatusMessage = 'Detecting broker format...');
      final headers = rows.first;
      final template = csvService.detectTemplate(headers);

      // Step 3: Map columns
      final initialMapping = csvService.mapColumns(headers, template);

      _stopScanning();
      if (!mounted) return;

      // Navigate to Column Mapping Screen for confirmation/edits
      final finalMapping = await Navigator.of(context).push<Map<int, CsvField>>(
        MaterialPageRoute(
          builder: (context) => ColumnMappingScreen(
            csvHeaders: headers,
            initialMapping: initialMapping,
          ),
        ),
      );

      if (finalMapping == null) return; // User cancelled mapping

      _startScanning('Parsing trades...');
      if (!mounted) return;

      // Step 4: Dry run using the confirmed mapping
      final preview = csvService.dryRun(
        rawCsvText: csvText,
        columnMapping: finalMapping,
        template: template,
      );

      _stopScanning();

      if (!mounted) return;

      if (preview.hasErrors && preview.trades.isEmpty) {
        _showErrorSnack('Parse failed: ${preview.errors.first}');
        return;
      }

      // Show confirmation dialog
      final confirmed = await _showCsvPreviewDialog(preview, template?.brokerName);
      if (confirmed != true) return;

      // Step 5: Commit
      _startScanning('Importing trades...');
      final importResult = await csvService.commit(preview);
      _stopScanning();

      if (mounted) {
        _showSuccessSnack(
          'Imported ${importResult.successfulRows}/${importResult.totalRows} trades'
          '${importResult.failedRows > 0 ? ' (${importResult.failedRows} failed)' : ''}.'
        );
      }
    } catch (e) {
      _stopScanning();
      if (mounted) _showErrorSnack('Import failed: $e');
    }
  }

  Future<bool?> _showCsvPreviewDialog(CsvImportPreview preview, String? brokerName) {
    return showDialog<bool>(
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
                const Icon(Icons.file_present_rounded, color: DesignTokens.obsidianTeal),
                const SizedBox(width: 12),
                Text('Import Preview', style: Theme.of(context).textTheme.titleLarge),
              ]),
              const SizedBox(height: 16),
              if (brokerName != null) ...[
                _PreviewRow(label: 'Broker detected', value: brokerName),
                const SizedBox(height: 8),
              ],
              _PreviewRow(label: 'Trades found', value: '${preview.trades.length}'),
              const SizedBox(height: 8),
              _PreviewRow(label: 'Parse confidence', value: '${preview.aggregateConfidence}%'),
              if (preview.warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PreviewRow(label: 'Warnings', value: '${preview.warnings.length}'),
              ],
              const SizedBox(height: 24),
              // Show first few trades as preview
              if (preview.trades.isNotEmpty) ...[
                Text('Trades:', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
                const SizedBox(height: 8),
                ...preview.trades.take(5).map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${t.tradeType.name.toUpperCase()} ${t.symbol} × ${t.quantity} @ ₹${t.pricePerUnit.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: DesignTokens.obsidianTeal,
                    ),
                  ),
                )),
                if (preview.trades.length > 5)
                  Text(
                    '… and ${preview.trades.length - 5} more',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast),
                  ),
              ],
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.obsidianTeal,
                      foregroundColor: DesignTokens.graphiteBase,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Import'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Email Scan ──────────────────────────────────────────────────────────────

  Future<void> _scanEmails() async {
    _startScanning('Connecting to Gmail...');

    try {
      final authService = await AuthService.create(scopes: [
        'https://www.googleapis.com/auth/gmail.readonly'
      ]);

      // ═══════════════════════════════════════════════════════════════════
      // STEP 0: GMAIL PROOF MODE (smoke test)
      // ═══════════════════════════════════════════════════════════════════
      setState(() => _scanStatusMessage = 'Testing Gmail connection...');
      final proofResult = await GmailSmokeTest.run(authService);
      if (!mounted) { _stopScanning(); return; }

      if (!proofResult.gmailReachable || proofResult.messageCount == 0) {
        _stopScanning();
        await _showGmailDiagnosticDialog(proofResult);
        return;
      }

      // ═══════════════════════════════════════════════════════════════════
      // STAGE 1: DISCOVERY
      // ═══════════════════════════════════════════════════════════════════
      setState(() => _scanStatusMessage = 'Discovering broker statements...');
      final importService = ref.read(emailImportServiceProvider);

      final discovery = await importService.discover(authService: authService, since: null);

      if (!mounted) { _stopScanning(); return; }

      if (discovery.isEmpty) {
        _stopScanning();
        _showErrorSnack('No broker emails found from NSE or SBI.');
        return;
      }

      // ═══════════════════════════════════════════════════════════════════
      // STAGE 2: UX CHECKPOINT (Confirm & Request PAN)
      // ═══════════════════════════════════════════════════════════════════
      _stopScanning();
      
      String pan = '';
      if (discovery.totalPdfAttachments > 0) {
        final inputtedPan = await _showPanInputDialog(discovery);
        if (inputtedPan == null || inputtedPan.isEmpty) {
          // User cancelled import
          return;
        }
        pan = inputtedPan;
      }

      // ═══════════════════════════════════════════════════════════════════
      // STAGE 3, 4, 5: DECRYPT, PARSE, LEDGER
      // ═══════════════════════════════════════════════════════════════════
      _startScanning('Unlocking & Processing ${discovery.totalPdfAttachments} PDFs...');
      
      final preview = await importService.process(
        discovery: discovery, 
        pan: pan, 
        authService: authService,
      );

      _stopScanning();
      if (!mounted) return;

      if (preview.allDecryptionsFailed) {
        _showErrorSnack(
          'Found ${preview.totalBrokerEmailsFound} broker emails, but '
          'all PDFs failed to decrypt. '
          'Please verify your PAN is correct.',
        );
        return;
      }

      // Check if all documents were classified as UNKNOWN
      if (preview.totalUnknownDocuments > 0 && preview.totalUnknownDocuments == preview.results.length) {
        _showErrorSnack('Documents found but formats not yet supported.');
        return;
      }

      if (!preview.hasTrades && preview.totalSnapshotsFound == 0) {
        _showErrorSnack('Statements found, but no executed trades detected.');
        return;
      }

      // ═══════════════════════════════════════════════════════════════════
      // FINAL STAGE: USER VERIFICATION
      // ═══════════════════════════════════════════════════════════════════
      final confirmed = await _showEmailPreviewDialog(preview);
      if (confirmed != true) return;

      _startScanning('Importing trades...');
      final result = await importService.commit(preview);
      _stopScanning();

      if (mounted) {
        final validationDocsCount = preview.results.where((r) => r.snapshots.isNotEmpty).length;
        _showSuccessSnack(
          '${result.successfulTrades} trades imported, $validationDocsCount documents used for validation.'
        );
      }
    } catch (e) {
      _stopScanning();
      if (mounted) {
        _showErrorSnack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  /// Shows a diagnostic dialog with the Gmail smoke test results.
  Future<void> _showGmailDiagnosticDialog(GmailProofResult result) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: DesignTokens.graphiteSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      result.gmailReachable
                          ? Icons.warning_amber_rounded
                          : Icons.error_outline_rounded,
                      color: result.gmailReachable ? Colors.amber : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      result.gmailReachable
                          ? 'Gmail Reachable — No Broker Emails'
                          : 'Gmail Connection Failed',
                      style: Theme.of(context).textTheme.titleMedium,
                    )),
                  ]),
                  const SizedBox(height: 16),
                  _DiagRow(label: 'Gmail reachable', value: result.gmailReachable ? 'Yes ✓' : 'No ✗'),
                  _DiagRow(label: 'Messages found', value: '${result.messageCount}'),
                  _DiagRow(label: 'Auth email', value: result.authenticatedEmail ?? 'unknown'),
                  _DiagRow(label: 'Token (prefix)', value: result.tokenPrefix ?? 'none'),
                  _DiagRow(label: 'Token expiry', value: result.tokenExpiry?.toIso8601String() ?? 'unknown'),
                  _DiagRow(label: 'Scopes', value: result.grantedScopes.isEmpty
                      ? 'none'
                      : result.grantedScopes.join('\n')),
                  if (result.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        result.errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade300,
                        ),
                      ),
                    ),
                  ],
                  if (result.sampleSubjects.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Sample emails:', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DesignTokens.textMediumContrast,
                    )),
                    const SizedBox(height: 4),
                    ...result.sampleSubjects.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(s, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace', fontSize: 10,
                        color: DesignTokens.obsidianTeal,
                      )),
                    )),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.obsidianTeal,
                        foregroundColor: DesignTokens.graphiteBase,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════
  /// STAGE 2: CONFIRMATION & SECURE PAN INPUT
  /// Blocks the pipeline until the human provides their PAN.
  /// ═══════════════════════════════════════════════════════════════════
  Future<String?> _showPanInputDialog(EmailDiscoveryResult discovery) {
    final panController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: DesignTokens.graphiteSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.shield_rounded, color: DesignTokens.obsidianTeal),
                  const SizedBox(width: 12),
                  Text('Broker Data Found', style: Theme.of(context).textTheme.titleLarge),
                ]),
                const SizedBox(height: 20),
                _PreviewRow(label: 'Broker Emails', value: '${discovery.totalBrokerEmailsFound}'),
                const SizedBox(height: 8),
                _PreviewRow(label: 'Secure PDFs', value: '${discovery.totalPdfAttachments}'),
                const SizedBox(height: 24),
                Text(
                  'These PDFs are encrypted by your broker. '
                  'Enter your PAN (UPPERCASE) to unlock and process them.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: panController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 10,
                  obscureText: true, // PAN is treated as a sensitive key
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ABCDE1234F',
                    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: DesignTokens.textMediumContrast.withValues(alpha: 0.3),
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                    filled: true,
                    fillColor: DesignTokens.graphiteBase,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: DesignTokens.obsidianTeal, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: const Icon(Icons.key_rounded, color: DesignTokens.textMediumContrast),
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text('Cancel Import', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final pan = panController.text.trim().toUpperCase();
                        if (pan.length == 10) {
                          Navigator.pop(ctx, pan);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Enter a valid 10-character PAN'),
                              backgroundColor: DesignTokens.crimsonWarning,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.obsidianTeal,
                        foregroundColor: DesignTokens.graphiteBase,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Unlock PDFs'),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'PAN is never saved or logged.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DesignTokens.obsidianTeal.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }





  Future<bool?> _showEmailPreviewDialog(EmailImportPreview preview) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: DesignTokens.graphiteSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.mail_outline_rounded, color: DesignTokens.obsidianTeal),
                    const SizedBox(width: 12),
                    Text('Email Scan Results', style: Theme.of(context).textTheme.titleLarge),
                  ]),
                  const SizedBox(height: 16),
                  // ── Metrics Grid ──
                  _PreviewRow(label: 'Emails found', value: '${preview.totalBrokerEmailsFound}'),
                  const SizedBox(height: 8),
                  _PreviewRow(label: 'Trades found', value: '${preview.totalTradesFound}'),
                  const SizedBox(height: 8),
                  _PreviewRow(label: 'Snapshots found', value: '${preview.totalSnapshotsFound}'),
                  const SizedBox(height: 8),
                  _PreviewRow(label: 'Confidence', value: '${preview.aggregateConfidence}%'),
                  // ── Discrepancies ──
                  if (preview.hasDiscrepancies) ...[
                    const SizedBox(height: 16),
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Ledger Discrepancies (${preview.ledgerDiscrepancies.length})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.amber),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    ...preview.ledgerDiscrepancies.take(3).map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 26),
                      child: Text(d, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignTokens.textMediumContrast, fontSize: 11,
                      )),
                    )),
                    if (preview.ledgerDiscrepancies.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(left: 26),
                        child: Text(
                          '… and ${preview.ledgerDiscrepancies.length - 3} more',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast),
                        ),
                      ),
                  ],
                  // ── Ledger Errors ──
                  if (preview.ledgerErrors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Ledger Errors (${preview.ledgerErrors.length})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red.shade400),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    ...preview.ledgerErrors.take(3).map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 26),
                      child: Text(e, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignTokens.textMediumContrast, fontSize: 11,
                      )),
                    )),
                  ],
                  const SizedBox(height: 16),
                  // ── Trade Preview ──
                  if (preview.results.isNotEmpty) ...[
                    Text('Extracted:', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
                    const SizedBox(height: 8),
                    ...preview.results.expand((r) => r.trades).take(5).map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${t.tradeType.name.toUpperCase()} ${t.symbol} × ${t.quantity.toStringAsFixed(0)} @ ₹${t.pricePerUnit.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: DesignTokens.obsidianTeal,
                        ),
                      ),
                    )),
                    if (preview.totalTradesFound > 5)
                      Text(
                        '… and ${preview.totalTradesFound - 5} more',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast),
                      ),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.obsidianTeal,
                          foregroundColor: DesignTokens.graphiteBase,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Import All'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final importsAsync = ref.watch(importsStreamProvider);

    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text('Import Center', style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to Vault',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Viren operates locally. Any files dropped here are parsed purely on-device and never leave your phone.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: DesignTokens.textMediumContrast,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),

            // Import Action Cards
            _ImportActionCard(
              icon: Icons.upload_file_rounded,
              title: 'Upload Statement',
              description: 'Drop a CSV from your broker.',
              statusMessage: _scanStatusMessage,
              onTap: _isScanning ? () {} : _uploadStatement,
              isScanning: _isScanning,
              pulseAnimation: _pulseAnimation,
            ),
            const SizedBox(height: 16),
            _ImportActionCard(
              icon: Icons.mail_outline_rounded,
              title: 'Connect Email',
              description: 'Auto-scan Gmail for contract notes.',
              statusMessage: _isScanning ? _scanStatusMessage : null,
              onTap: _isScanning ? () {} : _scanEmails,
              isScanning: _isScanning,
              pulseAnimation: _isScanning ? _pulseAnimation : null,
            ),
            const SizedBox(height: 16),
            _ImportActionCard(
              icon: Icons.edit_rounded,
              title: 'Manual Entry',
              description: 'Record a single trade with your thesis.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManualTradeEntryScreen()),
                );
              },
            ),

            const SizedBox(height: 48),
            Text(
               'Recent Parses',
               style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            
            // Real import history from database
            importsAsync.when(
              data: (imports) {
                if (imports.isEmpty) {
                  return _EmptyParseHistory();
                }
                return Column(
                  children: imports.take(10).map((imp) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ParseHistoryItem(import_: imp),
                  )).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DesignTokens.obsidianTeal,
                  ),
                ),
              ),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: DesignTokens.crimsonWarning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Failed to load import history: $e',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.crimsonWarning),
                ),
              ),
            ),
          ],
        ),
      )
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyParseHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 40, color: DesignTokens.textMediumContrast.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'No imports yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DesignTokens.textMediumContrast),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a CSV, connect your email, or add a trade manually to get started.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DesignTokens.textMediumContrast.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Preview Row ──────────────────────────────────────────────────────────────

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.textMediumContrast)),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DiagRow extends StatelessWidget {
  final String label;
  final String value;

  const _DiagRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DesignTokens.textMediumContrast,
            )),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 11,
            )),
          ),
        ],
      ),
    );
  }
}

// ─── Parse History Item (Real Data) ───────────────────────────────────────────

class _ParseHistoryItem extends StatelessWidget {
  final Import import_;

  const _ParseHistoryItem({required this.import_});

  @override
  Widget build(BuildContext context) {
    final isSuccess = import_.successRate > 50;
    final iconColor = isSuccess ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning;
    final dateFormatted = DateFormat('dd MMM yyyy').format(import_.createdAt);
    final confidence = import_.successRate / 100.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
             width: 40,
             height: 40,
             decoration: BoxDecoration(
               color: iconColor.withValues(alpha: 0.1),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Center(
               child: Icon(
                 _iconForImportType(import_.importType),
                 color: iconColor,
               ),
             ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      Text(import_.sourceName, style: Theme.of(context).textTheme.titleMedium),
                      Text(dateFormatted, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Row(
                   children: [
                     Text('${import_.rowsImported} records', style: Theme.of(context).textTheme.bodyMedium),
                     const Spacer(),
                     _ConfidenceBadge(confidence: confidence),
                   ],
                 )
              ],
            ),
          )
        ],
      ),
    );
  }

  IconData _iconForImportType(dynamic importType) {
    final typeStr = importType.toString().toLowerCase();
    if (typeStr.contains('email')) return Icons.mail_outline_rounded;
    if (typeStr.contains('csv')) return Icons.upload_file_rounded;
    if (typeStr.contains('manual')) return Icons.edit_rounded;
    return Icons.file_present_rounded;
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    Color color = DesignTokens.obsidianTeal;
    if (confidence < 0.8) color = DesignTokens.ashGold;
    if (confidence < 0.5) color = DesignTokens.crimsonWarning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
         color: color.withValues(alpha: 0.1),
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
           Icon(Icons.auto_awesome_rounded, size: 12, color: color),
           const SizedBox(width: 4),
           Text(
             '${(confidence * 100).toInt()}% Match',
             style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: color, fontWeight: FontWeight.w600),
           )
        ],
      ),
    );
  }
}

class _ImportActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? statusMessage;
  final VoidCallback onTap;
  final bool isScanning;
  final Animation<double>? pulseAnimation;

  const _ImportActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.statusMessage,
    this.isScanning = false,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isScanning 
            ? DesignTokens.obsidianTeal.withValues(alpha: 0.5) 
            : Colors.white.withValues(alpha: 0.05),
          width: isScanning ? 2.0 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isScanning ? DesignTokens.obsidianTeal.withValues(alpha: 0.1) : DesignTokens.graphiteBase,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isScanning ? DesignTokens.obsidianTeal : DesignTokens.textMediumContrast,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isScanning && statusMessage != null ? statusMessage! : title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isScanning)
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: DesignTokens.obsidianTeal),
            )
          else
            const Icon(Icons.chevron_right_rounded, color: DesignTokens.textMediumContrast),
        ],
      ),
    );

    if (pulseAnimation != null && isScanning) {
      return AnimatedBuilder(
        animation: pulseAnimation!,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
                  blurRadius: 20 * pulseAnimation!.value,
                  spreadRadius: 10 * pulseAnimation!.value,
                )
              ],
            ),
            child: Transform.scale(
              scale: 1.0 + (0.02 * pulseAnimation!.value),
              child: content,
            ),
          );
        },
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}
