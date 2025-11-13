import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _defaultTag = 'KedairekaApp';

  static void log(String message, {String? tag, DateTime? timestamp}) {
    final finalTag = tag ?? _defaultTag;
    final finalTimestamp = timestamp ?? DateTime.now();
    final formattedTime = '${finalTimestamp.hour.toString().padLeft(2, '0')}:'
                        '${finalTimestamp.minute.toString().padLeft(2, '0')}:'
                        '${finalTimestamp.second.toString().padLeft(2, '0')}.'
                        '${finalTimestamp.millisecond.toString().padLeft(3, '0')}';

    final logMessage = '[$formattedTime] [$finalTag] $message';

    if (kDebugMode) {
      print(logMessage);
    }

    developer.log(logMessage, name: finalTag);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    final finalTag = tag ?? _defaultTag;
    final errorMessage = 'ERROR: $message';

    if (kDebugMode) {
      print('🔴 $errorMessage');
      if (error != null) {
        print('   Error details: $error');
      }
      if (stackTrace != null) {
        print('   Stack trace:');
        print('   $stackTrace');
      }
    }

    developer.log(
      errorMessage,
      name: finalTag,
      error: error,
      stackTrace: stackTrace,
      level: 1000, // Error level
    );
  }

  static void warning(String message, {String? tag}) {
    final finalTag = tag ?? _defaultTag;
    final warningMessage = 'WARNING: $message';

    if (kDebugMode) {
      print('🟡 $warningMessage');
    }

    developer.log(
      warningMessage,
      name: finalTag,
      level: 900, // Warning level
    );
  }

  static void info(String message, {String? tag}) {
    final finalTag = tag ?? _defaultTag;
    final infoMessage = 'INFO: $message';

    if (kDebugMode) {
      print('🔵 $infoMessage');
    }

    developer.log(
      infoMessage,
      name: finalTag,
      level: 800, // Info level
    );
  }

  static void debug(String message, {String? tag}) {
    final finalTag = tag ?? _defaultTag;
    final debugMessage = 'DEBUG: $message';

    if (kDebugMode) {
      print('🟢 $debugMessage');
    }

    developer.log(
      debugMessage,
      name: finalTag,
      level: 700, // Debug level
    );
  }

  static void auth(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, tag: 'AUTH');
    if (error != null) {
      AppLogger.error(message, error: error, stackTrace: stackTrace, tag: 'AUTH');
    }
  }

  static void api(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, tag: 'API');
    if (error != null) {
      AppLogger.error(message, error: error, stackTrace: stackTrace, tag: 'API');
    }
  }

  static void network(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, tag: 'NETWORK');
    if (error != null) {
      AppLogger.error(message, error: error, stackTrace: stackTrace, tag: 'NETWORK');
    }
  }

  static void bloc(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, tag: 'BLOC');
    if (error != null) {
      AppLogger.error(message, error: error, stackTrace: stackTrace, tag: 'BLOC');
    }
  }
}