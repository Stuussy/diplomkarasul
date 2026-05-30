import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/appointment.dart';
import '../theme/clinic_theme.dart';

/// Переиспользуемый календарь записей.
/// Показывает месяц с метками-точками на днях, где есть записи, и список
/// записей на выбранный день (через [itemBuilder]).
class AppointmentCalendar extends StatefulWidget {
  const AppointmentCalendar({
    super.key,
    required this.appointments,
    required this.itemBuilder,
    this.header,
    this.emptyDayTitle = 'На этот день записей нет',
    this.emptyDayIcon = Icons.event_busy_outlined,
    this.listPadding = const EdgeInsets.fromLTRB(16, 4, 16, 24),
  });

  final List<Appointment> appointments;
  final Widget Function(BuildContext context, Appointment appointment) itemBuilder;

  /// Необязательный виджет над календарём (напр. фильтр по врачу).
  final Widget? header;
  final String emptyDayTitle;
  final IconData emptyDayIcon;
  final EdgeInsets listPadding;

  @override
  State<AppointmentCalendar> createState() => _AppointmentCalendarState();
}

class _AppointmentCalendarState extends State<AppointmentCalendar> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _format = CalendarFormat.month;

  static DateTime _dayKey(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now;
    // Если на сегодня записей нет, но есть ближайшая будущая — встанем на неё.
    _selectedDay = _pickInitialDay(now);
    _focusedDay = _selectedDay;
  }

  DateTime _pickInitialDay(DateTime now) {
    final today = _dayKey(now);
    final hasToday = widget.appointments.any((a) => _dayKey(a.startTime) == today);
    if (hasToday || widget.appointments.isEmpty) return now;
    final upcoming = widget.appointments
        .where((a) => a.startTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (upcoming.isNotEmpty) return upcoming.first.startTime;
    return now;
  }

  List<Appointment> _eventsForDay(DateTime day) {
    final key = _dayKey(day);
    final list = widget.appointments
        .where((a) => _dayKey(a.startTime) == key)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return ClinicTheme.mint;
      case 'completed':
        return ClinicTheme.azure;
      case 'cancelled':
      case 'no_show':
        return ClinicTheme.coral;
      default:
        return ClinicTheme.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = _eventsForDay(_selectedDay);
    final allDates = widget.appointments.map((a) => a.startTime).toList();
    final firstDay = allDates.isEmpty
        ? DateTime.now().subtract(const Duration(days: 365))
        : allDates.reduce((a, b) => a.isBefore(b) ? a : b).subtract(const Duration(days: 7));
    final lastDay = allDates.isEmpty
        ? DateTime.now().add(const Duration(days: 365))
        : allDates.reduce((a, b) => a.isAfter(b) ? a : b).add(const Duration(days: 7));

    return Column(
      children: [
        if (widget.header != null) widget.header!,
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: ClinicTheme.snow,
            borderRadius: BorderRadius.circular(ClinicTheme.radiusL),
            boxShadow: [
              BoxShadow(
                color: ClinicTheme.midnight.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: TableCalendar<Appointment>(
            locale: 'ru_RU',
            firstDay: firstDay,
            lastDay: lastDay,
            focusedDay: _focusedDay,
            calendarFormat: _format,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Месяц',
              CalendarFormat.twoWeeks: '2 недели',
              CalendarFormat.week: 'Неделя',
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _eventsForDay,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onFormatChanged: (format) => setState(() => _format = format),
            onPageChanged: (focused) => _focusedDay = focused,
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonShowsNext: false,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ClinicTheme.midnight,
              ),
              formatButtonDecoration: BoxDecoration(
                color: ClinicTheme.azureSoft,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              formatButtonTextStyle: TextStyle(
                color: ClinicTheme.azure,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: ClinicTheme.slate),
              rightChevronIcon: Icon(Icons.chevron_right, color: ClinicTheme.slate),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: ClinicTheme.slate, fontWeight: FontWeight.w600, fontSize: 12),
              weekendStyle: TextStyle(color: ClinicTheme.coral, fontWeight: FontWeight.w600, fontSize: 12),
            ),
            calendarStyle: CalendarStyle(
              isTodayHighlighted: true,
              todayDecoration: BoxDecoration(
                color: ClinicTheme.azureSoft,
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(color: ClinicTheme.azure, fontWeight: FontWeight.w700),
              selectedDecoration: const BoxDecoration(
                color: ClinicTheme.azure,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              weekendTextStyle: const TextStyle(color: ClinicTheme.midnight),
              outsideTextStyle: TextStyle(color: ClinicTheme.slate.withValues(alpha: 0.4)),
              markersMaxCount: 4,
              markersAlignment: Alignment.bottomCenter,
            ),
            calendarBuilders: CalendarBuilders<Appointment>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: events.take(4).map((e) {
                      return Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 0.8),
                        decoration: BoxDecoration(
                          color: _statusColor(e.status),
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
        // Заголовок выбранного дня
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              const Icon(Icons.event_note_outlined, size: 18, color: ClinicTheme.azure),
              const SizedBox(width: 8),
              Text(
                _formatHeaderDate(_selectedDay),
                style: const TextStyle(fontWeight: FontWeight.w700, color: ClinicTheme.midnight),
              ),
              const Spacer(),
              if (dayEvents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: ClinicTheme.azureSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${dayEvents.length}',
                    style: const TextStyle(
                        color: ClinicTheme.azure, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: dayEvents.isEmpty
              ? _emptyDay()
              : ListView.separated(
                  padding: widget.listPadding,
                  itemCount: dayEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => widget.itemBuilder(context, dayEvents[i]),
                ),
        ),
      ],
    );
  }

  Widget _emptyDay() => ListView(
        children: [
          const SizedBox(height: 40),
          Icon(widget.emptyDayIcon, size: 44, color: ClinicTheme.slate.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Center(
            child: Text(widget.emptyDayTitle,
                style: const TextStyle(color: ClinicTheme.slate, fontSize: 14)),
          ),
        ],
      );

  String _formatHeaderDate(DateTime d) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    const weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    return '${d.day} ${months[d.month - 1]}, ${weekdays[d.weekday - 1]}';
  }
}
