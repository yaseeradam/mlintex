import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      // Ensure tz.local is set safely if not set
      try {
        final String timeZoneName = DateTime.now().timeZoneName;
        if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
        }
      } catch (_) {}

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _initialized = true;
    } catch (e) {
      // Non-fatal notification init failure
    }
  }

  static Future<void> scheduleDebtReminder({
    required String debtId,
    required String customerName,
    required double amount,
    required DateTime scheduledDate,
    String? note,
  }) async {
    try {
      await init();

      final id = debtId.hashCode.abs() % 100000;
      final body = (note != null && note.isNotEmpty)
          ? '₦${amount.toStringAsFixed(0)} from $customerName — $note'
          : '₦${amount.toStringAsFixed(0)} owed by $customerName is due today.';

      tz.TZDateTime scheduledTz;
      try {
        scheduledTz = tz.TZDateTime.from(scheduledDate, tz.local);
      } catch (_) {
        scheduledTz = tz.TZDateTime.from(scheduledDate, tz.UTC);
      }

      await _plugin.zonedSchedule(
        id: id,
        title: '💰 Debt Reminder',
        body: body,
        scheduledDate: scheduledTz,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'debt_reminders',
            'Debt Reminders',
            channelDescription: 'Notifications for upcoming debt due dates',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } catch (e) {
      // Failure to schedule reminder shouldn't fail recording the debt
    }
  }

  static Future<void> cancelDebtReminder(String debtId) async {
    try {
      await _plugin.cancel(id: debtId.hashCode.abs() % 100000);
    } catch (_) {}
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(),
);
