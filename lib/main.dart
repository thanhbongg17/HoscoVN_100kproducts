import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Nếu đã dùng `flutterfire configure`, import file này:
import 'firebase_options.dart';

/// Background handler: chạy khi có push tới lúc app ở background/terminated.
/// CHÚ Ý: cần `@pragma('vm:entry-point')` để không bị tree-shake.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Nếu chưa dùng flutterfire configure, có thể dùng:
    // await Firebase.initializeApp();
  }
  // Xử lý dữ liệu nếu cần
  debugPrint('🔕 BG message: ${message.messageId} | data=${message.data}');
}

/// Local notifications cho banner khi app đang mở (foreground)
/// local notifications hiển thị khi app đang mở
final FlutterLocalNotificationsPlugin _localNoti =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for important notifications.',
  importance: Importance.high,
);

Future<void> _initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
  await _localNoti.initialize(initSettings);

  await _localNoti
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);
}
/// main khởi tạo toàn hệ thống
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Nếu chưa có firebase_options.dart:
    // await Firebase.initializeApp();
  }

  // Đăng ký background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // iOS & Android 13+: xin quyền hiển thị noti
  await FirebaseMessaging.instance.requestPermission(
    alert: true, badge: true, sound: true,
    provisional: false,
  );

  // Foreground presentation (đặc biệt quan trọng với iOS)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );

  // Local notifications cho foreground banner (Android)
  await _initLocalNotifications();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _token;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  Future<void> _setupFCM() async {
    // Lấy token để gửi test từ Firebase Console
    final t = await FirebaseMessaging.instance.getToken();
    setState(() => _token = t);
    debugPrint('📬 FCM TOKEN: $t');

    // Listener khi app đang mở (foreground): tự hiển thị banner bằng local_notis
    _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final n = msg.notification;
      final android = n?.android;
      debugPrint('🔔 FG message: title=${n?.title}, body=${n?.body}, data=${msg.data}');

      await _localNoti.show(
        n.hashCode,
        n?.title ?? 'New message',
        n?.body ?? 'You have a new notification',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            priority: Priority.high,
            importance: Importance.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: msg.data.toString(),
      );
    });

    // Khi user bấm vào noti để mở app (từ background)
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
          debugPrint('👉 Opened from notification: data=${msg.data}');
          _navigateByPayload(msg.data);
        });

    // Nếu app được mở từ trạng thái kill do user bấm noti
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      debugPrint('🚀 Launched from terminated by noti: data=${initial.data}');
      if (mounted) _navigateByPayload(initial.data);
    }
  }
/// điều hướng theo payload
  void _navigateByPayload(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    if (route == '/detail') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(payload: data)),
      );
    }
  }

  @override
  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push Notifications (FCM) Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('FCM Token (copy để test từ Firebase Console):',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SelectableText(_token ?? 'Đang lấy token...'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await FirebaseMessaging.instance.subscribeToTopic('demo');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã subscribe topic: demo')),
                  );
                }
              },
              child: const Text('Subscribe topic: demo'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await FirebaseMessaging.instance.unsubscribeFromTopic('demo');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã hủy topic: demo')),
                  );
                }
              },
              child: const Text('Unsubscribe topic: demo'),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final Map<String, dynamic> payload;
  const DetailScreen({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Opened from Notification')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Payload:\n$payload'),
      ),
    );
  }
}
