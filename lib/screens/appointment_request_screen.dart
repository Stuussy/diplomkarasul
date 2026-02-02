import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/slot.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import '../widgets/patient_ui.dart';
import '../widgets/section_header.dart';
import '../widgets/clinic_card.dart';

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
  DateTime? _selectedDate;
  late String _selectedService;
  late final List<String> _services;
  bool _isBooking = false;
  bool _isCheckingBooking = true;
  bool _hasActiveBooking = false;

  @override
  void initState() {
    super.initState();
    final api = context.read<SessionProvider>().apiService;
    _futureSlots = api.fetchSlots(
      doctorId: widget.doctor.id,
      status: 'available',
    );
    _services = widget.doctor.specialties.isNotEmpty
        ? widget.doctor.specialties
        : const ['Консультация'];
    _selectedService = _services.first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBookingState());
  }

  Future<void> _loadBookingState() async {
    final api = context.read<SessionProvider>().apiService;
    try {
      final appointments = await api.fetchAppointments();
      final hasActive = appointments
          .where(
            (app) => app.status == 'scheduled' || app.status == 'confirmed',
          )
          .isNotEmpty;
      if (!mounted) return;
      setState(() {
        _hasActiveBooking = hasActive;
        _isCheckingBooking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCheckingBooking = false);
    }
  }

  Future<void> _bookSlot() async {
    final slot = _selectedSlot;
    if (slot == null) return;
    setState(() => _isBooking = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.bookSlot(slot: slot, service: _selectedService);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Запись подтверждена.')));
      setState(() => _hasActiveBooking = true);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('already')
          ? 'Вы уже записаны. Сначала отмените текущую запись.'
          : 'Не удалось записаться: $e';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (message.contains('уже записаны')) {
        setState(() => _hasActiveBooking = true);
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Запись к врачу'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(color: PatientPalette.background),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClinicCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: PatientPalette.primary.withValues(
                              alpha: 0.12,
                            ),
                            child: Text(doctor.firstName[0].toUpperCase()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor.fullName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doctor.specialties.isNotEmpty
                                      ? doctor.specialties.join(', ')
                                      : 'Стоматолог',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 8),
                                PatientBadge(
                                  label:
                                      '${doctor.rating.toStringAsFixed(1)} · рейтинг',
                                  icon: Icons.star_rounded,
                                  variant: PatientBadgeVariant.warning,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: 'Скоро',
                              child: OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.call_outlined),
                                label: const Text('Аудио'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Tooltip(
                              message: 'Скоро',
                              child: OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.videocam_outlined),
                                label: const Text('Видео'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Tooltip(
                              message: 'Скоро',
                              child: OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Чат'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_services.length > 1) ...[
                  const SizedBox(height: 24),
                  const SectionHeader(
                    title: 'Выберите услугу',
                    subtitle: 'Можно поменять перед подтверждением',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _services
                        .map(
                          (service) => ChoiceChip(
                            label: Text(service),
                            selected: _selectedService == service,
                            onSelected: (_) =>
                                setState(() => _selectedService = service),
                            selectedColor: PatientPalette.primary,
                            labelStyle: TextStyle(
                              color: _selectedService == service
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                const SectionHeader(
                  title: 'Выберите дату',
                  subtitle: 'Доступные окна для записи',
                ),
                const SizedBox(height: 12),
                if (_isCheckingBooking)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                else if (_hasActiveBooking)
                  ClinicCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, color: PatientPalette.warning),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'У вас уже есть активная запись. Сначала отмените её в разделе «Записи».',
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: FutureBuilder<List<Slot>>(
                    future: _futureSlots,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Ошибка: ${snapshot.error}'));
                      }
                      final slots = snapshot.data ?? [];
                      if (slots.isEmpty) {
                        return const PatientEmptyState(
                          title: 'Нет свободных слотов',
                          message:
                              'Свяжитесь с администратором или попробуйте снова позже.',
                          icon: Icons.schedule_outlined,
                        );
                      }

                      final grouped = _groupSlotsByDate(slots);
                      final dates = grouped.keys.toList()..sort();
                      _selectedDate ??= dates.first;
                      final selectedKey = _selectedDate!;
                      final daySlots = grouped[selectedKey] ?? [];

                      if (_selectedSlot != null &&
                          !_sameDate(_selectedSlot!.startTime, selectedKey)) {
                        _selectedSlot = null;
                      }

                      return ListView(
                        children: [
                          SizedBox(
                            height: 86,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: dates.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final date = dates[index];
                                final isSelected = _sameDate(date, selectedKey);
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedDate = date),
                                  child: Container(
                                    width: 70,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? PatientPalette.primary
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: PatientPalette.background,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _shortWeekday(date),
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${date.day}',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          const SectionHeader(
                            title: 'Выберите время',
                            subtitle: 'Доступные слоты',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: daySlots
                                .map(
                                  (slot) => ChoiceChip(
                                    label: Text(_formatSlot(slot)),
                                    selected: _selectedSlot?.id == slot.id,
                                    onSelected: _hasActiveBooking
                                        ? null
                                        : (_) => setState(
                                            () => _selectedSlot = slot,
                                          ),
                                    selectedColor: PatientPalette.primary,
                                    labelStyle: TextStyle(
                                      color: _selectedSlot?.id == slot.id
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                      color: _selectedSlot?.id == slot.id
                                          ? Colors.transparent
                                          : PatientPalette.background,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: FilledButton(
          onPressed: _selectedSlot == null || _isBooking || _hasActiveBooking
              ? null
              : _bookSlot,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isBooking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _hasActiveBooking
                      ? 'Вы уже записаны'
                      : 'Записаться на выбранное время',
                ),
        ),
      ),
    );
  }

  Map<DateTime, List<Slot>> _groupSlotsByDate(List<Slot> slots) {
    final map = <DateTime, List<Slot>>{};
    for (final slot in slots) {
      final date = DateTime(
        slot.startTime.year,
        slot.startTime.month,
        slot.startTime.day,
      );
      map.putIfAbsent(date, () => []).add(slot);
    }
    return map;
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _shortWeekday(DateTime date) {
    const days = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    return days[date.weekday % 7];
  }

  String _formatSlot(Slot slot) {
    final start =
        '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}';
    final end =
        '${slot.endTime.hour.toString().padLeft(2, '0')}:${slot.endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }
}
