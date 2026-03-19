import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DeepLinkService — Bridges notification taps to PageView tab switching.
//
// Problem: VirenRouter uses a PageView with no named routes.
//          NotificationService fires outside the widget tree with no context.
//
// Solution: A global Riverpod notifier holds a pending DeepLinkTarget.
//           VirenRouter watches it and switches tabs when it changes.
//           NotificationService writes to it via a global ProviderContainer.
// ─────────────────────────────────────────────────────────────────────────────

class DeepLinkTarget {
  final int tab;
  final String? payload; // pre-filled message for Assistant tab

  const DeepLinkTarget({required this.tab, this.payload});
}

class DeepLinkNotifier extends Notifier<DeepLinkTarget?> {
  @override
  DeepLinkTarget? build() => null;

  void navigate(DeepLinkTarget target) => state = target;

  /// Called by VirenRouter after consuming the target so it
  /// does not re-fire on subsequent rebuilds.
  void consume() => state = null;
}

final deepLinkProvider =
    NotifierProvider<DeepLinkNotifier, DeepLinkTarget?>(
        DeepLinkNotifier.new);

// ── Tab index constants — matches _screens order in VirenRouter ──
const kTabDashboard = 0;
const kTabHoldings  = 1;
const kTabInsights  = 2;
const kTabAssistant = 3;
