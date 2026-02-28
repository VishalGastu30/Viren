import 'dart:io';

/// Defines the configuration for a given platform's OAuth setup.
class OAuthConfig {
  final String clientId;
  final String? clientSecret;
  final String? serverClientId;
  final bool useExternalBrowserFlow;

  const OAuthConfig({
    required this.clientId,
    this.clientSecret,
    this.serverClientId,
    required this.useExternalBrowserFlow,
  });
}

/// A service to automatically resolve the correct OAuth configuration
/// based on the runtime platform.
///
/// Platform-bound identity resolution:
///   • Desktop (Linux/macOS/Windows) → Desktop OAuth Client ID + secret + loopback
///   • Android → serverClientId required for google_sign_in v7
///   • iOS → clientId or serverClientId from GoogleService-Info.plist
///
/// No manual switching required — fully automatic and deterministic.
class OAuthPlatformResolver {
  // ── Desktop OAuth Client (type: "Desktop application") ─────────────────
  static const String desktopClientId =
      '368117347061-s1nat2d06kee6lcl7pqrnaj84lgei5c8.apps.googleusercontent.com';
  static const String desktopClientSecret = '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';

  // ── Android OAuth Client (type: "Android") ─────────────────────────────
  // Validates package name and SHA-1 signature.
  static const String androidClientId =
      '368117347061-sulnrgnk56othc1o30u8ve2iq11ar34j.apps.googleusercontent.com';

  // ── Server OAuth Client (type: "Web application") ──────────────────────
  // REQUIRED for google_sign_in v7 on Android. Used strictly for minting ID tokens.
  static const String androidServerClientId =
      '368117347061-00ek77b8pel8kse284v2qkpvncla03b9.apps.googleusercontent.com';

  // ── iOS ────────────────────────────────────────────────────────────────
  static const String iosClientId = '';

  /// Resolves the correct OAuth configuration for the current platform.
  static OAuthConfig resolve() {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return const OAuthConfig(
        clientId: desktopClientId,
        clientSecret: desktopClientSecret,
        useExternalBrowserFlow: true,
      );
    } else if (Platform.isAndroid) {
      return const OAuthConfig(
        clientId: androidClientId, 
        serverClientId: androidServerClientId,
        useExternalBrowserFlow: false,
      );
    } else if (Platform.isIOS) {
      return const OAuthConfig(
        clientId: iosClientId,
        useExternalBrowserFlow: false,
      );
    }

    // Fallback
    return const OAuthConfig(
      clientId: desktopClientId,
      clientSecret: desktopClientSecret,
      useExternalBrowserFlow: true,
    );
  }
}
