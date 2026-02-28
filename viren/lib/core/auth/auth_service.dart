import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'oauth_platform_resolver.dart';
import 'token_vault.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthService — Orchestrates platform-aware Google OAuth flow.
//
// CRITICAL RULES:
// 1. Tokens are BOUND to (clientId, platform, scopes, time).
//    Change ANY ONE → old tokens must be nuked.
// 2. disconnect() MUST call GoogleSignIn.disconnect(), not just signOut().
// 3. After auth, ALWAYS verify scopes include gmail.readonly.
// 4. Never silently reuse tokens that might be from a dead client.
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  final TokenVault _vault;
  final List<String> _scopes;

  AuthService._(this._vault, this._scopes);

  static Future<AuthService> create({required List<String> scopes}) async {
    final vault = await TokenVault.create();
    return AuthService._(vault, scopes);
  }

  /// Attempts to get valid credentials. If cached tokens are stale/invalid,
  /// nukes them and forces a fresh interactive consent flow.
  Future<AccessCredentials> authenticate() async {
    // 1. Check if we have cached tokens
    final existingToken = await _vault.getAccessToken();
    final refreshToken = await _vault.getRefreshToken();
    final expiryDate = await _vault.getTokenExpiry();

    if (existingToken != null && expiryDate != null) {
      final creds = AccessCredentials(
        AccessToken('Bearer', existingToken, expiryDate),
        refreshToken,
        _scopes,
      );

      // If NOT expired, verify the token actually works before returning
      if (!creds.accessToken.hasExpired) {
        final valid = await _verifyToken(existingToken);
        if (valid) return creds;
        // Token is invalid (wrong client, revoked, etc) — nuke everything
        await nukeAllTokens();
      } else if (creds.refreshToken != null) {
        // Expired — try refresh
        try {
          final refreshed = await _refreshTokens(creds);
          return refreshed;
        } catch (_) {
          // Refresh failed — nuke and re-auth
          await nukeAllTokens();
        }
      } else {
        // Expired and no refresh token — nuke
        await nukeAllTokens();
      }
    }

    // 2. Interactive auth (forced fresh consent)
    final config = OAuthPlatformResolver.resolve();

    if (config.useExternalBrowserFlow) {
      return await _authenticateDesktop(config);
    } else {
      return await _authenticateMobile(config);
    }
  }

  /// Verifies an access token is actually valid by hitting Google's tokeninfo.
  /// Returns false if the token is invalid, expired, or lacks gmail scopes.
  Future<bool> _verifyToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=$token'),
      );
      if (response.statusCode != 200) return false;

      // Check that gmail scope is present
      final body = response.body.toLowerCase();
      if (!body.contains('gmail')) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Desktop (Linux/Windows/macOS) Flow ───────────────────────────────────

  Future<AccessCredentials> _authenticateDesktop(OAuthConfig config) async {
    final clientId = ClientId(config.clientId, config.clientSecret ?? '');
    final client = http.Client();

    try {
      final credentials = await obtainAccessCredentialsViaUserConsent(
        clientId,
        _scopes,
        client,
        _launchBrowserPrompt,
      );

      await _vault.saveTokens(
        accessToken: credentials.accessToken.data,
        refreshToken: credentials.refreshToken,
        expiry: credentials.accessToken.expiry,
      );

      return credentials;
    } finally {
      client.close();
    }
  }

  void _launchBrowserPrompt(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch browser for OAuth: $url');
    }
  }

  // ── Mobile (Android/iOS) Flow — google_sign_in v7 singleton API ──────────

  Future<AccessCredentials> _authenticateMobile(OAuthConfig config) async {
    // Initialize the singleton with platform-correct client IDs
    await GoogleSignIn.instance.initialize(
      clientId: config.clientId.isNotEmpty ? config.clientId : null,
      serverClientId: config.serverClientId,
    );

    // CRITICAL: Do NOT use attemptLightweightAuthentication first.
    // After client ID changes, lightweight auth returns stale tokens.
    // Always force a full interactive auth to ensure fresh scopes.
    GoogleSignInAccount? account;
    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: [gmail.GmailApi.gmailReadonlyScope],
      );
    } catch (e) {
      // If auth fails, it might be stale state — nuke and retry once
      await _nukeMobileSession();
      try {
        account = await GoogleSignIn.instance.authenticate(
          scopeHint: [gmail.GmailApi.gmailReadonlyScope],
        );
      } catch (e2) {
        throw Exception(
          'Google Sign-In failed. Error: $e2\n'
          'Please ensure your Google account is set up correctly.',
        );
      }
    }

    // Get authorization headers for Gmail readonly scope
    final authHeaders = await account.authorizationClient.authorizationHeaders(
      [gmail.GmailApi.gmailReadonlyScope],
      promptIfNecessary: true,
    );

    // Extract access token from headers  
    final authValue = authHeaders?['Authorization'] ?? '';
    final accessToken = authValue.replaceFirst('Bearer ', '');

    if (accessToken.isEmpty) {
      throw Exception(
        'Failed to obtain access token. '
        'Gmail read permission was not granted.',
      );
    }

    // Verify the token actually has gmail scope
    final valid = await _verifyToken(accessToken);
    if (!valid) {
      await nukeAllTokens();
      throw Exception(
        'Token obtained but does not include Gmail permissions. '
        'Please sign in again and grant Gmail access.',
      );
    }

    // google_sign_in dynamically refreshes via Play Services;
    // we set a 1-hour window to match the interface.
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));

    await _vault.saveTokens(
      accessToken: accessToken,
      refreshToken: null,
      expiry: expiry,
    );

    return AccessCredentials(
      AccessToken('Bearer', accessToken, expiry),
      null,
      _scopes,
    );
  }

  // ── Token Refresh (For Desktop Flow) ─────────────────────────────────────

  Future<AccessCredentials> _refreshTokens(AccessCredentials credentials) async {
    final config = OAuthPlatformResolver.resolve();
    final clientId = ClientId(config.clientId, config.clientSecret ?? '');
    final client = http.Client();

    try {
      final refreshed = await refreshCredentials(clientId, credentials, client);
      await _vault.saveTokens(
        accessToken: refreshed.accessToken.data,
        refreshToken: refreshed.refreshToken ?? credentials.refreshToken,
        expiry: refreshed.accessToken.expiry,
      );
      return refreshed;
    } catch (e) {
      throw Exception('Session expired and token refresh failed: $e');
    } finally {
      client.close();
    }
  }

  // ── Token Nuking (THE NUCLEAR OPTION) ────────────────────────────────────

  /// Destroys ALL cached tokens — vault, Google Play Services, everything.
  /// Call this when tokens are stale, mismatched, or from a dead client ID.
  Future<void> nukeAllTokens() async {
    // 1. Clear vault (access + refresh + expiry)
    await _vault.clearTokens();

    // 2. Clear Google Sign-In cache on mobile
    await _nukeMobileSession();
  }

  /// Destroys the mobile Google Sign-In session completely.
  Future<void> _nukeMobileSession() async {
    try {
      // signOut() removes cached account only
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      // disconnect() revokes all grants — THIS IS THE CRITICAL ONE
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}
  }

  /// Public disconnect method for UI use.
  Future<void> disconnect() async {
    await nukeAllTokens();
  }
}
