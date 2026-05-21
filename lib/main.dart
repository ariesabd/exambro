import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/security_service.dart';
import 'services/audio_service.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Mengaktifkan mode Immersive Sticky (Layar penuh menyembunyikan status/navigation bar)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  // Mengaktifkan fitur Anti-Screenshot & Screen Recording
  await SecurityService.preventScreenshots();

  // Inisialisasi Audio Player untuk alarm
  AudioService.init();

  // Memeriksa status kunci persisten (untuk mencegah bypass force close)
  bool startLocked = await SecurityService.isAppLocked();

  runApp(MyApp(startLocked: startLocked));
}

class MyApp extends StatefulWidget {
  final bool startLocked;

  const MyApp({Key? key, required this.startLocked}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isLockScreenShowing = false;

  @override
  void initState() {
    super.initState();
    // Daftarkan observer untuk siklus hidup (lifecycle) aplikasi
    WidgetsBinding.instance.addObserver(this);
    
    // Jika dari session sebelumnya berstatus terkunci, tandai bahwa LockScreen aktif
    if (widget.startLocked) {
      _isLockScreenShowing = true;
    }
  }

  @override
  void dispose() {
    // Bersihkan observer dan audio player saat aplikasi ditutup
    WidgetsBinding.instance.removeObserver(this);
    AudioService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    print("Lifecycle State Changed: $state");

    // DETEKSI PELANGGARAN:
    // Jika aplikasi kehilangan fokus (menarik status bar, menekan quick ball, berpindah aplikasi)
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Tandai aplikasi berstatus TERKUNCI secara persisten
      await SecurityService.lockApp();
    }

    // PENANGANAN SAAT KEMBALI AKTIF:
    if (state == AppLifecycleState.resumed) {
      // Pastikan mode layar penuh tetap menyala
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      
      bool isLocked = await SecurityService.isAppLocked();
      if (isLocked && !_isLockScreenShowing) {
        _isLockScreenShowing = true;
        
        // Tampilkan halaman kunci proktor
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/lock'),
            builder: (context) => LockScreen(
              onUnlocked: () {
                _isLockScreenShowing = false;
                _navigatorKey.currentState?.pop();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exambro',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6C5DD3),
        fontFamily: 'Outfit',
      ),
      // Jika terdeteksi status terkunci saat startup, langsung buka LockScreen. 
      // Jika aman, buka HomeScreen.
      home: widget.startLocked
          ? LockScreen(
              onUnlocked: () {
                setState(() {
                  _isLockScreenShowing = false;
                });
                _navigatorKey.currentState?.pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            )
          : const HomeScreen(),
    );
  }
}
