import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../providers/session_provider.dart';
import '../services/notification_service.dart';
import 'qr_scanner_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Appointment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Appointment>> _load() {
    return context.read<SessionProvider>().apiService.fetchAppointments();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPatient = context.watch<SessionProvider>().user?.role == 'patient';

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Предстоящие'),
              Tab(text: 'Прошедшие'),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<Appointment>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final appointments = snapshot.data ?? [];
                final now = DateTime.now();
                final upcoming = appointments
                    .where(
                      (a) =>
                          a.status != 'cancelled' &&
                          (a.status == 'scheduled' ||
                              a.status == 'confirmed' ||
                              a.status == 'completed') &&
                          a.startTime.isAfter(now),
                    )
                    .toList()
                  ..sort((a, b) => a.startTime.compareTo(b.startTime));
                final past = appointments.where((a) => !a.startTime.isAfter(now)).toList()
                  ..sort((b, a) => a.startTime.compareTo(b.startTime));

                return TabBarView(
                  children: [
                    _buildList(upcoming, isPatient, true),
                    _buildList(past, isPatient, false),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Appointment> items, bool isPatient, bool upcoming) {
    if (items.isEmpty) {
      return const Center(child: Text('Нет записей'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final appointment = items[index];
          final date = appointment.startTime;
          final dateLabel =
              '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
          final timeLabel =
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          final statusChip = _StatusChip(status: appointment.status);
          return Card(
            child: ListTile(
              leading: Icon(
                upcoming ? Icons.watch_later_outlined : Icons.history_toggle_off,
                color: upcoming ? Colors.blue : Colors.grey,
              ),
              title: Text('${appointment.service} — $dateLabel $timeLabel'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appointment.doctor?.fullName ?? ''),
                  const SizedBox(height: 4),
                  statusChip,
                ],
              ),
              trailing:
                  isPatient && upcoming && appointment.status == 'scheduled'
                      ? _buildActions(appointment)
                      : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildActions(Appointment appointment) {
    return Wrap(
      spacing: 8,
      children: [
        if (appointment.status == 'scheduled')
          TextButton(
            onPressed: () => _confirm(appointment),
            child: const Text('Подтвердить'),
          ),
        if (appointment.status == 'scheduled')
          TextButton.icon(
            onPressed: () => _confirmViaQr(),
            icon: const Icon(Icons.qr_code_2),
            label: const Text('QR'),
          ),
        TextButton(
          onPressed: () => _confirmCancel(appointment),
          child: const Text('Отменить'),
        ),
      ],
    );
  }

  Future<void> _confirm(Appointment appointment) async {
    final api = context.read<SessionProvider>().apiService;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await api.confirmAppointment(appointment.id);
      if (!mounted) return;
      await NotificationService().showAppointmentConfirmed(result);
      messenger.showSnackBar(const SnackBar(content: Text('Запись подтверждена.')));
      _refresh();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _confirmViaQr() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final payload = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (payload == null || !mounted) return;
    final api = context.read<SessionProvider>().apiService;
    try {
      final result = await api.confirmAppointmentByQr(payload);
      if (!mounted) return;
      await NotificationService().showAppointmentConfirmed(result);
      messenger.showSnackBar(const SnackBar(content: Text('Запись подтверждена по QR.')));
      _refresh();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _confirmCancel(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить запись?'),
        content: const Text('Вы уверены, что хотите отменить запись?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _cancel(appointment);
  }

  Future<void> _cancel(Appointment appointment) async {
    final api = context.read<SessionProvider>().apiService;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.cancelAppointment(appointment.id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Запись отменена.')));
      _refresh();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  Color _colorForStatus() {
    switch (status) {
      case 'confirmed':
        return Colors.green.shade100;
      case 'scheduled':
        return Colors.orange.shade100;
      case 'completed':
        return Colors.blue.shade100;
      case 'cancelled':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  String _labelForStatus() {
    switch (status) {
      case 'confirmed':
        return 'Подтверждено';
      case 'scheduled':
        return 'Ожидает';
      case 'completed':
        return 'Завершено';
      case 'cancelled':
        return 'Отменено';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _colorForStatus(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _labelForStatus(),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
