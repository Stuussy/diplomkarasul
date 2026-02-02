import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../providers/session_provider.dart';
import '../services/notification_service.dart';
import '../widgets/patient_ui.dart';
import '../widgets/status_badge.dart';
import '../widgets/clinic_card.dart';
import 'qr_scanner_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

enum _AppointmentView { upcoming, past }

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Appointment>> _future;
  _AppointmentView _view = _AppointmentView.upcoming;

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

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PatientPalette.background,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          children: [
            const SizedBox(height: 12),
            SegmentedButton<_AppointmentView>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((state) {
                  if (state.contains(WidgetState.selected)) {
                    return PatientPalette.primary;
                  }
                  return Colors.white;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((state) {
                  if (state.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.black87;
                }),
              ),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _AppointmentView.upcoming,
                  label: Text('Предстоящие'),
                ),
                ButtonSegment(
                  value: _AppointmentView.past,
                  label: Text('Прошедшие'),
                ),
              ],
              selected: <_AppointmentView>{_view},
              onSelectionChanged: (value) =>
                  setState(() => _view = value.first),
            ),
            const SizedBox(height: 20),
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
                  final upcoming =
                      appointments
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
                  final past =
                      appointments
                          .where((a) => !a.startTime.isAfter(now))
                          .toList()
                        ..sort((b, a) => a.startTime.compareTo(b.startTime));

                  final items = _view == _AppointmentView.upcoming
                      ? upcoming
                      : past;
                  return _buildList(
                    items,
                    isPatient,
                    _view == _AppointmentView.upcoming,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Appointment> items, bool isPatient, bool upcoming) {
    if (items.isEmpty) {
      return const PatientEmptyState(
        title: 'Записей нет',
        message: 'Когда вы запишетесь на приём, он появится в этом списке.',
        icon: Icons.event_note_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final appointment = items[index];
          final showReviewButton =
              !upcoming &&
              isPatient &&
              appointment.status == 'completed' &&
              appointment.review == null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AppointmentCard(
                appointment: appointment,
                upcoming: upcoming,
                controls:
                    isPatient && upcoming && appointment.status == 'scheduled'
                    ? _buildActions(appointment)
                    : null,
              ),
              if (showReviewButton)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _showReviewDialog(appointment),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Оставить отзыв'),
                    ),
                  ),
                ),
            ],
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
      messenger.showSnackBar(
        const SnackBar(content: Text('Запись подтверждена.')),
      );
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
      messenger.showSnackBar(
        const SnackBar(content: Text('Запись подтверждена по QR.')),
      );
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
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

  Future<void> _showReviewDialog(Appointment appointment) async {
    final ratingNotifier = ValueNotifier<int>(5);
    final commentController = TextEditingController();
    bool isSubmitting = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setState) {
            Future<void> submit() async {
              setState(() => isSubmitting = true);
              try {
                await innerContext
                    .read<SessionProvider>()
                    .apiService
                    .submitReview(
                      appointmentId: appointment.id,
                      rating: ratingNotifier.value,
                      comment: commentController.text.trim().isEmpty
                          ? null
                          : commentController.text.trim(),
                    );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text('Ошибка: $error')));
              } finally {
                if (innerContext.mounted) setState(() => isSubmitting = false);
              }
            }

            return AlertDialog(
              title: const Text('Отзыв о визите'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: ratingNotifier,
                    builder: (context, value, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) => IconButton(
                          onPressed: () => ratingNotifier.value = index + 1,
                          icon: Icon(
                            index < value ? Icons.star : Icons.star_border,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий (необязательно)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Отправить'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Спасибо за отзыв!')));
      }
    }
    commentController.dispose();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(status: status);
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.upcoming,
    this.controls,
  });

  final Appointment appointment;
  final bool upcoming;
  final Widget? controls;

  @override
  Widget build(BuildContext context) {
    final date = appointment.startTime;
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final timeLabel =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final doctor = appointment.doctor?.fullName ?? 'Врач уточняется';

    return ClinicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: upcoming
                    ? PatientPalette.primary.withValues(alpha: 0.1)
                    : Colors.grey.shade200,
                child: Icon(
                  upcoming ? Icons.access_time : Icons.history,
                  color: upcoming ? PatientPalette.primary : Colors.black54,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.service,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateLabel · $timeLabel',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: appointment.status),
            ],
          ),
          const SizedBox(height: 16),
          Text(doctor, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (controls != null) ...[const SizedBox(height: 16), controls!],
        ],
      ),
    );
  }
}
