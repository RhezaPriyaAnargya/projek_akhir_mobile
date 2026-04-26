import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotifItem {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  bool isRead;

  NotifItem({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'time': time.toIso8601String(),
        'isRead': isRead,
      };

  factory NotifItem.fromJson(Map<String, dynamic> json) => NotifItem(
        id: json['id'],
        title: json['title'],
        body: json['body'],
        time: DateTime.parse(json['time']),
        isRead: json['isRead'] ?? false,
      );
}

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const _prefKey = 'in_app_notifications';

  // ─── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    await _requestPermissions();
    _initialized = true;
  }

  static Future<void> _requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  // ─── In-App Notification Storage ──────────────────────────────────────────

  static Future<void> _saveInApp(NotifItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getInAppNotifications();
    list.insert(0, item);
    final trimmed = list.take(50).toList();
    await prefs.setString(
      _prefKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  static Future<List<NotifItem>> getInAppNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => NotifItem.fromJson(e)).toList();
  }

  static Future<int> getUnreadCount() async {
    final list = await getInAppNotifications();
    return list.where((e) => !e.isRead).length;
  }

  static Future<void> markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getInAppNotifications();
    for (final item in list) {
      item.isRead = true;
    }
    await prefs.setString(
      _prefKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> clearAllInApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  // ─── Notifikasi 1: Plan Berhasil Dibuat ───────────────────────────────────

  static Future<void> showPlanCreatedNotification({
    required String planTitle,
    required String planLocation,
  }) async {
    const title = '🎉 Yeay! Rencana Berhasil Dibuat!';
    final body =
        'Destinasimu: $planLocation siap menunggumu! Semangat berpetualangan 🗺️';

    await _plugin.show(
      _generateId(planTitle),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'plan_created',
          'Rencana Dibuat',
          channelDescription:
              'Notifikasi saat rencana perjalanan berhasil dibuat',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(
            'Destinasimu: $planLocation siap menunggumu! Semangat merencanakan '
            'petualangan seru dan jangan lupa cek cuaca sebelum berangkat ya ☀️',
            contentTitle: title,
            summaryText: planTitle,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    await _saveInApp(NotifItem(
      id: 'created_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: 'Rencana "$planTitle" ke $planLocation berhasil dibuat! '
          'Semangat merencanakan petualangan seru dan jangan lupa cek cuaca ☀️',
      time: DateTime.now(),
    ));
  }

  // ─── Notifikasi 2: H-1 Reminder ───────────────────────────────────────────

  static Future<void> scheduleH1Reminder({
    required String planTitle,
    required String planLocation,
    required String dateString,
  }) async {
    final departureDate = _parseDepartureDate(dateString);
    if (departureDate == null) {
      debugPrint('Could not parse departure date: $dateString');
      return;
    }

    const title = '⏰ Jangan Lupakan Planmu!';
    final body =
        'Besok berangkat ke $planLocation! Cek cuaca & pastikan sudah packing 🎒';
    final bodyLong =
        'Besok kamu berangkat ke $planLocation! Jangan lupa cek cuaca terkini '
        'supaya perjalananmu makin nyaman. Sudah packing belum? 🎒';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final departure =
        DateTime(departureDate.year, departureDate.month, departureDate.day);
    final diff = departure.difference(today).inDays;

    if (diff == 1) {
      final jam8HariIni = DateTime(now.year, now.month, now.day, 8, 0);
      if (now.isAfter(jam8HariIni)) {
        await _showH1Now(planTitle, title, body, bodyLong);
      } else {
        await _scheduleH1(
          planTitle, title, body, bodyLong,
          tz.TZDateTime.from(jam8HariIni, tz.local),
        );
      }
      await _saveInApp(NotifItem(
        id: 'reminder_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: 'Pengingat H-1 untuk "$planTitle" ke $planLocation telah '
            'dijadwalkan. Jangan lupa cek cuaca! 🎒',
        time: DateTime.now(),
      ));
    } else if (diff > 1) {
      final reminderDate = departureDate.subtract(const Duration(days: 1));
      final reminderDateTime = DateTime(
          reminderDate.year, reminderDate.month, reminderDate.day, 8, 0);
      await _scheduleH1(
        planTitle, title, body, bodyLong,
        tz.TZDateTime.from(reminderDateTime, tz.local),
      );
      await _saveInApp(NotifItem(
        id: 'reminder_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: 'Pengingat H-1 untuk "$planTitle" ke $planLocation dijadwalkan '
            'pada ${reminderDate.day}/${reminderDate.month}. Jangan lupa cek cuaca! 🎒',
        time: DateTime.now(),
      ));
    }
  }

  static Future<void> _showH1Now(
      String planTitle, String title, String body, String bodyLong) async {
    await _plugin.show(
      _generateId('${planTitle}_reminder'),
      title,
      body,
      _reminderDetails(title, bodyLong, planTitle),
    );
  }

  static Future<void> _scheduleH1(String planTitle, String title, String body,
      String bodyLong, tz.TZDateTime tzDateTime) async {
    await _plugin.zonedSchedule(
      _generateId('${planTitle}_reminder'),
      title,
      body,
      tzDateTime,
      _reminderDetails(title, bodyLong, planTitle),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static NotificationDetails _reminderDetails(
      String title, String bodyLong, String planTitle) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'plan_reminder',
        'Pengingat Perjalanan',
        channelDescription: 'Pengingat H-1 sebelum perjalanan dimulai',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(
          bodyLong,
          contentTitle: title,
          summaryText: planTitle,
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // ─── Cancel ───────────────────────────────────────────────────────────────

  static Future<void> cancelPlanNotifications(String planTitle) async {
    await _plugin.cancel(_generateId(planTitle));
    await _plugin.cancel(_generateId('${planTitle}_reminder'));
  }

  static Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static int _generateId(String key) => key.hashCode.abs() % 100000;

  static DateTime? _parseDepartureDate(String dateString) {
    try {
      final raw = dateString.split('-').first.trim();
      final parts = raw.split(' ');
      if (parts.length < 2) return null;
      final day = int.parse(parts[0]);
      final month = _monthIndex(parts[1]);
      if (month == -1) return null;
      final year = DateTime.now().year;
      final date = DateTime(year, month, day);
      if (date.isBefore(DateTime.now())) return DateTime(year + 1, month, day);
      return date;
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return null;
    }
  }

  static int _monthIndex(String abbr) {
    const months = [
      'jan', 'feb', 'mar', 'apr', 'mei', 'jun',
      'jul', 'ags', 'sep', 'okt', 'nov', 'des',
    ];
    final idx = months.indexOf(abbr.toLowerCase());
    return idx == -1 ? -1 : idx + 1;
  }
}