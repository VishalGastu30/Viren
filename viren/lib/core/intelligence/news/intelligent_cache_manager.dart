import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheEntry {
  final String assetClass;
  final String content;
  final DateTime timestamp;

  CacheEntry({
    required this.assetClass,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'assetClass': assetClass,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      assetClass: json['assetClass'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class IntelligentCacheManager {
  static const String _fileName = 'viren_intelligence_cache.json';
  static Map<String, CacheEntry>? _memoryCache;
  static bool _initialised = false;

  /// Get the currently active cache, observing strict context-aware TTL rules.
  static Future<String?> getCachedContext(String cacheKey) async {
    await _ensureInitialised();

    final entry = _memoryCache![cacheKey];
    if (entry == null) return null;

    final now = DateTime.now();
    final age = now.difference(entry.timestamp);

    // Context-Aware TTL logic
    bool isMarketHours = _isIndianMarketOpen(now) || _isIndianMarketOpen(entry.timestamp);
    
    // Macro news has a longer shelf life
    if (cacheKey.startsWith('macro_india')) {
      if (age.inHours < 24) return entry.content;
      return null;
    }

    if (isMarketHours) {
      // 15 minute TTL during active market hours
      if (age.inMinutes <= 15) return entry.content;
    } else {
      // 12 hour TTL after hours or weekends
      if (age.inHours <= 12) return entry.content;
    }

    return null; // Expired
  }

  /// Save new context to both memory and disk.
  static Future<void> saveContext(String cacheKey, String content) async {
    await _ensureInitialised();
    
    _memoryCache![cacheKey] = CacheEntry(
      assetClass: cacheKey, // repurposing the existing field
      content: content,
      timestamp: DateTime.now(),
    );

    await _flushToDisk();
  }

  /// The Janitor: Runs on init to aggressively prune old data and save storage.
  static Future<void> _runJanitor() async {
    if (_memoryCache == null) return;
    
    final now = DateTime.now();
    bool needsFlush = false;

    // Remove anything older than 48 hours to prevent unbounded growth
    _memoryCache!.removeWhere((key, entry) {
      final age = now.difference(entry.timestamp);
      if (age.inHours > 48) {
        needsFlush = true;
        return true;
      }
      return false;
    });

    if (needsFlush) {
      await _flushToDisk();
    }
  }

  static Future<void> _ensureInitialised() async {
    if (_initialised) return;
    
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        
        _memoryCache = {};
        for (final entry in decoded.entries) {
          _memoryCache![entry.key] = CacheEntry.fromJson(entry.value);
        }
      } else {
        _memoryCache = {};
      }
    } catch (e) {
      // Corrupt cache or IO error — start fresh
      _memoryCache = {};
    }

    await _runJanitor();
    _initialised = true;
  }

  static Future<void> _flushToDisk() async {
    if (_memoryCache == null) return;
    try {
      final file = await _getFile();
      final Map<String, dynamic> toSave = {};
      for (final entry in _memoryCache!.entries) {
        toSave[entry.key] = entry.value.toJson();
      }
      await file.writeAsString(jsonEncode(toSave));
    } catch (_) {
      // Fail silently on disk write error, memory cache will still work
    }
  }

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Determines if the Indian stock market is currently open.
  /// Standard hours are Monday-Friday, 9:15 AM to 3:30 PM IST.
  static bool _isIndianMarketOpen(DateTime time) {
    // Note: Assuming device is in IST timezone. For absolute precision we would check UTC.
    if (time.weekday == DateTime.saturday || time.weekday == DateTime.sunday) {
      return false;
    }
    
    final int minutesSinceMidnight = time.hour * 60 + time.minute;
    final int openTime = 9 * 60 + 15; // 9:15 AM
    final int closeTime = 15 * 60 + 30; // 3:30 PM

    return minutesSinceMidnight >= openTime && minutesSinceMidnight <= closeTime;
  }
}
