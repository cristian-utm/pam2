import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/assignment_item.dart';

class AssignmentNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static int _notificationIdCounter = 1000;

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const DarwinInitializationSettings initializationSettingsMacOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsMacOS,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    await _notifications
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
  }

  static Future<int?> scheduleNotification(AssignmentItem assignment) async {
    if (assignment.isCompleted || assignment.deadline.isBefore(DateTime.now())) {
      return null;
    }

    try {
      final notificationId = _notificationIdCounter++;
      final scheduledDate = assignment.deadline.subtract(const Duration(hours: 1));
      
      if (scheduledDate.isBefore(DateTime.now())) {
        return null;
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'assignment_channel',
        'Assignment Notifications',
        channelDescription: 'Notifications for assignment deadlines',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
        macOS: iOSPlatformChannelSpecifics,
      );

      await _notifications.zonedSchedule(
        notificationId,
        'Assignment Due Soon!',
        '${assignment.title} (${assignment.subject}) is due in 1 hour',
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: assignment.id,
      );

      return notificationId;
    } catch (e) {
      print('Error scheduling notification: $e');
      return null;
    }
  }

  static Future<void> cancelNotification(int? notificationId) async {
    if (notificationId != null) {
      try {
        await _notifications.cancel(notificationId);
      } catch (e) {
        print('Error canceling notification: $e');
      }
    }
  }

  static Future<int?> updateNotification(AssignmentItem assignment) async {
    if (assignment.notificationId != null) {
      await cancelNotification(assignment.notificationId);
    }
    return await scheduleNotification(assignment);
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      print('Error canceling all notifications: $e');
    }
  }

  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      print('Error getting pending notifications: $e');
      return [];
    }
  }
}