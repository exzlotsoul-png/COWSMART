import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class AppSettingsState {
  final bool notificationsEnabled;
  final bool isDarkMode;
  final String language;
  final String languageCode;
  final String appVersion;

  const AppSettingsState({
    this.notificationsEnabled = true,
    this.isDarkMode = false,
    this.language = 'ไทย',
    this.languageCode = 'th',
    this.appVersion = 'v1.0.0',
  });

  AppSettingsState copyWith({
    bool? notificationsEnabled,
    bool? isDarkMode,
    String? language,
    String? languageCode,
    String? appVersion,
  }) {
    return AppSettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
      languageCode: languageCode ?? this.languageCode,
      appVersion: appVersion ?? this.appVersion,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  static const String _keyNotifications = 'app_notifications_enabled';
  static const String _keyDarkMode = 'app_dark_mode';
  static const String _keyLanguage = 'app_language_name';
  static const String _keyLanguageCode = 'app_language_code';

  @override
  AppSettingsState build() {
    _loadSettings();
    return const AppSettingsState();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = prefs.getBool(_keyNotifications) ?? true;
      final isDark = prefs.getBool(_keyDarkMode) ?? false;
      final langName = prefs.getString(_keyLanguage) ?? 'ไทย';
      final langCode = prefs.getString(_keyLanguageCode) ?? 'th';

      state = state.copyWith(
        notificationsEnabled: notifications,
        isDarkMode: isDark,
        language: langName,
        languageCode: langCode,
      );
    } catch (e) {
      debugPrint('[SETTINGS] Load error: $e');
    }
  }

  Future<void> toggleNotifications(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyNotifications, enabled);
    } catch (e) {
      debugPrint('[SETTINGS] Save notifications error: $e');
    }
  }

  Future<void> toggleDarkMode(bool enabled) async {
    state = state.copyWith(isDarkMode: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDarkMode, enabled);
    } catch (e) {
      debugPrint('[SETTINGS] Save dark mode error: $e');
    }
  }

  Future<void> setLanguage(String name, String code) async {
    state = state.copyWith(language: name, languageCode: code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLanguage, name);
      await prefs.setString(_keyLanguageCode, code);
    } catch (e) {
      debugPrint('[SETTINGS] Save language error: $e');
    }
  }

  Future<double> clearCache() async {
    double freedMb = 0.0;
    try {
      // 1. Clear image cache from memory
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // 2. Clear temp dir files
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        int totalBytes = 0;
        final entities = tempDir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            try {
              totalBytes += entity.lengthSync();
              entity.deleteSync();
            } catch (_) {}
          }
        }
        freedMb = totalBytes / (1024 * 1024);
      }
    } catch (e) {
      debugPrint('[SETTINGS] Clear cache error: $e');
    }
    return freedMb;
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsState>(() {
  return AppSettingsNotifier();
});
