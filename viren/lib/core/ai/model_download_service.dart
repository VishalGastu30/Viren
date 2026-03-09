import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelDownloadService {
  static const _modelFileName =
      'Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';
  static const _modelReadyKey = 'ai_model_ready_v4';
  static const _downloadUrl =
      'https://www.dropbox.com/scl/fi/c9k03uh30pm2fjz87gmub/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task?rlkey=akfe8cpfmc23zty3hxexzqyl0&dl=1';
  static const _minValidSize = 1500000000;

  static Future<String> getModelPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/$_modelFileName';
  }

  static Future<bool> isModelReady() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flagSet = prefs.getBool(_modelReadyKey) ?? false;
      if (!flagSet) return false;
      final path = await getModelPath();
      final file = File(path);
      if (!await file.exists()) return false;
      final size = await file.length();
      debugPrint('Model size check: $size bytes');
      return size > _minValidSize;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> modelFileExists() async {
    try {
      final path = await getModelPath();
      final file = File(path);
      if (!await file.exists()) return false;
      final size = await file.length();
      return size > _minValidSize;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markModelReady() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modelReadyKey, true);
  }

  static Future<void> clearModelReady() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modelReadyKey, false);
  }

  static Future<void> resetModelReady() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modelReadyKey, false);
  }

  static Future<void> deleteModel() async {
    try {
      final path = await getModelPath();
      final file = File(path);
      if (await file.exists()) await file.delete();
      debugPrint('Model deleted.');
    } catch (_) {}
    await clearModelReady();
  }

  static Future<bool> downloadModel({
    required void Function(double progress) onProgress,
    required void Function(String stage) onStage,
    required void Function(String speed) onSpeed,
    required void Function(String received, String total) onSize,
  }) async {
    HttpClient? httpClient;
    IOSink? sink;
    try {
      final path = await getModelPath();
      final file = File(path);

      if (await file.exists()) await file.delete();

      onStage('connecting');
      onProgress(0.0);

      httpClient = HttpClient();
      httpClient.userAgent = 'VirenApp/1.0';
      httpClient.connectionTimeout = const Duration(seconds: 30);

      final req = await httpClient.getUrl(Uri.parse(_downloadUrl));
      req.followRedirects = true;
      req.maxRedirects = 5;
      req.headers.set(HttpHeaders.acceptHeader, '*/*');

      final res = await req.close();
      debugPrint('Dropbox status: ${res.statusCode}');
      debugPrint('Content-Length: ${res.contentLength}');

      if (res.statusCode != 200) {
        debugPrint('ERROR: Bad status ${res.statusCode}');
        await res.drain();
        return false;
      }

      onStage('downloading');

      final totalBytes =
          res.contentLength > 0 ? res.contentLength : 1600000000;

      int receivedBytes = 0;
      int lastSpeedCheck = DateTime.now().millisecondsSinceEpoch;
      int bytesAtLastCheck = 0;

      sink = file.openWrite(mode: FileMode.write);

      await for (final chunk in res) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
        onProgress(progress);

        final receivedMB = receivedBytes / 1024 / 1024;
        final totalMB = totalBytes / 1024 / 1024;
        onSize(
          receivedMB >= 1024
              ? '${(receivedMB / 1024).toStringAsFixed(2)} GB'
              : '${receivedMB.toStringAsFixed(0)} MB',
          totalMB >= 1024
              ? '${(totalMB / 1024).toStringAsFixed(2)} GB'
              : '${totalMB.toStringAsFixed(0)} MB',
        );

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastSpeedCheck >= 1000) {
          final bytesDiff = receivedBytes - bytesAtLastCheck;
          final speedMBs = bytesDiff / 1024 / 1024;
          onSpeed('${speedMBs.toStringAsFixed(1)} MB/s');
          lastSpeedCheck = now;
          bytesAtLastCheck = receivedBytes;
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final finalSize = await file.length();
      debugPrint('Download complete. Final size: $finalSize bytes');

      // Only check that the file is big enough.
      // Format validation is left to MediaPipe — it will throw a clear
      // error during the diagnostic stage if the file is corrupt.
      if (finalSize < _minValidSize) {
        debugPrint('File too small: $finalSize bytes — likely a server error page.');
        return false;
      }

      return true;
    } catch (e, stack) {
      debugPrint('VIREN_DOWNLOAD_ERROR: $e');
      debugPrint('VIREN_DOWNLOAD_STACK: $stack');
      return false;
    } finally {
      await sink?.close();
      httpClient?.close();
    }
  }
}