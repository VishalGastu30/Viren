import 'package:flutter/services.dart';
import 'dart:io';

class MarketWatcherController {
  static const MethodChannel _channel = MethodChannel('com.viren.viren/foreground');

  static Future<void> startIfMarketOpen() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startWatcher');
    } catch (e) {
      // Ignored
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopWatcher');
    } catch (e) {
      // Ignored
    }
  }
}
