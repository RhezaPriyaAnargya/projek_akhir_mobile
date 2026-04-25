import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    await _requestPermissions();
    _initialized = true;
  }

  static Future<void> _requestPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      debugPrint('Notification permission granted: $granted');

      final exactAlarmGranted = await androidPlugin
          .requestExactAlarmsPermission();
      debugPrint('Exact alarm permission granted: $exactAlarmGranted');
    }
  }

  static const _planCreatedChannelId = 'plan_created';
  static const _reminderChannelId = 'plan_reminder';

  static Future<void> showPlanCreatedNotification({
    required String planTitle,
    required String planLocation,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _planCreatedChannelId,
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
          contentTitle: '🎉 Yeay! Rencana Berhasil Dibuat!',
          summaryText: planTitle,
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      _generateId(planTitle),
      '🎉 Yeay! Rencana Berhasil Dibuat!',
      'Destinasimu: $planLocation siap menunggumu! Semangat berpetualangan 🗺️',
      details,
    );
  }

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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final departure = DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
    );
    final diff = departure.difference(today).inDays;

    if (diff == 1) {
      // Keberangkatan besok = ini adalah H-1, munculkan notifikasi sekarang atau jam 8 hari ini
      final jam8HariIni = DateTime(now.year, now.month, now.day, 8, 0);

      if (now.isAfter(jam8HariIni)) {
        // Jam 8 sudah lewat → tampilkan langsung sekarang
        await _showH1Notification(planTitle, planLocation);
      } else {
        // Jam 8 belum lewat → jadwalkan jam 8 hari ini
        final tzDateTime = tz.TZDateTime.from(jam8HariIni, tz.local);
        await _scheduleH1Notification(planTitle, planLocation, tzDateTime);
      }
    } else if (diff > 1) {
      // Keberangkatan lebih dari 1 hari lagi → jadwalkan H-1 jam 08.00
      final reminderDate = departureDate.subtract(const Duration(days: 1));
      final reminderDateTime = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        8,
        0,
      );
      final tzDateTime = tz.TZDateTime.from(reminderDateTime, tz.local);
      await _scheduleH1Notification(planTitle, planLocation, tzDateTime);
    }
    // diff == 0 → hari ini berangkat, skip reminder
  }

  static Future<void> _showH1Notification(
    String planTitle,
    String planLocation,
  ) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannelId,
        'Pengingat Perjalanan',
        channelDescription: 'Pengingat H-1 sebelum perjalanan dimulai',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(
          'Besok kamu berangkat ke $planLocation! Jangan lupa cek cuaca terkini '
          'supaya perjalananmu makin nyaman. Sudah packing belum? 🎒',
          contentTitle: '⏰ Jangan Lupakan Planmu!',
          summaryText: planTitle,
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      _generateId('${planTitle}_reminder'),
      '⏰ Jangan Lupakan Planmu!',
      'Besok berangkat ke $planLocation! Cek cuaca & pastikan sudah packing 🎒',
      details,
    );
  }

  static Future<void> _scheduleH1Notification(
    String planTitle,
    String planLocation,
    tz.TZDateTime tzDateTime,
  ) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannelId,
        'Pengingat Perjalanan',
        channelDescription: 'Pengingat H-1 sebelum perjalanan dimulai',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(
          'Besok kamu berangkat ke $planLocation! Jangan lupa cek cuaca terkini '
          'supaya perjalananmu makin nyaman. Sudah packing belum? 🎒',
          contentTitle: '⏰ Jangan Lupakan Planmu!',
          summaryText: planTitle,
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      _generateId('${planTitle}_reminder'),
      '⏰ Jangan Lupakan Planmu!',
      'Besok berangkat ke $planLocation! Cek cuaca & pastikan sudah packing 🎒',
      tzDateTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('H-1 reminder scheduled at: $tzDateTime');
  }

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

      if (date.isBefore(DateTime.now())) {
        return DateTime(year + 1, month, day);
      }
      return date;
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return null;
    }
  }

  static int _monthIndex(String abbr) {
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'mei',
      'jun',
      'jul',
      'ags',
      'sep',
      'okt',
      'nov',
      'des',
    ];
    final idx = months.indexOf(abbr.toLowerCase());
    return idx == -1 ? -1 : idx + 1;
  }

  static Future<void> cancelPlanNotifications(String planTitle) async {
    await _plugin.cancel(_generateId(planTitle));
    await _plugin.cancel(_generateId('${planTitle}_reminder'));
  }

  static Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }
}
