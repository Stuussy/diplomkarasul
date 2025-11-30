import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/slot.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';

class AppointmentRequestScreen extends StatefulWidget {
  const AppointmentRequestScreen({super.key, required this.doctor});

  final AppUser doctor;

  @override
  State<AppointmentRequestScreen> createState() => _AppointmentRequestScreenState();
}

class _AppointmentRequestScreenState extends State<AppointmentRequestScreen> {
  late Future<List<Slot>> _futureSlots;
  Slot? _selectedSlot;
  late String _selectedService;
  bool _isBooking = false;
  bool _isCheckingBooking = true;
  bool _hasActiveBooking = false;

  @override
  void initState() {
    super.initState();
    final api = context.read<SessionProvider>().apiService;
    _futureSlots = api.fetchSlots(doctorId: widget.doctor.id, status: 'available');
    _selectedService = widget.doctor.specialties.isNotEmpty
        ? widget.doctor.specialties.first
        : 'Консультация';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBookingState());
  }

  Future<void> _loadBookingState() async {
    final api = context.read<SessionProvider>().apiService;
    try {
      final appointments = await api.fetchAppointments();
      final hasActive = appointments
          .where((app) => app.status == 'scheduled' || app.status == 'confirmed')
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запись подтверждена.')),
      );
      setState(() => _hasActiveBooking = true);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('already')
          ? 'Вы уже записаны. Сначала отмените текущую запись.'
          : 'Не удалось записаться: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      appBar: AppBar(title: const Text('Запрос записи')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Text(doctor.firstName[0].toUpperCase()),
              ),
              title: Text(doctor.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                doctor.specialties.isNotEmpty ? doctor.specialties.join(', ') : 'Стоматолог',
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            if (doctor.specialties.isNotEmpty) ...[
              Text('Выберите услугу', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _selectedService,
                items: doctor.specialties
                    .map((spec) => DropdownMenuItem(value: spec, child: Text(spec)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedService = value);
                },
              ),
              const SizedBox(height: 16),
            ],
            Text('Свободные слоты', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
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
                    return const Center(child: Text('Нет доступных слотов. Свяжитесь с администратором.'));
                  }
                  final grouped = _groupSlotsByDate(slots);
                  return ListView(
                    children: grouped.entries.map((entry) {
                      final date = entry.key;
                      final daySlots = entry.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              date,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: daySlots.map((slot) {
                              final selected = _selectedSlot?.id == slot.id;
                              return ChoiceChip(
                                label: Text(_formatSlot(slot)),
                                selected: selected,
                                onSelected: (_) => setState(() => _selectedSlot = slot),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_isCheckingBooking)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (_hasActiveBooking)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Вы уже записаны. Чтобы выбрать другое время, отмените текущую запись.',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed:
                  _selectedSlot == null || _isBooking || _hasActiveBooking ? null : _bookSlot,
              child: _isBooking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_hasActiveBooking ? 'Вы уже записаны' : 'Записаться на выбранное время'),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<Slot>> _groupSlotsByDate(List<Slot> slots) {
    final map = <String, List<Slot>>{};
    for (final slot in slots) {
      final date = '${slot.startTime.day.toString().padLeft(2, '0')}.'
          '${slot.startTime.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(date, () => []).add(slot);
    }
    return map;
  }

  String _formatSlot(Slot slot) {
    final start =
        '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}';
    final end =
        '${slot.endTime.hour.toString().padLeft(2, '0')}:${slot.endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }
}
