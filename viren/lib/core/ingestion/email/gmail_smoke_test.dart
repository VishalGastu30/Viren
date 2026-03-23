import 'dart:convert';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../../auth/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Gmail Smoke Test — PROOF MODE
//
// This exists for ONE reason:
//   "Is Gmail API reachable with the current access token?"
//
// If this fails → OAuth/scopes/token is broken.
// If this succeeds → the problem is downstream (parsing, PAN, etc).
//
// NO PAN. NO PARSING. NO ATTACHMENTS. NO DATE FILTERS.
// Just: authenticate → query → count.
// ─────────────────────────────────────────────────────────────────────────────

class GmailProofResult {
  final bool gmailReachable;
  final int messageCount;
  final String? authenticatedEmail;
  final String? tokenPrefix;   // First 8 chars of access token
  final DateTime? tokenExpiry;
  final List<String> grantedScopes;
  final String? errorMessage;
  final List<String> sampleSubjects; // First 3 subjects for proof

  const GmailProofResult({
    required this.gmailReachable,
    this.messageCount = 0,
    this.authenticatedEmail,
    this.tokenPrefix,
    this.tokenExpiry,
    this.grantedScopes = const [],
    this.errorMessage,
    this.sampleSubjects = const [],
  });

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('═══ GMAIL PROOF RESULT ═══');
    buf.writeln('Reachable: $gmailReachable');
    buf.writeln('Messages found: $messageCount');
    buf.writeln('Auth email: $authenticatedEmail');
    buf.writeln('Token prefix: $tokenPrefix');
    buf.writeln('Token expiry: $tokenExpiry');
    buf.writeln('Scopes: $grantedScopes');
    if (errorMessage != null) buf.writeln('ERROR: $errorMessage');
    if (sampleSubjects.isNotEmpty) {
      buf.writeln('Sample subjects:');
      for (final s in sampleSubjects) {
        buf.writeln('  • $s');
      }
    }
    buf.writeln('═══════════════════════════');
    return buf.toString();
  }
}

class GmailSmokeTest {
  static final _log = Logger();

