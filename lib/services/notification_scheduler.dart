import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

enum NotificationTarget { moodCheckIn }

enum ReminderType { morning, midday, evening }

class NotificationScheduler {
  static final NotificationScheduler instance = NotificationScheduler._();

  NotificationScheduler._();

  static const String _scheduledIdsKey = 'scheduled_notification_ids';
  static const String _pendingTargetKey = 'pending_notification_target';
  static const int _windowDays = 21;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true && response != null) {
      await _setPendingTarget(response.payload);
    }

    _initialized = true;
  }

  Future<void> scheduleDailyReminders() async {
    if (!await Permission.notification.isGranted) {
      return;
    }

    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final scheduledIds = _loadScheduledIds(prefs);
    final now = DateTime.now();

    _pruneExpiredIds(scheduledIds, now);

    final notificationsToSchedule = <_ScheduledNotification>[];
    for (var dayOffset = 0; dayOffset < _windowDays; dayOffset++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: dayOffset));
      for (final reminderType in ReminderType.values) {
        final scheduledDateTime = _scheduledDateTime(date, reminderType);
        if (scheduledDateTime.isBefore(now)) {
          continue;
        }

        final id = _buildNotificationId(date, reminderType);
        if (scheduledIds.contains(id.toString())) {
          continue;
        }

        notificationsToSchedule.add(
          _ScheduledNotification(
            id: id,
            scheduledDateTime: scheduledDateTime,
            reminderType: reminderType,
          ),
        );
      }
    }

    for (final notification in notificationsToSchedule) {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: _titleFor(notification.reminderType),
        body: _bodyFor(notification.reminderType),
        scheduledDate: tz.TZDateTime.from(
          notification.scheduledDateTime,
          tz.local,
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_wellness_reminders',
            'Daily wellness reminders',
            channelDescription:
                'Mood, reflection, and gentle check-in reminders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: NotificationTarget.moodCheckIn.name,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      scheduledIds.add(notification.id.toString());
    }

    await prefs.setStringList(_scheduledIdsKey, scheduledIds.toList());
  }

  Future<void> cancelMorningReminderForTodayIfBeforeNine() async {
    final now = DateTime.now();
    if (now.hour >= 9) {
      return;
    }

    final todayMorningId = _buildNotificationId(now, ReminderType.morning);
    await _plugin.cancel(id: todayMorningId);
    await _removeScheduledId(todayMorningId);
  }

  Future<void> clearScheduledReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _loadScheduledIds(prefs);
    for (final rawId in ids) {
      final id = int.tryParse(rawId);
      if (id != null) {
        await _plugin.cancel(id: id);
      }
    }
    await prefs.remove(_scheduledIdsKey);
  }

  Future<NotificationTarget?> consumePendingTarget() async {
    final prefs = await SharedPreferences.getInstance();
    final targetValue = prefs.getString(_pendingTargetKey);
    if (targetValue == null) {
      return null;
    }

    await prefs.remove(_pendingTargetKey);
    return NotificationTarget.values.firstWhere(
      (value) => value.name == targetValue,
      orElse: () => NotificationTarget.moodCheckIn,
    );
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    await _setPendingTarget(response.payload);
  }

  Future<void> _setPendingTarget(String? payload) async {
    if (payload != NotificationTarget.moodCheckIn.name) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingTargetKey, payload!);
  }

  List<String> _loadScheduledIds(SharedPreferences prefs) {
    return prefs.getStringList(_scheduledIdsKey) ?? <String>[];
  }

  void _pruneExpiredIds(List<String> scheduledIds, DateTime now) {
    scheduledIds.removeWhere((rawId) {
      final id = int.tryParse(rawId);
      if (id == null) {
        return true;
      }

      final scheduledDateTime = _dateTimeFromId(id);
      return scheduledDateTime.isBefore(now);
    });
  }

  Future<void> _removeScheduledId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _loadScheduledIds(prefs);
    ids.remove(id.toString());
    await prefs.setStringList(_scheduledIdsKey, ids);
  }

  int _buildNotificationId(DateTime date, ReminderType type) {
    final datePart = date.year * 1000000 + date.month * 10000 + date.day * 100;
    return datePart + type.index + 1;
  }

  DateTime _dateTimeFromId(int id) {
    final typeIndex = (id % 10) - 1;
    final yyyymmdd = id ~/ 10;
    final year = yyyymmdd ~/ 10000;
    final month = (yyyymmdd % 10000) ~/ 100;
    final day = yyyymmdd % 100;
    final reminderType = ReminderType.values[typeIndex.clamp(0, 2)];
    final date = DateTime(year, month, day);
    return _scheduledDateTime(date, reminderType);
  }

  DateTime _scheduledDateTime(DateTime date, ReminderType type) {
    switch (type) {
      case ReminderType.morning:
        return DateTime(date.year, date.month, date.day, 9);
      case ReminderType.midday:
        return DateTime(date.year, date.month, date.day, 14);
      case ReminderType.evening:
        return DateTime(date.year, date.month, date.day, 21);
    }
  }

  String _titleFor(ReminderType type) {
    switch (type) {
      case ReminderType.morning:
        return 'Good morning! How are you feeling today?';
      case ReminderType.midday:
        return 'Take a mindful pause';
      case ReminderType.evening:
        return 'Time to reflect 🌙';
    }
  }

  String _bodyFor(ReminderType type) {
    switch (type) {
      case ReminderType.morning:
        return 'Take 30 seconds to log your mood and start your day.';
      case ReminderType.midday:
        return 'Pause for a moment and let your thoughts out in a calm space inside the app.';
      case ReminderType.evening:
        return 'How did your day go? Write a little in your diary.';
    }
  }
}

class _ScheduledNotification {
  const _ScheduledNotification({
    required this.id,
    required this.scheduledDateTime,
    required this.reminderType,
  });

  final int id;
  final DateTime scheduledDateTime;
  final ReminderType reminderType;
}
