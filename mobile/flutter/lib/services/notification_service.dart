import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service for managing push notifications for critical patients
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Notification permission granted');
      } else {
        print('⚠️ Notification permission denied');
        return;
      }

      // Initialize local notifications
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(android: android, iOS: ios);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Get FCM token
      final token = await _messaging.getToken();
      if (kDebugMode) {
        print('🔑 FCM Token: $token');
      }

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      _initialized = true;
      print('✅ Notification service initialized');
    } catch (e) {
      print('❌ Notification init error: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped: ${response.payload}');
    // TODO: Navigate to patient details
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message: ${message.notification?.title}');
    // Show local notification when app is in foreground
    await _showLocalNotification(
      title: message.notification?.title ?? 'New Alert',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  /// Show local notification for critical patient
  Future<void> showCriticalPatientAlert({
    required String patientName,
    required double riskProbability,
    required String patientId,
  }) async {
    final riskPercent = (riskProbability * 100).toStringAsFixed(0);

    await _showLocalNotification(
      title: '🚨 CRITICAL PATIENT ALERT',
      body: '$patientName - Risk: $riskPercent% - Immediate attention required',
      payload: patientId,
      isCritical: true,
    );

    print('🚨 Critical alert sent for $patientName');
  }

  /// Show local notification for urgent patient
  Future<void> showUrgentPatientAlert({
    required String patientName,
    required double riskProbability,
    required String patientId,
  }) async {
    final riskPercent = (riskProbability * 100).toStringAsFixed(0);

    await _showLocalNotification(
      title: '⚠️ Urgent Patient',
      body: '$patientName - Risk: $riskPercent%',
      payload: patientId,
      isCritical: false,
    );

    print('⚠️ Urgent alert sent for $patientName');
  }

  /// Internal method to show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    bool isCritical = false,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        isCritical ? 'critical_channel' : 'urgent_channel',
        isCritical ? 'Critical Alerts' : 'Urgent Alerts',
        channelDescription: isCritical
            ? 'Critical patient alerts requiring immediate attention'
            : 'Urgent patient notifications',
        importance: isCritical ? Importance.max : Importance.high,
        priority: isCritical ? Priority.max : Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: isCritical
            ? Int64List.fromList(
                [0, 500, 200, 500, 200, 500]) // Triple vibration
            : Int64List.fromList([0, 300, 100, 300]), // Double vibration
        color: isCritical ? Color(0xFFEF4444) : Color(0xFFF59E0B),
        styleInformation: BigTextStyleInformation(body),
        category: AndroidNotificationCategory.alarm,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // Use default notification sound
        interruptionLevel:
            isCritical ? InterruptionLevel.critical : InterruptionLevel.active,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecond,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      print('❌ Show notification error: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}
