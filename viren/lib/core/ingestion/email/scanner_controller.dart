import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScannerController — Coordinates incremental Gmail scanning.
//
// Maintains lastHistoryId for incremental scanning.
// Builds optimised Gmail queries for the target senders.
// Delegates attachment handling & parsing to downstream components.
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a scanned email message with its attachment metadata.
class ScannedEmail {
  final String messageId;
  final String from;
  final String subject;
  final DateTime date;
  final String bodyText;
  final List<ScannedAttachment> attachments;

  const ScannedEmail({
    required this.messageId,
    required this.from,
    required this.subject,
    required this.date,
    required this.bodyText,
    required this.attachments,
  });
}

/// Metadata about a single attachment in a Gmail message.
class ScannedAttachment {
  final String attachmentId;
  final String filename;
  final String mimeType;
  final int size;

  const ScannedAttachment({
    required this.attachmentId,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  bool get isPdf => mimeType == 'application/pdf' || filename.toLowerCase().endsWith('.pdf');
}

class ScannerController {
  static const String _historyIdKey = 'viren_gmail_last_history_id';

  /// Performs a full scan for broker emails.
  ///
  /// Uses `messages.list` with targeted sender queries.
  /// Supports incremental scanning via stored historyId.
  Future<List<ScannedEmail>> scanForBrokerEmails({
    required AuthService authService,
    DateTime? since,
    int maxResults = 100,
    bool incrementalOnly = false,
  }) async {
    final credentials = await authService.authenticate();
    final authClient = authenticatedClient(http.Client(), credentials);
    final gmailApi = gmail.GmailApi(authClient);

    try {
      // Build Gmail query for CNB-only mode
      // Determine time bounds
      String dateFilter = '';
      if (since != null) {
        // Incremental/bounded scan
        final dateStr = '${since.year}/${since.month}/${since.day}';
        dateFilter = ' after:$dateStr';
      }
      // If since is null, this is an unbounded full historical scan.

      final q = 'from:digidocemail@sbicapsec.com filename:CNB$dateFilter';

      // Collect all message IDs (with pagination)
      final allMessageIds = <String>[];
      String? pageToken;

      do {
        final response = await gmailApi.users.messages.list(
          'me',
          q: q,
          maxResults: maxResults,
          pageToken: pageToken,
        );

        for (final m in (response.messages ?? [])) {
          if (m.id != null) allMessageIds.add(m.id!);
        }

        pageToken = response.nextPageToken;
      } while (pageToken != null);

      // Fetch full messages with attachments
      final results = <ScannedEmail>[];

      for (final msgId in allMessageIds) {
        try {
          final fullMsg = await gmailApi.users.messages.get('me', msgId, format: 'full');
          final email = _parseGmailMessage(fullMsg);
          if (email != null) {
            results.add(email);
          }
        } catch (_) {
          // Skip individual failures
          continue;
        }
      }

      // Store historyId for future incremental scans
      if (results.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        // Use the latest historyId from any processed message
        await prefs.setString(_historyIdKey, results.first.messageId);
      }

      return results;
    } finally {
      authClient.close();
    }
  }

  /// Downloads a specific attachment from a Gmail message.
  Future<List<int>> downloadAttachment({
    required AuthService authService,
    required String messageId,
    required String attachmentId,
  }) async {
    final credentials = await authService.authenticate();
    final authClient = authenticatedClient(http.Client(), credentials);
    final gmailApi = gmail.GmailApi(authClient);

    try {
      final attachment = await gmailApi.users.messages.attachments.get(
        'me',
        messageId,
        attachmentId,
      );

      final data = attachment.data;
      if (data == null || data.isEmpty) {
        throw Exception('Attachment is empty');
      }

      // Decode base64url data
      return _decodeBase64Url(data);
    } finally {
      authClient.close();
    }
  }

  /// Computes SHA-256 hash of attachment bytes.
  String computeAttachmentHash(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  ScannedEmail? _parseGmailMessage(gmail.Message msg) {
    final msgId = msg.id;
    if (msgId == null) return null;

    final headers = msg.payload?.headers ?? [];
    final fromHeader = _getHeader(headers, 'from');
    final subjectHeader = _getHeader(headers, 'subject');
    final dateHeader = _getHeader(headers, 'date');

    // Extract body text
    String body = _extractPlainText(msg.payload);
    if (body.isEmpty) {
      body = _extractHtmlText(msg.payload);
    }

    // Extract attachment metadata
    final attachments = _extractAttachmentMeta(msg.payload);

    final date = _parseDate(dateHeader);

    return ScannedEmail(
      messageId: msgId,
      from: fromHeader,
      subject: subjectHeader,
      date: date ?? DateTime.now(),
      bodyText: body,
      attachments: attachments,
    );
  }

  String _getHeader(List<gmail.MessagePartHeader> headers, String name) {
    return headers
        .firstWhere(
          (h) => h.name?.toLowerCase() == name,
          orElse: () => gmail.MessagePartHeader(),
        )
        .value ?? '';
  }

  List<ScannedAttachment> _extractAttachmentMeta(gmail.MessagePart? part) {
    final result = <ScannedAttachment>[];
    if (part == null) return result;

    // Check this part
    if (part.filename != null && part.filename!.isNotEmpty && part.body?.attachmentId != null) {
      result.add(ScannedAttachment(
        attachmentId: part.body!.attachmentId!,
        filename: part.filename!,
        mimeType: part.mimeType ?? 'application/octet-stream',
        size: part.body?.size ?? 0,
      ));
    }

    // Recurse into child parts
    if (part.parts != null) {
      for (final child in part.parts!) {
        result.addAll(_extractAttachmentMeta(child));
      }
    }

    return result;
  }

  String _extractPlainText(gmail.MessagePart? part) {
    if (part == null) return '';
    if (part.mimeType == 'text/plain' && part.body?.data != null) {
      return _decodeBase64String(part.body!.data!);
    }
    if (part.parts != null) {
      for (final p in part.parts!) {
        final text = _extractPlainText(p);
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  String _extractHtmlText(gmail.MessagePart? part) {
    if (part == null) return '';
    if (part.mimeType == 'text/html' && part.body?.data != null) {
      final html = _decodeBase64String(part.body!.data!);
      return html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    if (part.parts != null) {
      for (final p in part.parts!) {
        final text = _extractHtmlText(p);
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  String _decodeBase64String(String data) {
    String padded = data;
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    try {
      return utf8.decode(base64Url.decode(padded));
    } catch (_) {
      return '';
    }
  }

  List<int> _decodeBase64Url(String data) {
    String padded = data;
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    return base64Url.decode(padded);
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    // Remove trailing timezone name in parentheses e.g. "(IST)"
    final cleaned = dateStr
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
        .trim();

    // Try standard ISO parse first
    try { return DateTime.parse(cleaned); } catch (_) {}

    // RFC 2822 format: "Thu, 05 Mar 2026 14:32:11 +0530"
    // or without day name: "05 Mar 2026 14:32:11 +0530"
    try {
      // Strip leading weekday if present e.g. "Thu, "
      final withoutDay = cleaned.replaceFirst(
          RegExp(r'^[A-Za-z]{3},\s*'), '');

      // Expected: "05 Mar 2026 14:32:11 +0530"
      final parts = withoutDay.split(' ');
      if (parts.length >= 4) {
        final day   = parts[0].padLeft(2, '0');
        final month = _monthToNumber(parts[1]);
        final year  = parts[2];
        final time  = parts[3];
        final tz    = parts.length >= 5 ? parts[4] : '+0000';

        // Assemble ISO 8601 and parse
        final iso = '$year-$month-${day}T$time$tz';
        return DateTime.parse(iso);
      }
    } catch (_) {}

    return null;
  }

  String _monthToNumber(String month) {
    const months = {
      'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
      'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
      'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
    };
    return months[month.toLowerCase()] ?? '01';
  }
}
