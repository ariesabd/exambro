import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'lock_screen.dart';

class ExamScreen extends StatefulWidget {
  final String examUrl;

  const ExamScreen({Key? key, required this.examUrl}) : super(key: key);

  @override
  _ExamScreenState createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  InAppWebViewController? _webViewController;
  double _progress = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Menjaga layar agar tetap menyala selama ujian
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    // Mematikan wakelock saat keluar dari halaman ujian
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _exitExam() async {
    // Menampilkan halaman verifikasi PIN Proktor untuk bisa keluar dari ujian
    final bool? unlocked = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LockScreen(
          onUnlocked: () {
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );

    if (unlocked == true) {
      // Jika PIN benar, keluar dari halaman ujian kembali ke halaman utama
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mencegah tombol back bawaan HP agar tidak bisa langsung keluar dari ujian
    return WillPopScope(
      onWillPop: () async {
        if (_webViewController != null && await _webViewController!.canGoBack()) {
          // Jika webview memiliki history mundur, biarkan mundur di web
          _webViewController!.goBack();
          return false;
        } else {
          // Jika di halaman pertama web, minta PIN Proktor untuk keluar
          _exitExam();
          return false;
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0E17),
        appBar: AppBar(
          backgroundColor: const Color(0xFF141221),
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () async {
              if (_webViewController != null && await _webViewController!.canGoBack()) {
                _webViewController!.goBack();
              }
            },
          ),
          title: Text(
            widget.examUrl.replaceAll('https://', '').replaceAll('http://', ''),
            style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
          actions: [
            // Tombol Refresh
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _webViewController?.reload();
              },
            ),
            // Tombol Exit/Power (Merah) yang membutuhkan PIN Proktor
            IconButton(
              icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
              onPressed: _exitExam,
            ),
          ],
        ),
        body: Column(
          children: [
            // Bar Progress Loading
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress,
                color: const Color(0xFF10B981),
                backgroundColor: const Color(0xFF1E1B29),
                minHeight: 3.5,
              ),
            
            // WebView Ujian
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.examUrl)),
                initialSettings: InAppWebViewSettings(
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                  javaScriptEnabled: true,
                  supportMultipleWindows: false,
                  safeBrowsingEnabled: true,
                  disableDefaultErrorPage: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _isLoading = true;
                  });
                },
                onLoadStop: (controller, url) {
                  setState(() {
                    _isLoading = false;
                  });
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100;
                    if (progress == 100) {
                      _isLoading = false;
                    }
                  });
                },
                onReceivedError: (controller, request, error) {
                  // Jika koneksi internet mati atau alamat tidak ditemukan
                  setState(() {
                    _isLoading = false;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
