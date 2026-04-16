// lib/notification_service.dart
import 'dart:ui' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));
    _initialized = true;
  }

  // ── FCM Setup ─────────────────────────────────────────────────
  // Sab users ko society_updates topic subscribe karo
  // Yeh tab call karo jab app start ho
  static Future<void> setupFCM() async {
    final fcm = FirebaseMessaging.instance;

    // iOS/Android permissions
    await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Sab users society_updates topic subscribe karo
    await fcm.subscribeToTopic('society_updates');

    // Foreground notification channel (Android 8+)
    const channel = AndroidNotificationChannel(
      'update_channel',
      'App Updates',
      description: 'Naye update ki notifications',
      importance: Importance.max,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Foreground: FCM message aaye tou local notification dikhao
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final n = msg.notification;
      if (n == null) return;
      _plugin.show(
        9999,
        n.title ?? 'Update Available',
        n.body ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'update_channel',
            'App Updates',
            channelDescription: 'Naye update ki notifications',
            importance: Importance.max,
            priority: Priority.max,
            color: Color(0xFF0052CC),
          ),
        ),
      );
    });
  }

  // Permission sirf ek baar poochna
  static Future<void> requestPermissions() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool('notif_permission_asked') ?? false;
    if (asked) return;
    final a = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await a?.requestNotificationsPermission();
    await prefs.setBool('notif_permission_asked', true);
  }

  // Check karo aaj is house ka notification bheja ya nahi
  static Future<bool> _alreadySentToday(String houseId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final key =
        'notif_sent_${houseId}_${today.year}_${today.month}_${today.day}';
    return prefs.getBool(key) ?? false;
  }

  // Aaj sent mark karo
  static Future<void> _markSentToday(String houseId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final key =
        'notif_sent_${houseId}_${today.year}_${today.month}_${today.day}';
    await prefs.setBool(key, true);
  }

  /// Main method — resident login pe call karo
  /// - Permission sirf ek baar poochna
  /// - Sirf 1-10 tarikh ko notification
  /// - Din mein sirf ek baar
  /// - Dues nahi hain ya payment aayi — cancel
  static Future<void> handleDuesNotification({
    required String houseId,
    required List<String> allDues,
    required double totalDues,
  }) async {
    await init();
    await requestPermissions();

    final now = DateTime.now();

    // Sirf 1-10 tarikh ko
    if (now.day > 10) {
      await cancelAllForHouse(houseId);
      return;
    }

    // Koi dues nahi — cancel
    if (allDues.isEmpty) {
      await cancelAllForHouse(houseId);
      return;
    }

    // Aaj pehle bhej chuke hain — skip
    if (await _alreadySentToday(houseId)) return;

    // Notification bhejo
    final title = 'مینٹیننس یاددہانی — گھر نمبر $houseId';
    const body = 'برائے مہربانی مینٹیننس ویزٹ کریں۔ شکریہ';

    const ad = AndroidNotificationDetails(
      'dues_channel',
      'Dues Reminders',
      channelDescription: 'Monthly dues reminders',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF0052CC),
      styleInformation: BigTextStyleInformation(''),
    );
    const details = NotificationDetails(
        android: ad,
        iOS: DarwinNotificationDetails(
            presentAlert: true, presentSound: true));

    final id = _houseToId(houseId);
    await _plugin.show(id, title, body, details);

    // Aaj sent mark karo
    await _markSentToday(houseId);
  }

  // Jab payment aaye — cancel karo taake band ho jaye
  static Future<void> cancelAllForHouse(String houseId) async {
    await init();
    final base = _houseToId(houseId);
    for (int day = 1; day <= 10; day++) {
      await _plugin.cancel(base * 100 + day);
      await _plugin.cancel(base * 100 + day + 50000);
    }
    await _plugin.cancel(base);
    await _plugin.cancel(base + 1);
  }

  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  static int _houseToId(String houseId) {
    final d = houseId.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(d.isEmpty ? '0' : d) ?? 0;
  }
}
