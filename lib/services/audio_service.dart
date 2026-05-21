import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static AudioPlayer? _audioPlayer;

  /// Inisialisasi Audio Player
  static void init() {
    _audioPlayer ??= AudioPlayer();
  }

  /// Memutar suara alarm peringatan secara berulang (loop)
  static Future<void> playAlarm() async {
    try {
      init();
      // Pastikan sound source dihentikan dulu jika sedang berjalan
      await _audioPlayer?.stop();
      // Set Mode Loop agar suara terus berbunyi sampai dimasukkan PIN Proktor
      await _audioPlayer?.setReleaseMode(ReleaseMode.loop);
      // Putar file MP3 dari direktori assets
      await _audioPlayer?.play(AssetSource('alert.mp3'));
      print("AudioService: Alarm peringatan berbunyi!");
    } catch (e) {
      print("Error playing alarm: $e");
    }
  }

  /// Menghentikan suara alarm
  static Future<void> stopAlarm() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer?.stop();
        print("AudioService: Alarm dihentikan");
      }
    } catch (e) {
      print("Error stopping alarm: $e");
    }
  }

  /// Membersihkan memori player
  static void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}
