import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

const _twoGisWebUrl =
    'https://2gis.kz/astana/search/%D1%81%D1%82%D0%BE%D0%BC%D0%BE%D1%82%D0%BE%D0%BB%D0%BE%D0%B3%D0%B8%D1%8F/filters/sort%3Drating/firm/70000001041371459?m=71.421132%2C51.123988%2F18&immersive=on';
const _twoGisDeepLink = 'dgis://2gis.ru/firm/70000001041371459';
// Yandex Navi / Taxi deep link to clinic location (Astana)
const _taxiDeepLink = 'yandexnavi://build_route_on_map?lat=51.1694&lon=71.4491';
const _taxiWebUrl = 'https://taxi.yandex.ru/route/?end-lat=51.1694&end-lon=71.4491';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<List<AppUser>> _futureDoctors;
  bool _isOpeningMap = false;
  bool _isOpeningTaxi = false;

  @override
  void initState() {
    super.initState();
    _futureDoctors = context.read<SessionProvider>().apiService.fetchDoctors();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureDoctors = context.read<SessionProvider>().apiService.fetchDoctors();
    });
  }

  Future<void> _callTaxi() async {
    if (_isOpeningTaxi) return;
    setState(() => _isOpeningTaxi = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      bool opened = false;
      try {
        opened = await launchUrl(Uri.parse(_taxiDeepLink), mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
      if (!opened) {
        opened = await launchUrl(Uri.parse(_taxiWebUrl), mode: LaunchMode.externalApplication);
      }
      if (!opened && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось открыть Яндекс Такси.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningTaxi = false);
    }
  }

  Future<void> _openClinicLocation() async {
    if (_isOpeningMap) return;
    setState(() => _isOpeningMap = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final deepLink = Uri.parse(_twoGisDeepLink);
      final webLink = Uri.parse(_twoGisWebUrl);
      bool opened = false;
      try {
        opened = await launchUrl(deepLink, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
      if (!opened) {
        opened = await launchUrl(webLink, mode: LaunchMode.externalApplication);
      }
      if (!opened && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось открыть карту. Проверьте установку 2GIS.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningMap = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<SessionProvider>().user?.role ?? 'patient';
    final isPatient = role == 'patient';

    return DecoratedBox(
      decoration: const BoxDecoration(color: ClinicTheme.mist),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: DentCard(
              gradient: ClinicTheme.heroGradient,
              borderRadius: ClinicTheme.radiusL,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Dental AI на карте',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Постройте маршрут в 2GIS и рассчитайте время в пути до клиники.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _isOpeningMap ? null : _openClinicLocation,
                        icon: const Icon(LucideIcons.navigation, size: 16),
                        label: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _isOpeningMap ? 'Открываем…' : 'Открыть 2GIS',
                            key: ValueKey(_isOpeningMap),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: ClinicTheme.azure,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isOpeningTaxi ? null : _callTaxi,
                        icon: const Icon(LucideIcons.car, size: 16),
                        label: Text(_isOpeningTaxi ? 'Загрузка…' : 'Вызвать такси'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SectionHeader(
              title: 'Команда клиники',
              subtitle: 'Выберите врача и запишитесь онлайн',
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AppUser>>(
              future: _futureDoctors,
              builder: (context, snapshot) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildDoctorsList(snapshot, isPatient),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsList(AsyncSnapshot<List<AppUser>> snapshot, bool isPatient) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: const [
          SizedBox(height: 16),
          DentShimmerCard(height: 140),
          SizedBox(height: 16),
          DentShimmerCard(height: 140),
        ],
      );
    }
    if (snapshot.hasError) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text('Ошибка: ${snapshot.error}')),
        ],
      );
    }
    final doctors = snapshot.data ?? [];
    if (doctors.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          PatientEmptyState(
            title: 'Нет доступных врачей',
            message: 'Скоро добавим новых специалистов.',
            icon: LucideIcons.stethoscope,
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: doctors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final doctor = doctors[index];
        final specialty = doctor.specialties.isNotEmpty
            ? doctor.specialties.join(', ')
            : 'Специализация уточняется';
        return DentCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DoctorDetailScreen(doctor: doctor)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: ClinicTheme.azure.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        doctor.firstName.isNotEmpty ? doctor.firstName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ClinicTheme.azure),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doctor.fullName, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(specialty, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, color: ClinicTheme.slate, size: 20),
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
                  Text('${doctor.reviews} отзывов', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              if (isPatient) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AppointmentRequestScreen(doctor: doctor)),
                      ),
                      child: const Text('Записаться'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isOpeningMap ? null : _openClinicLocation,
                      icon: const Icon(LucideIcons.navigation, size: 16),
                      label: const Text('Маршрут'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final fullStars = value.floor();
    final half = value - fullStars >= 0.5;
    return Row(
      children: List.generate(5, (index) {
        Color color;
        if (index < fullStars || (index == fullStars && half)) {
          color = ClinicTheme.amber;
        } else {
          color = ClinicTheme.mist;
        }
        return Icon(LucideIcons.star, color: color, size: 18);
      }),
    );
  }
}
