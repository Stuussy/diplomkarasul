import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';
import '../widgets/dent_card.dart';
import '../widgets/dent_badge.dart';
import '../widgets/dent_shimmer.dart';
import '../widgets/patient_ui.dart';
import 'qr_scanner_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late Future<List<Appointment>> _futureAppointments;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _futureAppointments = _loadAppointments();
  }

  Future<List<Appointment>> _loadAppointments() async {
    final api = context.read<SessionProvider>().apiService;
    final now = DateTime.now();
    return api.fetchMyAppointments(
      from: now.subtract(const Duration(days: 365)),
      to: now.add(const Duration(days: 90)),
    );
  }

  Future<void> _refresh() async {
    setState(() => _futureAppointments = _loadAppointments());
    await _futureAppointments;
  }

  Future<void> _confirmViaQr(Appointment appointment) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result == null || !mounted) return;

    final api = context.read<SessionProvider>().apiService;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.confirmAppointmentByQr(
        appointmentId: appointment.id,
        qrPayload: result,
      );
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Запись подтверждена! ✓'),
          backgroundColor: ClinicTheme.mint,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _refresh();
    } catch (e) {
      HapticFeedback.heavyImpact();
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить запись?'),
        content: Text('Вы хотите отменить запись на «${appointment.service}»?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: ClinicTheme.coral),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final api = context.read<SessionProvider>().apiService;
    try {
      await api.cancelAppointment(appointment.id);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _submitReview(Appointment appointment) async {
    double rating = 5;
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Оставить отзыв'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () => setState(() => rating = i + 1.0),
                    icon: Icon(
                      i < rating ? LucideIcons.star : LucideIcons.star,
                      color: i < rating ? ClinicTheme.amber : ClinicTheme.mist,
                      size: 28,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Ваш комментарий'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Отправить')),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;

    final api = context.read<SessionProvider>().apiService;
    try {
      await api.submitReview(
        appointmentId: appointment.id,
        rating: rating.round(),
        comment: controller.text.trim(),
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: ClinicTheme.mist),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: _SegmentedControl(
              index: _tabIndex,
              labels: const ['Предстоящие', 'Прошедшие'],
              onChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _tabIndex = i);
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Appointment>>(
              future: _futureAppointments,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: const [
                        SizedBox(height: 16),
                        DentShimmerCard(height: 120),
                        SizedBox(height: 16),
                        DentShimmerCard(height: 120),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final now = DateTime.now();
                final all = snapshot.data ?? [];
                final upcoming = all.where((a) =>
                    a.startTime.isAfter(now) &&
                    (a.status == 'scheduled' || a.status == 'confirmed')).toList()
                  ..sort((a, b) => a.startTime.compareTo(b.startTime));
                final past = all.where((a) =>
                    a.startTime.isBefore(now) || a.status == 'completed' || a.status == 'cancelled').toList()
                  ..sort((a, b) => b.startTime.compareTo(a.startTime));
                final list = _tabIndex == 0 ? upcoming : past;

                if (list.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: [
                        const SizedBox(height: 80),
                        PatientEmptyState(
                          title: _tabIndex == 0 ? 'Нет предстоящих записей' : 'Нет прошедших записей',
                          message: _tabIndex == 0
                              ? 'Запишитесь к врачу на вкладке «Главная»'
                              : 'Ваши прошлые записи будут отображены здесь',
                          icon: LucideIcons.calendarX,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final apt = list[index];
                      return _AppointmentCard(
                        appointment: apt,
                        isUpcoming: _tabIndex == 0,
                        onConfirmQr: () => _confirmViaQr(apt),
                        onCancel: () => _cancelAppointment(apt),
                        onReview: () => _submitReview(apt),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: ClinicTheme.snow,
        borderRadius: BorderRadius.circular(14),
        boxShadow: ClinicTheme.shadowSm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: tabWidth * index + 4,
                top: 4,
                width: tabWidth - 8,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: ClinicTheme.azure,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: List.generate(labels.length, (i) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(i),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: i == index ? Colors.white : ClinicTheme.slate,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.isUpcoming,
    required this.onConfirmQr,
    required this.onCancel,
    required this.onReview,
  });

  final Appointment appointment;
  final bool isUpcoming;
  final VoidCallback onConfirmQr;
  final VoidCallback onCancel;
  final VoidCallback onReview;

  (Color, IconData) _statusInfo() {
    switch (appointment.status) {
      case 'scheduled':
        return (ClinicTheme.azure, LucideIcons.clock);
      case 'confirmed':
        return (ClinicTheme.mint, LucideIcons.checkCircle);
      case 'completed':
        return (ClinicTheme.slate, LucideIcons.circleCheck);
      case 'cancelled':
        return (ClinicTheme.coral, LucideIcons.xCircle);
      default:
        return (ClinicTheme.slate, LucideIcons.circle);
    }
  }

  DentBadgeVariant _badgeVariant() {
    switch (appointment.status) {
      case 'scheduled':
        return DentBadgeVariant.info;
      case 'confirmed':
        return DentBadgeVariant.success;
      case 'cancelled':
        return DentBadgeVariant.error;
      default:
        return DentBadgeVariant.neutral;
    }
  }

  String _statusLabel() {
    switch (appointment.status) {
      case 'scheduled':
        return 'Запланирован';
      case 'confirmed':
        return 'Подтверждён';
      case 'completed':
        return 'Завершён';
      case 'cancelled':
        return 'Отменён';
      default:
        return appointment.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _statusInfo();

    return DentCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.service,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(appointment.startTime),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              DentBadge(label: _statusLabel(), variant: _badgeVariant()),
            ],
          ),
          if (appointment.doctor != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(LucideIcons.stethoscope, size: 14, color: ClinicTheme.slate),
                const SizedBox(width: 6),
                Text(
                  appointment.doctor!.fullName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
          if (isUpcoming && appointment.status == 'scheduled') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onConfirmQr,
                    icon: const Icon(LucideIcons.scanLine, size: 16),
                    label: const Text('QR'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClinicTheme.coral,
                      side: const BorderSide(color: ClinicTheme.coralSoft, width: 1.2),
                    ),
                    child: const Text('Отменить'),
                  ),
                ),
              ],
            ),
          ],
          if (!isUpcoming && appointment.status == 'completed') ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onReview,
              icon: const Icon(LucideIcons.star, size: 16),
              label: const Text('Оставить отзыв'),
              style: FilledButton.styleFrom(
                backgroundColor: ClinicTheme.violetSoft,
                foregroundColor: ClinicTheme.violet,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.${dt.year} • $h:$m';
  }
}
