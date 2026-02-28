import 'dart:convert';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../../auth/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmailConnector — Abstract Email Access Interface
//
// Defines the contract for email access. Strict security boundaries:
//   • Read-only — no sends, no deletes, no writes
//   • Sender-scoped — only messages matching allowed senders returned
//   • Time-bounded — only messages within the specified window
//   • No persistent storage — messages exist only in memory during processing
//
// Implementations:
//   • ImapConnector — Generic IMAP (future, requires compatible package)
//   • GmailOAuthConnector — Google Gmail API via OAuth 2.0 (Platform-Aware)
// ─────────────────────────────────────────────────────────────────────────────

/// A minimal email message — only the fields needed for trade extraction.
class EmailMessage {
  final String messageId;
  final String from;
  final String subject;
  final String body;
  final DateTime date;

  const EmailMessage({
    required this.messageId,
    required this.from,
    required this.subject,
    required this.body,
    required this.date,
  });
}

/// Auth type for email connections.
enum EmailAuthType {
  imap,
  gmailOAuth,
}

abstract class EmailConnector {
  EmailAuthType get authType;

  Future<List<EmailMessage>> fetchBrokerEmails({
    required List<String> allowedSenders,
    required DateTime since,
    int maxResults = 50,
  });

  Future<void> disconnect();
}

/// Implementation for Gmail via Google Cloud OAuth. Uses platform-aware AuthService.
class GmailOAuthConnector extends EmailConnector {
  AuthService? _authService;

  GmailOAuthConnector();

  @override
  EmailAuthType get authType => EmailAuthType.gmailOAuth;

  Future<AuthService> _getAuthService() async {
    _authService ??= await AuthService.create(
      scopes: [gmail.GmailApi.gmailReadonlyScope],
    );
    return _authService!;
  }

  @override
  Future<List<EmailMessage>> fetchBrokerEmails({
    required List<String> allowedSenders,
    required DateTime since,
    int maxResults = 50,
  }) async {
    // 1. Authenticate using the Platform-Aware Auth Service
    final authService = await _getAuthService();
    AccessCredentials credentials;
    
    try {
      credentials = await authService.authenticate();
    } catch (e) {
      throw Exception(
        'Platform-aware Google authentication failed. '
        'Error: $e',
      );
    }

    // 2. Initialize Gmail API client
    final authClient = authenticatedClient(http.Client(), credentials);
    final gmailApi = gmail.GmailApi(authClient);

    // 3. Build search query: from:(sender1 OR sender2) after:YYYY/MM/DD
    final sendersQuery = allowedSenders.map((s) => 'from:$s').join(' OR ');
    final dateStr = '${since.year}/${since.month}/${since.day}';
    final q = '($sendersQuery) after:$dateStr';

    // 4. Call messages.list
    final gmail.ListMessagesResponse response;
    try {
      response = await gmailApi.users.messages.list(
        'me',
        q: q,
        maxResults: maxResults,
      );
    } catch (e) {
      authClient.close();
      throw Exception(
        'Failed to search Gmail. '
        'This may be a network issue or expired authorization. '
        'Error: $e',
      );
    }
    
    final messagesIds = response.messages ?? [];
    final result = <EmailMessage>[];

    // 5. Fetch full content for each match
    for (final m in messagesIds) {
      final msgId = m.id;
      if (msgId == null) continue;

      try {
        final fullMsg = await gmailApi.users.messages.get('me', msgId, format: 'full');

        // Extract Headers
        final headers = fullMsg.payload?.headers ?? [];
        final fromHeader = headers.firstWhere((h) => h.name?.toLowerCase() == 'from', orElse: () => gmail.MessagePartHeader()).value ?? '';
        final subjectHeader = headers.firstWhere((h) => h.name?.toLowerCase() == 'subject', orElse: () => gmail.MessagePartHeader()).value ?? '';
        final dateHeader = headers.firstWhere((h) => h.name?.toLowerCase() == 'date', orElse: () => gmail.MessagePartHeader()).value ?? '';

        // Extract Body — try text/plain first, then text/html
        String body = _extractPlainText(fullMsg.payload);
        if (body.isEmpty) {
          body = _extractHtmlText(fullMsg.payload);
        }

        if (body.isNotEmpty) {
          result.add(EmailMessage(
            messageId: msgId,
            from: fromHeader,
            subject: subjectHeader,
            body: body,
            date: _parseRfc2822Date(dateHeader) ?? DateTime.now(),
          ));
        }
      } catch (e) {
        // Skip individual message failures — continue scanning
        continue;
      }
    }

    authClient.close();
    return result;
  }

  /// Recursively climbs the MIME tree to find text/plain
  String _extractPlainText(gmail.MessagePart? part) {
    if (part == null) return '';

    if (part.mimeType == 'text/plain' && part.body?.data != null) {
      return _decodeBase64Body(part.body!.data!);
    }

    if (part.parts != null) {
      for (final p in part.parts!) {
        final text = _extractPlainText(p);
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  /// Fallback: extract text/html and strip tags for parsing
  String _extractHtmlText(gmail.MessagePart? part) {
    if (part == null) return '';

    if (part.mimeType == 'text/html' && part.body?.data != null) {
      final html = _decodeBase64Body(part.body!.data!);
      // Simple HTML tag stripping for trade pattern matching
      return html
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    if (part.parts != null) {
      for (final p in part.parts!) {
        final text = _extractHtmlText(p);
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  /// Decodes base64url-encoded body data from Gmail API
  String _decodeBase64Body(String base64Data) {
    // Google API omits padding, so we must add it back
    String padded = base64Data;
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    try {
      return utf8.decode(base64Decode(padded));
    } catch (_) {
      return '';
    }
  }

  /// Parses date strings. Tries ISO-8601 first, then common email formats.
  DateTime? _parseRfc2822Date(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}
    // Try stripping timezone abbreviations and re-parsing
    try {
      final cleaned = dateStr.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
      return DateTime.parse(cleaned);
    } catch (_) {}
    return null;
  }

  @override
  Future<void> disconnect() async {
    final authService = await _getAuthService();
    await authService.disconnect();
  }
}

/// Placeholder IMAP connector
class ImapConnector extends EmailConnector {
  final String host;
  final int port;
  final String username;
  final String password;
  final bool useTls;

  ImapConnector({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.useTls = true,
  });

  @override
  EmailAuthType get authType => EmailAuthType.imap;

  @override
  Future<List<EmailMessage>> fetchBrokerEmails({
    required List<String> allowedSenders,
    required DateTime since,
    int maxResults = 50,
  }) async {
    throw UnimplementedError('IMAP connector deferred. Use GmailOAuthConnector.');
  }

  @override
  Future<void> disconnect() async {}
}
