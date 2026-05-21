import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../services/audio_service.dart';
import '../widgets/custom_keypad.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;

  const LockScreen({Key? key, this.onUnlocked}) : super(key: key);

  @override
  _LockScreenState createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  String _pinCode = '';
  final String _correctPin = '7777';
  bool _isError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    // Memulai pemutaran suara alarm ketika layar kunci muncul
    AudioService.playAlarm();

    // Setup animasi getar (shake) untuk salah PIN
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String value) {
    if (_pinCode.length < 4) {
      setState(() {
        _isError = false;
        _pinCode += value;
      });

      // Jika sudah 4 digit, langsung verifikasi
      if (_pinCode.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDelete() {
    if (_pinCode.isNotEmpty) {
      setState(() {
        _isError = false;
        _pinCode = _pinCode.substring(0, _pinCode.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    if (_pinCode == _correctPin) {
      // Hentikan alarm
      await AudioService.stopAlarm();
      // Buka kunci secara persisten di SharedPreferences
      await SecurityService.unlockApp();
      
      if (widget.onUnlocked != null) {
        widget.onUnlocked!();
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      // PIN Salah
      setState(() {
        _isError = true;
        _pinCode = ''; // reset pin
      });
      _shakeController.forward(from: 0.0);
      
      // Berikan efek getar visual singkat
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PIN Proktor Salah! Silakan coba lagi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildDot(int index) {
    bool isActive = index < _pinCode.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: _isError
            ? Colors.redAccent
            : (isActive ? const Color(0xFF10B981) : Colors.white.withOpacity(0.2)),
        shape: BoxShape.circle,
        boxShadow: isActive && !_isError
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mencegah tombol back bawaan HP agar tidak bisa menutup layar kunci
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1E1B29),
                Color(0xFF0F0E17),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                
                // Icon Alarm / Peringatan
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gpp_bad_rounded,
                    color: Colors.redAccent,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Judul Peringatan
                const Text(
                  'APLIKASI TERKUNCI',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                
                // Sub-deskripsi
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    'Terdeteksi upaya keluar dari aplikasi ujian atau mengakses menu pintasan. Harap hubungi Proktor/Pengawas ujian untuk membuka kunci.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                      height: 1.5,
                    ),
                  ),
                ),
                
                const Spacer(),

                // Baris Titik (Dot Indicators) untuk PIN
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value * (1 - _shakeController.value), 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) => _buildDot(index)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Masukkan PIN Proktor',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
                
                const Spacer(),

                // Custom Secure Keypad
                CustomKeypad(
                  onKeyPressed: _onKeyPress,
                  onDeletePressed: _onDelete,
                  onSubmitPressed: _verifyPin,
                  showSubmit: false, // Otomatis submit pas 4 karakter
                ),
                
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
