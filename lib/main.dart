import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: ExamBrowserFinal(),
    debugShowCheckedModeBanner: false,
  ));
}

class ExamBrowserFinal extends StatefulWidget {
  const ExamBrowserFinal({super.key});

  @override
  State<ExamBrowserFinal> createState() => _ExamBrowserFinalState();
}

class _ExamBrowserFinalState extends State<ExamBrowserFinal> with WidgetsBindingObserver {
  InAppWebViewController? webViewController;
  static const platform = MethodChannel('com.example.exambrowser/volume');

  Future<void> _maximizeVolume() async {
    try {
      await platform.invokeMethod('maximizeVolume');
    } catch (e) {
      debugPrint("Gagal memaksimalkan volume: $e");
    }
  }
  // ==========================================
  // KONFIGURASI APLIKASI (APP CONFIG)
  // ==========================================
  // 1. Password/PIN Otoritas Proktor untuk keluar/ganti link
  final String exitPassword = "1111";

  // 2. Judul Utama Aplikasi
  final String appTitle = "EXAM BROWSER";

  // 3. Sub-Judul Aplikasi
  final String appSubtitle = "SMART EXAM SOLUTION";

  // 4. Custom User Agent (Untuk keamanan server agar hanya menerima dari webview ini)
  // - Kosongkan "" jika ingin dinonaktifkan (menggunakan User Agent bawaan perangkat).
  final String customUserAgent = ""; 

  // 5. LINK TANAM (EMBEDDED URL)
  // - Masukkan URL server ujian CBT Anda di bawah ini (contoh: "http://192.168.1.100/").
  // - Jika dikosongkan "", aplikasi akan masuk ke mode Scan QR & Input Manual.
  final String embeddedUrl = "https://mgmp.anbk.my.id/"; 
  // ==========================================
  
  final AudioPlayer audioPlayer = AudioPlayer();
  final TextEditingController _urlController = TextEditingController();
  
  bool isUrlSet = false;
  String currentUrl = "";
  bool isLoading = true;
  bool isError = false;
  double progress = 0;
  String errorMsg = "";

  int _batteryLevel = 100;
  Timer? _batteryTimer;

  Future<void> _updateBatteryLevel() async {
    try {
      final int level = await platform.invokeMethod('getBatteryLevel');
      if (mounted) {
        setState(() {
          _batteryLevel = level;
        });
      }
    } catch (e) {
      debugPrint("Gagal mengambil level baterai: $e");
    }
  }

