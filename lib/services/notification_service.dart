import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/appointment.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> _ensurePermissionRequested() async {
    await init();

    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macOsImplementation =
        _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    await macOsImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> showAppointmentConfirmed(Appointment appointment) async {
    await _ensurePermissionRequested();
    if (!_initialized) return;
    final doctorName = appointment.doctor?.fullName ?? 'Ваш врач';
    final clinicName = appointment.clinic?.name ?? 'клинике';
    final start = appointment.startTime;
    final dateLabel =
        '${start.day.toString().padLeft(2, '0')}.${start.month.toString().padLeft(2, '0')} в '
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    const androidDetails = AndroidNotificationDetails(
      'appointments',
      'Записи',
      channelDescription: 'Уведомления о подтверждениях записей',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      appointment.hashCode,
      'Запись подтверждена',
      '$doctorName ждёт вас $dateLabel в $clinicName',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
