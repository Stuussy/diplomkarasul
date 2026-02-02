import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import '../widgets/patient_ui.dart';
import '../widgets/section_header.dart';
import '../widgets/clinic_card.dart';
import 'appointment_request_screen.dart';
import 'doctor_detail_screen.dart';
import 'filter_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Appointment? _nextAppointment;
  String? _aiTip;
  bool _loading = true;
  late Future<List<AppUser>> _futureDoctors;
  final List<String> _specialties = const [
    'Все',
    'Терапия',
    'Эстетика',
    'Хирургия',
    'Ортодонтия',
    'Детская',
  ];
  int _activeSpecialty = 0;
  _DoctorFilters _filters = const _DoctorFilters();

  @override
  void initState() {
    super.initState();
    _futureDoctors = context.read<SessionProvider>().apiService.fetchDoctors();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final api = context.read<SessionProvider>().apiService;
    try {
      final appointment = await api.fetchNextAppointment();
      final tip = await api.fetchAiTip();
      if (mounted) {
        setState(() {
          _nextAppointment = appointment;
          _aiTip = tip;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить данные: $error')),
      );
    }
  }

  Future<void> _refreshDoctors() async {
    setState(() {
      _futureDoctors = context
          .read<SessionProvider>()
          .apiService
          .fetchDoctors();
    });
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FilterSheet(
        specialties: _specialties,
        selectedSpecialty: _filters.specialty,
        minRating: _filters.minRating,
        maxDistance: _filters.maxDistance,
        instantBookOnly: _filters.instantBookOnly,
      ),
    );
    if (result == null) return;
    setState(() {
      _filters = _filters.copyWith(
        specialty: result['specialty'] as String?,
        minRating: (result['rating'] as double?) ?? _filters.minRating,
        maxDistance: (result['distance'] as double?) ?? _filters.maxDistance,
        instantBookOnly: result['instantBook'] as bool?,
      );
      final index = _specialties.indexOf(_filters.specialty);
      _activeSpecialty = index >= 0 ? index : 0;
    });
  }

  void _resetFilters() {
    setState(() {
      _filters = const _DoctorFilters();
      _activeSpecialty = 0;
    });
  }

  void _onSpecialtySelected(int index) {
    setState(() {
      _activeSpecialty = index;
      _filters = _filters.copyWith(specialty: _specialties[index]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PatientPalette.background,
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadData();
          await _refreshDoctors();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _TopBar(userName: user?.firstName ?? 'Пациент'),
                    const SizedBox(height: 20),
                    _SearchBar(
                      onFilter: _openFilterSheet,
                      hasFilters: _filters.hasActiveFilters,
                    ),
                    const SizedBox(height: 24),
                    _UpcomingCard(
                      appointment: _nextAppointment,
                      loading: _loading,
                    ),
                    const SizedBox(height: 24),
                    _SpecialtyScroller(
                      specialties: _specialties,
                      selectedIndex: _activeSpecialty,
                      onChanged: _onSpecialtySelected,
                    ),
                    if (_aiTip != null) ...[
                      const SizedBox(height: 24),
                      _AiTipCard(tip: _aiTip!),
                    ],
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: 'Лучшие врачи',
                      subtitle: 'Подобраны под ваш запрос',
                      actionLabel: _filters.hasActiveFilters ? 'Сбросить' : null,
                      onAction: _filters.hasActiveFilters ? _resetFilters : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverToBoxAdapter(
                child: FutureBuilder<List<AppUser>>(
                  future: _futureDoctors,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return ClinicCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Не удалось загрузить врачей',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('Ошибка: ${snapshot.error}'),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: _refreshDoctors,
                              child: const Text('Попробовать ещё раз'),
                            ),
                          ],
                        ),
                      );
                    }
                    final doctors = snapshot.data ?? [];
                    if (doctors.isEmpty) {
                      return PatientEmptyState(
                        title: 'Нет доступных врачей',
                        message:
                            'Свяжитесь с администратором или обновите список чуть позже.',
                        action: FilledButton(
                          onPressed: _refreshDoctors,
                          child: const Text('Обновить'),
                        ),
                      );
                    }
                    final filteredDoctors = doctors
                        .where(_filters.matches)
                        .toList();
                    if (filteredDoctors.isEmpty) {
                      return PatientEmptyState(
                        title: 'Нет врачей по заданным критериям',
                        message:
                            'Попробуйте изменить фильтры или выберите другую специализацию.',
                        action: FilledButton.tonal(
                          onPressed: _resetFilters,
                          child: const Text('Сбросить фильтры'),
                        ),
                      );
                    }
                    return Column(
                      children: filteredDoctors
                          .map(
                            (doctor) => _DoctorTile(
                              doctor: doctor,
                              onOpened: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DoctorDetailScreen(doctor: doctor),
                                  ),
                                );
                              },
                              onBook: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AppointmentRequestScreen(
                                      doctor: doctor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorFilters {
  const _DoctorFilters({
    this.specialty = 'Все',
    this.minRating = 0,
    this.maxDistance = 50,
    this.instantBookOnly = false,
  });

  final String specialty;
  final double minRating;
  final double maxDistance;
  final bool instantBookOnly;

  _DoctorFilters copyWith({
    String? specialty,
    double? minRating,
    double? maxDistance,
    bool? instantBookOnly,
  }) {
    return _DoctorFilters(
      specialty: specialty ?? this.specialty,
      minRating: minRating ?? this.minRating,
      maxDistance: maxDistance ?? this.maxDistance,
      instantBookOnly: instantBookOnly ?? this.instantBookOnly,
    );
  }

  bool matches(AppUser doctor) {
    final normalized = specialty.trim().toLowerCase();
    final matchesSpecialty =
        normalized == 'все' ||
        doctor.specialties.any(
          (spec) => spec.toLowerCase().contains(normalized),
        );
    final ratingOk = doctor.rating >= minRating;
    final instantOk = !instantBookOnly || doctor.services.isNotEmpty;
    return matchesSpecialty && ratingOk && instantOk;
  }

  bool get hasActiveFilters =>
      specialty != 'Все' || minRating > 0 || instantBookOnly;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Добрый день, ${userName.isEmpty ? 'пациент' : userName}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Частная стоматология · Алматы',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 26,
          backgroundColor: PatientPalette.primary.withValues(alpha: 0.12),
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'P',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: PatientPalette.primary),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onFilter, required this.hasFilters});

  final VoidCallback onFilter;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Найти врача или услугу',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onFilter,
                icon: const Icon(Icons.tune_rounded),
              ),
              if (hasFilters)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: PatientPalette.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.appointment, required this.loading});

  final Appointment? appointment;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      gradient: PatientPalette.muted(0.14),
      background: PatientPalette.background,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: PatientPalette.primary.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text('Ближайший визит', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          else if (appointment == null)
            Text(
              'Запланируйте визит, чтобы держать профилактику под контролем.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else ...[
            Text(
              appointment!.service,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(appointment!.startTime),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              appointment!.doctor?.fullName ?? 'Врач уточняется',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$day.$month.${date.year} · $time';
  }
}

class _SpecialtyScroller extends StatelessWidget {
  const _SpecialtyScroller({
    required this.specialties,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> specialties;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: specialties.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(specialties[index]),
            selected: selected,
            onSelected: (_) => onChanged(index),
            selectedColor: PatientPalette.primary,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? Colors.transparent : PatientPalette.background,
            ),
          );
        },
      ),
    );
  }
}

class _AiTipCard extends StatelessWidget {
  const _AiTipCard({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    return ClinicCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PatientPalette.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: PatientPalette.warning,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Совет от Dental AI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(tip, style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorTile extends StatelessWidget {
  const _DoctorTile({
    required this.doctor,
    required this.onOpened,
    required this.onBook,
  });

  final AppUser doctor;
  final VoidCallback onOpened;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final subtitle = doctor.specialties.isNotEmpty
        ? doctor.specialties.join(', ')
        : 'Стоматолог';
    final location = doctor.clinics.isNotEmpty
        ? doctor.clinics.join(', ')
        : 'Dental AI Clinic';
    return ClinicCard(
      margin: const EdgeInsets.only(bottom: 16),
      onTap: onOpened,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: PatientPalette.primary.withValues(alpha: 0.12),
                child: Text(
                  doctor.firstName.isNotEmpty
                      ? doctor.firstName[0].toUpperCase()
                      : doctor.lastName.isNotEmpty
                      ? doctor.lastName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpened,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: PatientPalette.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      doctor.rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${doctor.reviews} отзывов',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Записаться'),
              ),
              OutlinedButton(
                onPressed: onOpened,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Подробнее'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
