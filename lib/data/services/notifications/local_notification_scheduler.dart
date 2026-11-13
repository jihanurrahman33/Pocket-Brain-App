import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/logging/app_logger.dart';
import '../../../core/utils/clock.dart';
import '../../../domain/entities/task_item.dart';
import '../../../domain/services/reminder_scheduler.dart';

/// Reminders as local notifications via `flutter_local_notifications`.
///
/// How a reminder is *timed* depends on the platform (Strategy):
/// - Android/iOS: the OS schedules it, so it fires with the app closed and
///   survives reboots.
/// - Linux desktop: the plugin can only show notifications, so the app keeps
///   timers while it runs and, on launch, shows reminders missed while it
///   was closed (once each, within [missedWindow]).
final class LocalNotificationReminderScheduler implements ReminderScheduler {
  LocalNotificationReminderScheduler({
    required FlutterLocalNotificationsPlugin plugin,
    required SharedPreferences preferences,
    required Clock clock,
    required AppLogger logger,
    bool? osScheduling,
  }) : _plugin = plugin,
       _preferences = preferences,
       _clock = clock,
       _logger = logger,
       _osScheduling = osScheduling ?? (Platform.isAndroid || Platform.isIOS);

  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _preferences;
  final Clock _clock;
  final AppLogger _logger;
  final bool _osScheduling;

  final _taps = StreamController<String>.broadcast();
  final _timers = <String, Timer>{};
  bool _ready = false;

  /// Missed reminders older than this are not shown on launch.
  static const missedWindow = Duration(hours: 24);

  /// Timers further out are set up at a later launch instead.
  static const _maxTimerDelay = Duration(days: 20);
  static const _shownKey = 'shown_reminders';
  static const _channelId = 'reminders';
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Reminders',
      channelDescription: 'Reminders for your tasks',
      importance: Importance.high,
      priority: Priority.high,
    ),
    linux: LinuxNotificationDetails(),
  );

  @override
  Stream<String> get openedTaskIds => _taps.stream;

  /// Initialises the plugin and time zones; safe to call more than once.
  Future<void> initialize() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        linux: LinuxInitializationSettings(defaultActionName: 'Open task'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload case final id? when id.isNotEmpty) _taps.add(id);
      },
    );
    if (_osScheduling) {
      tz_data.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      // A tap that launched the app from a terminated state.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && payload != null) {
        scheduleMicrotask(() => _taps.add(payload));
      }
    }
    _ready = true;
  }

  @override
  Future<void> sync(TaskItem task) async {
    await cancel(task.id);
    final at = task.reminderAt;
    if (task.isDone || at == null) return;
    try {
      await initialize();
      if (_osScheduling) {
        await _scheduleWithOs(task, at);
      } else {
        await _scheduleInApp(task, at);
      }
    } on Object catch (e, s) {
      _logger.error('Scheduling reminder for ${task.id} failed', e, s);
    }
  }

  Future<void> _scheduleWithOs(TaskItem task, DateTime at) async {
    if (!at.isAfter(_clock.now())) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin.zonedSchedule(
      id: notificationIdFor(task.id),
      title: task.title,
      body: 'Reminder from Pocket Brain',
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details,
      // Inexact needs no special permission; it may fire a few minutes late.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: task.id,
    );
  }

  Future<void> _scheduleInApp(TaskItem task, DateTime at) async {
    final now = _clock.now();
    if (!at.isAfter(now)) {
      if (now.difference(at) <= missedWindow) await _showOnce(task, at);
      return;
    }
    final delay = at.difference(now);
    if (delay > _maxTimerDelay) return;
    _timers[task.id] = Timer(delay, () => _showOnce(task, at));
  }

  /// Shows a reminder unless it was already shown for this exact time.
  Future<void> _showOnce(TaskItem task, DateTime at) async {
    final key = '${task.id}@${at.toIso8601String()}';
    final shown = _preferences.getStringList(_shownKey) ?? const [];
    if (shown.contains(key)) return;
    await _plugin.show(
      id: notificationIdFor(task.id),
      title: task.title,
      body: 'Reminder from Pocket Brain',
      notificationDetails: _details,
      payload: task.id,
    );
    await _preferences.setStringList(_shownKey, [...shown.take(200), key]);
  }

  @override
  Future<void> cancel(String taskId) async {
    _timers.remove(taskId)?.cancel();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: notificationIdFor(taskId));
    } on Object catch (e, s) {
      _logger.error('Cancelling reminder for $taskId failed', e, s);
    }
  }

  @override
  Future<void> syncAll(List<TaskItem> tasks) async {
    await clear();
    for (final task in tasks) {
      await sync(task);
    }
  }

  @override
  Future<void> clear() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    if (_ready) await _plugin.cancelAll();
  }

  /// A stable 31-bit notification id for a task id (FNV-1a), so the same
  /// task always maps to the same notification across launches.
  static int notificationIdFor(String taskId) {
    const fnvPrime = 0x01000193;
    var hash = 0x811c9dc5;
    for (final unit in taskId.codeUnits) {
      hash = ((hash ^ unit) * fnvPrime) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