  IconData _getBatteryIcon(int level) {
    if (level >= 90) return Icons.battery_full_rounded;
    if (level >= 75) return Icons.battery_6_bar_rounded;
    if (level >= 50) return Icons.battery_5_bar_rounded;
    if (level >= 30) return Icons.battery_3_bar_rounded;
    if (level >= 15) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupExamEnvironment();
    _checkSavedUrl();
    
    // Pemantauan Baterai Natif
    _updateBatteryLevel();
    _batteryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateBatteryLevel();
    });
  }

  Future<void> _checkSavedUrl() async {
    if (embeddedUrl.isNotEmpty) {
      String formattedUrl = embeddedUrl.trim();
      if (!formattedUrl.startsWith('http')) {
        formattedUrl = 'https://' + formattedUrl;
      }
      setState(() {
        currentUrl = formattedUrl;
        isUrlSet = true;
        isLoading = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('exam_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      setState(() {
        currentUrl = savedUrl;
        isUrlSet = true;
      });
    }
    setState(() => isLoading = false);
  }

  Future<void> _saveAndOpenUrl(String url) async {
    if (url.isEmpty) return;
    
    setState(() => isLoading = true);

    // Auto-fix URL
    String formattedUrl = url.trim();
    if (!formattedUrl.startsWith('http')) {
      formattedUrl = 'https://' + formattedUrl;
    }

    try {
      Uri.parse(formattedUrl);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('exam_url', formattedUrl);
      
      setState(() {
        currentUrl = formattedUrl;
        isUrlSet = true;
        isLoading = true;
        isError = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        isError = true;
        errorMsg = "Format URL Tidak Valid!";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Format URL tidak valid!'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _resetUrl() async {
    if (embeddedUrl.isNotEmpty) {
      setState(() {
        currentUrl = embeddedUrl;
        isUrlSet = true;
        isLoading = true;
        isError = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('exam_url');
    setState(() {
      isUrlSet = false;
      currentUrl = "";
      isLoading = false;
    });
  }

  Future<void> _setupExamEnvironment() async {
    try {
      await WakelockPlus.enable();
      await startKioskMode();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await InAppWebViewController.clearAllCache();

      final session = await audio_session.AudioSession.instance;
      await session.configure(const audio_session.AudioSessionConfiguration(
        avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker,
        androidAudioAttributes: audio_session.AndroidAudioAttributes(
          usage: audio_session.AndroidAudioUsage.alarm,
          contentType: audio_session.AndroidAudioContentType.sonification,
        ),
      ));
    } catch (e) {
      debugPrint("Setup error: $e");
    }
  }

  @override
  void dispose() {
    _batteryTimer?.cancel(); // Bersihkan timer pemantauan baterai
    WakelockPlus.disable();
    stopKioskMode();
    audioPlayer.dispose();
    _urlController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && isUrlSet) {
      _reportViolation("Aplikasi ditinggalkan");
    }
  }

  void _reportViolation(String type) async {
    await _maximizeVolume();
    audioPlayer.play(AssetSource('alert.mp3'), volume: 1.0);
    webViewController?.evaluateJavascript(
      source: "if(typeof reportViolation === 'function') { reportViolation('app_switch'); }"
    );
  }

  void _showExitDialog({bool isReset = false}) {
    final TextEditingController _passController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isReset ? 'Reset Konfigurasi' : 'Otoritas Proktor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isReset ? 'Masukkan password untuk ganti link:' : 'Masukkan password untuk keluar:'),
            const SizedBox(height: 15),
            TextField(
              controller: _passController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'PIN Keamanan'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          ElevatedButton(
            onPressed: () {
              if (_passController.text == exitPassword) {
                Navigator.pop(context);
                if (isReset) {
                  _resetUrl();
                } else {
                  stopKioskMode().then((_) => SystemNavigator.pop());
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password Salah!')));
              }
            },
            child: Text(isReset ? 'OK' : 'KELUAR'),
          ),
        ],
      ),
    );
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text("Scan QR Link Ujian")),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  Navigator.pop(context);
                  _saveAndOpenUrl(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && !isUrlSet) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!isUrlSet) return _buildSetupScreen();
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar Navigation
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left Branding: Logo + App Title
                    Row(
                      children: [
                        Image.asset('assets/logo.png', height: 20, errorBuilder: (_,__,___) => const Icon(Icons.school, color: Colors.white, size: 18)),
                        const SizedBox(width: 8),
                        Text(appTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                      ],
                    ),
                    
                    // Right Side: Refresh -> Battery -> Clock -> Exit
                    Row(
                      children: [
                        // 1. Refresh Button
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                          tooltip: "Segarkan Halaman",
                          onPressed: () {
                            webViewController?.reload();
                          },
                        ),
                        const SizedBox(width: 5),
                        
                        // 2. Battery Status
                        Row(
                          children: [
                            Icon(_getBatteryIcon(_batteryLevel), color: _batteryLevel <= 20 ? Colors.redAccent : Colors.white70, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              "$_batteryLevel%",
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        const SizedBox(width: 15),

                        // 3. Clock: Phone Digital Time (Optimized to 30s)
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 30)),
                          builder: (context, snapshot) {
                            final now = DateTime.now();
                            return Text(
                              "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                            );
                          },
                        ),
                        const SizedBox(width: 5),

                        // 4. Exit Button: Exit (Power / Off icon)
                        IconButton(
                          icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 22),
                          onPressed: () => _showExitDialog(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isLoading || progress < 1.0)
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: Colors.grey[900],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
                ),
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(currentUrl)),
                      initialSettings: InAppWebViewSettings(
                        userAgent: customUserAgent.isNotEmpty ? customUserAgent : null,
                        useShouldOverrideUrlLoading: true,
                        mediaPlaybackRequiresUserGesture: false,
                        allowsInlineMediaPlayback: true,
                        cacheEnabled: false,
                        clearCache: true,
                        overScrollMode: OverScrollMode.NEVER,
                      ),
                      onWebViewCreated: (controller) => webViewController = controller,
                      onProgressChanged: (controller, p) {
                        setState(() {
                          progress = p / 100;
                          if (progress == 1.0) isLoading = false;
                        });
                      },
                      onLoadError: (controller, url, code, message) {
                        setState(() {
                          isError = true;
                          errorMsg = "Gagal memuat halaman ujian.";
                        });
                      },
                    ),
                    if (isError) _buildErrorView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white24, size: 28),
                  onPressed: _showExitDialog,
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(color: Colors.indigo.withOpacity(0.2), blurRadius: 25, spreadRadius: 4)
                          ]
                        ),
                        child: Image.asset('assets/logo.png', height: 80, errorBuilder: (_,__,___) => const Icon(Icons.school, size: 80, color: Colors.white)),
                      ),
                      const SizedBox(height: 20),
                      Text(appTitle, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text(appSubtitle, style: const TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            const Text("KONFIGURASI UJIAN", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _openScanner,
                                icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                                label: const Text("SCAN QR CODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigoAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 10,
                                  shadowColor: Colors.indigoAccent.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text("ATAU", style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                              ],
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: _urlController,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: "Ketik Link Ujian Manual...",
                                hintStyle: const TextStyle(color: Colors.white24, fontWeight: FontWeight.normal),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.3),
                                prefixIcon: const Icon(Icons.link, color: Colors.white30),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigoAccent, width: 2)),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.send_rounded, color: Colors.indigoAccent),
                                  onPressed: () => _saveAndOpenUrl(_urlController.text),
                                ),
                              ),
                              onSubmitted: (val) => _saveAndOpenUrl(val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                            SizedBox(width: 10),
                            Text(
                              "Pastikan Internet & Baterai Stabil",
                              style: TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text("Gagal Memuat Halaman", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(currentUrl, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => setState(() => isError = false),
              child: const Text("Coba Lagi"),
            ),
            if (embeddedUrl.isEmpty)
              TextButton(
                onPressed: () => _showExitDialog(isReset: true),
                child: const Text("Ganti Link", style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
