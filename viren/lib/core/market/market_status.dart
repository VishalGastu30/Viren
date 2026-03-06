import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum MarketStatus { live, preMarket, closed }

class MarketStatusHelper {
  static MarketStatus current() {
    // Convert to IST (UTC+5:30)
    final now =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    // Weekend check
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return MarketStatus.closed;
    }
    final open = DateTime(now.year, now.month, now.day, 9, 15);
    final close = DateTime(now.year, now.month, now.day, 15, 30);
    if (now.isAfter(open) && now.isBefore(close)) {
      return MarketStatus.live;
    }
    if (now.isBefore(open)) return MarketStatus.preMarket;
    return MarketStatus.closed;
  }

  static String label(MarketStatus status) {
    switch (status) {
      case MarketStatus.live:
        return 'LIVE';
      case MarketStatus.preMarket:
        return 'PRE-MARKET';
      case MarketStatus.closed:
        return 'MARKET CLOSED';
    }
  }

  static Color color(MarketStatus status) {
    switch (status) {
      case MarketStatus.live:
        return DesignTokens.obsidianTeal;
      case MarketStatus.preMarket:
        return DesignTokens.ashGold;
      case MarketStatus.closed:
        return DesignTokens.textMediumContrast;
    }
  }
}
