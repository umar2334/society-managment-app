// lib/main.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'society_data.dart';
import 'app_theme.dart';
import 'splash_screen.dart';
import 'notification_service.dart';
import 'update_service.dart';

// ── FCM Background Handler (top-level function zaroor chahiye) ──
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Background mein kuch extra nahi karna — system notification automatic show hogi
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FCM background handler register karo
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  await SocietyData.initializeRecords();
  await NotificationService.init();
  await NotificationService.setupFCM();

  // Notification tap se app khuli? → update dialog dikhao
  FirebaseMessaging.instance
      .getInitialMessage()
      .then((RemoteMessage? msg) {
    if (msg?.data['type'] == 'app_update') {
      _handleUpdateTap();
    }
  });

  // App background mein thi, notification tap ki
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
    if (msg.data['type'] == 'app_update') {
      _handleUpdateTap();
    }
  });

  runApp(KarimNagarApp());
}

Future<void> _handleUpdateTap() async {
  final data = await UpdateService.checkForUpdate();
  if (data == null) return;
  final ctx = navigatorKey.currentContext;
  if (ctx != null) showUpdateDialog(ctx, data);
}

class KarimNagarApp extends StatelessWidget {
  const KarimNagarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Karim Nagar Portal',
      theme: AppTheme.theme,
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
    );
  }
}