  /// Runs the minimal Gmail proof test.
  ///
  /// Steps:
  ///   1. Authenticate (same path as production)
  ///   2. Log the token provenance tuple
  ///   3. Verify token via tokeninfo endpoint
  ///   4. Query Gmail with ONLY sender filter (no dates, no attachments)
  ///   5. Count results
  ///   6. Fetch first 3 subjects as proof
  static Future<GmailProofResult> run(AuthService authService) async {
    _log.i('──── GMAIL SMOKE TEST START ────');

    // ── STEP 1: AUTHENTICATE ──
    AccessCredentials credentials;
    try {
      credentials = await authService.authenticate();
      _log.i('✓ Authentication succeeded');
    } catch (e) {
      _log.e('✗ Authentication FAILED: $e');
      return GmailProofResult(
        gmailReachable: false,
        errorMessage: 'Authentication failed: $e',
      );
    }

    final accessToken = credentials.accessToken.data;
    final tokenPrefix = accessToken.length > 8
        ? accessToken.substring(0, 8)
        : accessToken;
    final tokenExpiry = credentials.accessToken.expiry;

    _log.i('Token prefix: $tokenPrefix...');
    _log.i('Token expiry: $tokenExpiry');
    _log.i('Token expired? ${credentials.accessToken.hasExpired}');
    _log.i('Credential scopes: ${credentials.scopes}');

    // ── STEP 2: VERIFY TOKEN VIA TOKENINFO ──
    List<String> grantedScopes = [];
    String? authenticatedEmail;
    try {
      final tokenInfoResp = await http.get(
        Uri.parse(
            'https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=$accessToken'),
      );
      _log.i('tokeninfo status: ${tokenInfoResp.statusCode}');
      _log.i('tokeninfo body: ${tokenInfoResp.body}');

      if (tokenInfoResp.statusCode == 200) {
        final info = json.decode(tokenInfoResp.body) as Map<String, dynamic>;
        authenticatedEmail = info['email'] as String?;
        final scopeStr = info['scope'] as String? ?? '';
        grantedScopes = scopeStr.split(' ').where((s) => s.isNotEmpty).toList();

        _log.i('Authenticated email: $authenticatedEmail');
        _log.i('Granted scopes: $grantedScopes');

        // Check for gmail scope
        final hasGmailScope = grantedScopes.any(
            (s) => s.contains('gmail'));
        if (!hasGmailScope) {
          _log.e('✗ Token does NOT include any Gmail scope!');
          return GmailProofResult(
            gmailReachable: false,
            authenticatedEmail: authenticatedEmail,
            tokenPrefix: tokenPrefix,
            tokenExpiry: tokenExpiry,
            grantedScopes: grantedScopes,
            errorMessage:
              'Token is valid but does NOT include Gmail scopes. '
              'Granted: $grantedScopes. '
              'You must re-authenticate with gmail.readonly.',
          );
        }
        _log.i('✓ Gmail scope confirmed');
      } else {
        _log.e('✗ tokeninfo rejected: ${tokenInfoResp.statusCode}');
        return GmailProofResult(
          gmailReachable: false,
          tokenPrefix: tokenPrefix,
          tokenExpiry: tokenExpiry,
          errorMessage:
            'Token rejected by Google (HTTP ${tokenInfoResp.statusCode}). '
            'Token is invalid, expired, or from a dead client ID.',
        );
      }
    } catch (e) {
      _log.w('tokeninfo check failed: $e (proceeding anyway)');
    }

    // ── STEP 3: MAKE THE ONE GMAIL QUERY ──
    final authClient = authenticatedClient(http.Client(), credentials);
    try {
      final gmailApi = gmail.GmailApi(authClient);

      // THE query — just senders, nothing else
      const q = 'from:digidocemail@sbicapsec.com filename:CNB';

      _log.i('Querying Gmail: q="$q"');

      final response = await gmailApi.users.messages.list('me', q: q, maxResults: 10);
      final messages = response.messages ?? [];
      final totalEstimate = response.resultSizeEstimate ?? messages.length;

      _log.i('✓ Gmail API responded');
      _log.i('Messages returned: ${messages.length}');
      _log.i('Total estimate: $totalEstimate');

      if (messages.isEmpty) {
        _log.w('Gmail returned 0 messages for broker senders.');
        _log.w('This means either:');
        _log.w('  a) This Gmail account ($authenticatedEmail) has NO emails from these senders');
        _log.w('  b) Wrong Google account is authenticated');
        return GmailProofResult(
          gmailReachable: true,
          messageCount: 0,
          authenticatedEmail: authenticatedEmail,
          tokenPrefix: tokenPrefix,
          tokenExpiry: tokenExpiry,
          grantedScopes: grantedScopes,
          errorMessage:
            'Gmail is reachable but returned 0 broker emails. '
            'Authenticated as: $authenticatedEmail. '
            'Are you sure THIS account receives broker mail?',
        );
      }

      // ── STEP 4: FETCH FIRST 3 SUBJECTS AS PROOF ──
      final sampleSubjects = <String>[];
      for (final msg in messages.take(3)) {
        if (msg.id == null) continue;
        try {
          final full = await gmailApi.users.messages.get(
            'me', msg.id!,
            format: 'metadata',
            metadataHeaders: ['Subject', 'From', 'Date'],
          );
          final headers = full.payload?.headers ?? [];
          final subject = headers
              .firstWhere((h) => h.name?.toLowerCase() == 'subject',
                  orElse: () => gmail.MessagePartHeader())
              .value ?? '(no subject)';
          final from = headers
              .firstWhere((h) => h.name?.toLowerCase() == 'from',
                  orElse: () => gmail.MessagePartHeader())
              .value ?? '(unknown)';
          final date = headers
              .firstWhere((h) => h.name?.toLowerCase() == 'date',
                  orElse: () => gmail.MessagePartHeader())
              .value ?? '(no date)';
          sampleSubjects.add('[$date] $from: $subject');
        } catch (e) {
          sampleSubjects.add('(failed to fetch: $e)');
        }
      }

      _log.i('✓ GMAIL PROOF PASSED');
      for (final s in sampleSubjects) {
        _log.i('  Sample: $s');
      }

      return GmailProofResult(
        gmailReachable: true,
        messageCount: totalEstimate,
        authenticatedEmail: authenticatedEmail,
        tokenPrefix: tokenPrefix,
        tokenExpiry: tokenExpiry,
        grantedScopes: grantedScopes,
        sampleSubjects: sampleSubjects,
      );
    } catch (e) {
      _log.e('✗ Gmail API call FAILED: $e');
      return GmailProofResult(
        gmailReachable: false,
        authenticatedEmail: authenticatedEmail,
        tokenPrefix: tokenPrefix,
        tokenExpiry: tokenExpiry,
        grantedScopes: grantedScopes,
        errorMessage: 'Gmail API call failed: $e',
      );
    } finally {
      authClient.close();
    }
  }
}
