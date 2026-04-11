// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'society_data.dart';
import 'app_theme.dart';
import 'splash_screen.dart';
import 'notification_service.dart';
import 'update_service.dart'; // ← SIRF YEH LINE ADD HUI HAI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
    
  );

  await SocietyData.initializeRecords();
  await NotificationService.init();

  runApp(const KarimNagarApp());
}

class KarimNagarApp extends StatelessWidget {
  const KarimNagarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Karim Nagar Portal',
      theme: AppTheme.theme,
      // ── UpdateChecker wrap kiya SplashScreen ko ──
      // Bas yahi ek change hai poori app mein!
    
      home: const SplashScreen(),
    );
  }
}
