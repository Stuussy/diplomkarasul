import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/slot.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';
import '../widgets/dent_card.dart';
import '../widgets/dent_badge.dart';
import '../widgets/dent_shimmer.dart';

class AppointmentRequestScreen extends StatefulWidget {
  const AppointmentRequestScreen({super.key, required this.doctor});

  final AppUser doctor;

  @override
  State<AppointmentRequestScreen> createState() =>
      _AppointmentRequestScreenState();
}

class _AppointmentRequestScreenState extends State<AppointmentRequestScreen> {
  late Future<List<Slot>> _futureSlots;
  Slot? _selectedSlot;
  String _selectedService = '';
  bool _isBooking = false;
  bool _hasActiveBooking = false;

  @override
  void initState() {
    super.initState();
    _futureSlots = _loadSlots();
    if (widget.doctor.specialties.isNotEmpty) {
      _selectedService = widget.doctor.specialties.first;
    }
    _checkActiveBooking();
  }

  Future<List<Slot>> _loadSlots() {
    final api = context.read<SessionProvider>().apiService;
    return api.fetchSlots(doctorId: widget.doctor.id, status: 'available');
  }

  Future<void> _checkActiveBooking() async {
    try {
      final api = context.read<SessionProvider>().apiService;
      final now = DateTime.now();
      final appointments = await api.fetchAppointments(
        from: now,
        to: now.add(const Duration(days: 60)),
      );
      if (mounted) {
        setState(() {
          _hasActiveBooking = appointments.any(
            (a) => a.status == 'scheduled' || a.status == 'confirmed',
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _book() async {
    if (_selectedSlot == null || _selectedService.isEmpty) return;
    setState(() => _isBooking = true);
    HapticFeedback.lightImpact();

    final api = context.read<SessionProvider>().apiService;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.bookSlot(
        slot: _selectedSlot!,
        service: _selectedService,
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      context.read<SessionProvider>().notifyBooked();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Вы успешно записаны! ✓'),
          backgroundColor: ClinicTheme.mint,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final specialty = widget.doctor.specialties.isNotEmpty
        ? widget.doctor.specialties.join(', ')
        : 'Специализация уточняется';

    return Scaffold(
      backgroundColor: ClinicTheme.mist,
      appBar: AppBar(
        title: const Text('Запись к врачу'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doctor mini-card
                  DentCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: ClinicTheme.azure.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              widget.doctor.firstName.isNotEmpty
                                  ? widget.doctor.firstName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: ClinicTheme.azure,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.doctor.fullName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(specialty, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        DentBadge(
                          label: widget.doctor.rating.toStringAsFixed(1),
                          icon: LucideIcons.star,
                          variant: DentBadgeVariant.warning,
                        ),
                      ],
                    ),
                  ),

                  if (_hasActiveBooking) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ClinicTheme.amberSoft,
                        borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertTriangle, color: ClinicTheme.amber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'У вас уже есть активная запись. Можно записаться повторно.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClinicTheme.midnight),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Service selection
                  if (widget.doctor.specialties.length > 1) ...[
                    const SizedBox(height: 24),
                    Text('Услуга', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.doctor.specialties.map((s) {
                        final selected = s == _selectedService;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedService = s);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? ClinicTheme.azure : ClinicTheme.snow,
                              borderRadius: BorderRadius.circular(20),
                              border: selected ? null : Border.all(color: ClinicTheme.mist),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                color: selected ? Colors.white : ClinicTheme.midnight,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Slots
                  const SizedBox(height: 24),
                  Text('Доступные слоты', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),

                  FutureBuilder<List<Slot>>(
                    future: _futureSlots,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Column(
                          children: List.generate(3, (_) => const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: DentShimmer(height: 56),
                          )),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Ошибка: ${snapshot.error}'));
                      }
                      final slots = snapshot.data ?? [];
                      if (slots.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(LucideIcons.calendarX, size: 40, color: ClinicTheme.slate),
                              const SizedBox(height: 12),
                              Text('Нет доступных слотов', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                'Попробуйте позже или выберите другого врача',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      }

                      // Group by date
                      final grouped = <String, List<Slot>>{};
                      for (final slot in slots) {
                        final dayKey = '${slot.startTime.year}-${slot.startTime.month.toString().padLeft(2, '0')}-${slot.startTime.day.toString().padLeft(2, '0')}';
                        grouped.putIfAbsent(dayKey, () => []).add(slot);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: grouped.entries.map((entry) {
                          final date = DateTime.parse(entry.key);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  _formatDayLabel(date),
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ClinicTheme.slate),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: entry.value.map((slot) {
                                  final selected = _selectedSlot?.id == slot.id;
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _selectedSlot = slot);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selected ? ClinicTheme.azure : ClinicTheme.snow,
                                        borderRadius: BorderRadius.circular(14),
                                        border: selected ? null : Border.all(color: ClinicTheme.mist),
                                        boxShadow: selected ? [
                                          BoxShadow(
                                            color: ClinicTheme.azure.withValues(alpha: 0.2),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ] : null,
                                      ),
                                      child: Text(
                                        '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          color: selected ? Colors.white : ClinicTheme.midnight,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom CTA
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: ClinicTheme.snow,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x0C000000),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _selectedSlot == null || _isBooking ? null : _book,
                child: _isBooking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Записаться'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    if (dateDay == today) return 'Сегодня';
    if (dateDay == today.add(const Duration(days: 1))) return 'Завтра';
    const weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return '${weekDays[date.weekday - 1]}, ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
  }
}
