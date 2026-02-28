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
// Detects the platform via OAuthPlatformResolver, executing either the
// native mobile flow (via google_sign_in v7 singleton) or the Desktop
// PKCE flow (via googleapis_auth + loopback HttpServer + external browser).
//
// Securely stores refresh/access tokens in the TokenVault (AES-256-GCM).
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  final TokenVault _vault;
  final List<String> _scopes;

  AuthService._(this._vault, this._scopes);

  static Future<AuthService> create({required List<String> scopes}) async {
    final vault = await TokenVault.create();
    return AuthService._(vault, scopes);
  }

  /// Attempts to get valid credentials silently. If none, prompts the user.
  Future<AccessCredentials> authenticate() async {
    // 1. Check if we already have valid or refreshable tokens in the Vault
    final existingToken = await _vault.getAccessToken();
    final refreshToken = await _vault.getRefreshToken();
    final expiryDate = await _vault.getTokenExpiry();

    if (existingToken != null && expiryDate != null) {
      final creds = AccessCredentials(
        AccessToken('Bearer', existingToken, expiryDate),
        refreshToken,
        _scopes,
      );

      // If expired, try to refresh
      if (creds.accessToken.hasExpired) {
        if (creds.refreshToken != null) {
          try {
            return await _refreshTokens(creds);
          } catch (_) {
            // Refresh failed — clear and fall through to interactive auth
            await _vault.clearTokens();
          }
        }
      } else {
        return creds;
      }
    }

    // 2. Perform interactive authentication based on platform
    final config = OAuthPlatformResolver.resolve();

    if (config.useExternalBrowserFlow) {
      return await _authenticateDesktop(config);
    } else {
      return await _authenticateMobile(config);
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
    // Initialize the singleton.
    // On Android: serverClientId is REQUIRED.
    // On iOS: clientId is used (from GoogleService-Info.plist if empty).
    await GoogleSignIn.instance.initialize(
      clientId: config.clientId.isNotEmpty ? config.clientId : null,
      serverClientId: config.serverClientId,
    );

    // Try silent/lightweight auth first
    GoogleSignInAccount? account;
    try {
      account = await GoogleSignIn.instance
          .attemptLightweightAuthentication();
    } catch (_) {
      // Expected to fail on first use
    }

    // Fall back to interactive auth if lightweight didn't work
    if (account == null) {
      try {
        account = await GoogleSignIn.instance.authenticate(
          scopeHint: [gmail.GmailApi.gmailReadonlyScope],
        );
      } catch (e) {
        throw Exception('Google Sign-In failed or was cancelled. Error: $e');
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
        'Failed to obtain access token from Google Sign-In. '
        'Authorization was not granted.',
      );
    }

    // google_sign_in dynamically refreshes via Play Services;
    // we set a 1-hour window to match the interface.
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));

    await _vault.saveTokens(
      accessToken: accessToken,
      refreshToken: null, // google_sign_in handles refresh internally
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

  // ── Revocation & Disconnect ──────────────────────────────────────────────

  Future<void> disconnect() async {
    await _vault.clearTokens();

    final config = OAuthPlatformResolver.resolve();
    if (!config.useExternalBrowserFlow) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Silent — sign-out failure is non-critical
      }
    }
  }
}
