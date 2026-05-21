import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _lockKey = 'exambro_app_locked';

  /// Mencegah screenshot & screen recording (FLAG_SECURE) di Android
  static Future<void> preventScreenshots() async {
    try {
      if (Platform.isAndroid) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      }
    } catch (e) {
      // Abaikan jika tidak didukung atau terjadi error saat inisialisasi awal
      print("Error preventing screenshots: $e");
    }
  }

  /// Memperbolehkan kembali screenshot (jika diperlukan)
  static Future<void> allowScreenshots() async {
    try {
      if (Platform.isAndroid) {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      }
    } catch (e) {
      print("Error allowing screenshots: $e");
    }
  }

  /// Memeriksa apakah aplikasi sedang terkunci secara persisten
  static Future<bool> isAppLocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockKey) ?? false;
  }

  /// Menandai aplikasi dalam status terkunci
  static Future<void> lockApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockKey, true);
    print("SecurityService: Aplikasi telah dikunci (status disimpan ke SharedPreferences)");
  }

  /// Membuka kunci aplikasi
  static Future<void> unlockApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockKey, false);
    print("SecurityService: Kunci aplikasi terbuka");
  }
}
