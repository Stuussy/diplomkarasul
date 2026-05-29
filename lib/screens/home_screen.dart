import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/appointment.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';
import '../widgets/dent_card.dart';
import '../widgets/dent_badge.dart';
import '../widgets/dent_shimmer.dart';
import '../widgets/patient_ui.dart';
import '../widgets/section_header.dart';
import 'appointment_request_screen.dart';
import 'doctor_detail_screen.dart';
import 'filter_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<AppUser>> _futureDoctors;
  late Future<Appointment?> _futureNextAppointment;
  String _selectedSpecialty = 'Все';
  String _searchQuery = '';
  String? _selectedSortOrder;
  double? _selectedMinRating;
  bool _instantBookingOnly = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _futureDoctors = _loadDoctors();
    _futureNextAppointment = _loadNextAppointment();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<AppUser>> _loadDoctors() {
    return context.read<SessionProvider>().apiService.fetchDoctors();
  }

  Future<Appointment?> _loadNextAppointment() async {
    try {
      final api = context.read<SessionProvider>().apiService;
      final now = DateTime.now();
      final appointments = await api.fetchAppointments(
        from: now,
        to: now.add(const Duration(days: 30)),
      );
      appointments.sort((a, b) => a.startTime.compareTo(b.startTime));
      final upcoming = appointments.where((a) =>
          a.status == 'scheduled' || a.status == 'confirmed');
      return upcoming.isNotEmpty ? upcoming.first : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _futureDoctors = _loadDoctors();
      _futureNextAppointment = _loadNextAppointment();
    });
  }

  void _openFilter() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterSheet(),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedSortOrder = result['sort'] as String?;
        _selectedMinRating = result['rating'] as double?;
        _instantBookingOnly = result['instantBooking'] as bool? ?? false;
      });
    }
  }

  List<AppUser> _applyFilters(List<AppUser> doctors) {
    var filtered = List<AppUser>.from(doctors);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((d) =>
          d.fullName.toLowerCase().contains(q) ||
          d.specialties.any((s) => s.toLowerCase().contains(q))).toList();
    }

    if (_selectedSpecialty != 'Все') {
      filtered = filtered.where((d) =>
          d.specialties.any((s) => s.toLowerCase().contains(
              _selectedSpecialty.toLowerCase()))).toList();
    }

    if (_selectedMinRating != null) {
      filtered = filtered.where((d) => d.rating >= _selectedMinRating!).toList();
    }

    if (_selectedSortOrder == 'rating') {
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_selectedSortOrder == 'reviews') {
      filtered.sort((a, b) => b.reviews.compareTo(a.reviews));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final user = context.watch<SessionProvider>().user;
    final greeting = _greeting();

    return DecoratedBox(
      decoration: const BoxDecoration(color: ClinicTheme.mist),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.firstName ?? 'Пользователь',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: ClinicTheme.heroGradient,
                          ),
                          child: Center(
                            child: Text(
                              _initials(user),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Search bar
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: ClinicTheme.snow,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: ClinicTheme.shadowSm,
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: s.homeSearchDoctors,
                          prefixIcon: const Icon(LucideIcons.search, size: 20, color: ClinicTheme.slate),
                          suffixIcon: GestureDetector(
                            onTap: _openFilter,
                            child: Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: ClinicTheme.azureSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                LucideIcons.slidersHorizontal,
                                size: 18,
                                color: ClinicTheme.azure,
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Upcoming appointment
                    FutureBuilder<Appointment?>(
                      future: _futureNextAppointment,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const DentShimmerCard(height: 120);
                        }
                        final appointment = snapshot.data;
                        if (appointment == null) {
                          return DentCard(
                            gradient: ClinicTheme.heroGradient,
                            borderRadius: ClinicTheme.radiusL,
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    LucideIcons.calendarPlus,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.homeNoAppointmentTitle,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        s.homeNoAppointmentSubtitle,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return DentCard(
                          gradient: ClinicTheme.heroGradient,
                          borderRadius: ClinicTheme.radiusL,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(LucideIcons.calendarCheck, color: Colors.white70, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    s.homeNextVisitLabel,
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: Colors.white70,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                appointment.service,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_formatDate(appointment.startTime)} • ${appointment.doctor?.fullName ?? ''}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Specialty chips
                    SizedBox(
                      height: 40,
                      child: FutureBuilder<List<AppUser>>(
                        future: _futureDoctors,
                        builder: (context, snapshot) {
                          final specialties = _extractSpecialties(snapshot.data ?? []);
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: specialties.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final spec = specialties[index];
                              final selected = spec == _selectedSpecialty;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedSpecialty = spec);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected ? ClinicTheme.azure : ClinicTheme.snow,
                                    borderRadius: BorderRadius.circular(20),
                                    border: selected ? null : Border.all(color: ClinicTheme.mist),
                                  ),
                                  child: Text(
                                    spec == 'Все' ? s.filterAll : spec,
                                    style: TextStyle(
                                      color: selected ? Colors.white : ClinicTheme.midnight,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                    SectionHeader(
                      title: s.homeSectionBestDoctors,
                      subtitle: s.homeSectionSubtitle,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Doctor list
            FutureBuilder<List<AppUser>>(
              future: _futureDoctors,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: DentShimmerCard(height: 140),
                        ),
                        childCount: 3,
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('Ошибка: ${snapshot.error}'),
                      ),
                    ),
                  );
                }
                final doctors = _applyFilters(snapshot.data ?? []);
                if (doctors.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: PatientEmptyState(
                        title: s.homeNoDoctors,
                        message: _searchQuery.isNotEmpty
                            ? 'Попробуйте другой запрос'
                            : 'Скоро добавим новых специалистов',
                        icon: LucideIcons.stethoscope,
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 110 + MediaQuery.of(context).padding.bottom),
                  sliver: SliverList.separated(
                    itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      return _DoctorTile(
                        doctor: doctor,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DoctorDetailScreen(doctor: doctor),
                          ),
                        ),
                        onBook: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AppointmentRequestScreen(doctor: doctor),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemCount: doctors.length,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Доброе утро 👋';
    if (hour < 17) return 'Добрый день 👋';
    return 'Добрый вечер 👋';
  }

  String _initials(AppUser? user) {
    if (user == null) return '?';
    final f = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final l = user.lastName.isNotEmpty ? user.lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$day.$month • $time';
  }

  List<String> _extractSpecialties(List<AppUser> doctors) {
    final set = <String>{'Все'};
    for (final d in doctors) {
      set.addAll(d.specialties);
    }
    return set.toList();
  }
}

class _DoctorTile extends StatelessWidget {
  const _DoctorTile({
    required this.doctor,
    required this.onTap,
    required this.onBook,
  });

  final AppUser doctor;
  final VoidCallback onTap;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final specialty = doctor.specialties.isNotEmpty
        ? doctor.specialties.join(', ')
        : s.homeSpecialties;

    return DentCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: ClinicTheme.azure.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
                ),
                child: Center(
                  child: Text(
                    doctor.firstName.isNotEmpty
                        ? doctor.firstName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 22,
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
                      doctor.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialty,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: ClinicTheme.slate,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              DentBadge(
                label: doctor.rating.toStringAsFixed(1),
                icon: LucideIcons.star,
                variant: DentBadgeVariant.warning,
              ),
              const SizedBox(width: 8),
              Text(
                '${doctor.reviews} отзывов',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              FilledButton(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(s.homeBook),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
