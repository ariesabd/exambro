import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/overlay_warning.dart';
import 'overlay_checker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable immersive sticky mode (full-screen)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Perform overlay detection once the app is built
    WidgetsBinding.instance?.addPostFrameCallback((_) async {
      bool overlayEnabled = await isOverlayEnabled();
      if (overlayEnabled) {
        showDialog(
          context: context,
          builder: (_) => const OverlayWarningDialog(),
        );
      }
    });

    return MaterialApp(
      title: 'Exambro',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(child: Text('Exambro Home')), // placeholder, replace with actual home widget
      ),
    );
  }
}
