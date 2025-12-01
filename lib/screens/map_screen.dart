import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user.dart';
import '../providers/session_provider.dart';
import '../widgets/patient_ui.dart';
import 'appointment_request_screen.dart';
import 'doctor_detail_screen.dart';

const _twoGisWebUrl =
    'https://2gis.kz/astana/search/%D1%81%D1%82%D0%BE%D0%BC%D0%BE%D1%82%D0%BE%D0%BB%D0%BE%D0%B3%D0%B8%D1%8F/filters/sort%3Drating/firm/70000001041371459?m=71.421132%2C51.123988%2F18&immersive=on';
const _twoGisDeepLink = 'dgis://2gis.ru/firm/70000001041371459';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<List<AppUser>> _futureDoctors;
  bool _isOpeningMap = false;

  @override
  void initState() {
    super.initState();
    _futureDoctors = context.read<SessionProvider>().apiService.fetchDoctors();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureDoctors = context
          .read<SessionProvider>()
          .apiService
          .fetchDoctors();
    });
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
        opened = await launchUrl(
          deepLink,
          mode: LaunchMode.externalApplication,
        );
        if (opened) {
          debugPrint('2GIS deep link opened');
        }
      } catch (_) {
        opened = false;
      }

      if (!opened) {
        opened = await launchUrl(webLink, mode: LaunchMode.externalApplication);
        if (opened) {
          debugPrint('2GIS web link opened');
        }
      }

      if (!opened && mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось открыть карту. Проверьте установку 2GIS.',
            ),
          ),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7F9FC), Color(0xFFEFF3FA)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: PatientCard(
              gradient: PatientPalette.hero,
              color: PatientPalette.primary,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dental AI на карте',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Нажмите, чтобы построить маршрут в 2GIS и рассчитать время в пути до клиники.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _isOpeningMap ? null : _openClinicLocation,
                        icon: const Icon(Icons.map_outlined),
                        label: Text(
                          _isOpeningMap ? 'Открываем…' : 'Открыть 2GIS',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: PatientPalette.primary,
                        ),
                      ),
                      TextButton(
                        onPressed: _isOpeningMap ? null : _openClinicLocation,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Поделиться адресом'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: PatientSectionTitle(
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

  Widget _buildDoctorsList(
    AsyncSnapshot<List<AppUser>> snapshot,
    bool canContactSupport,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (snapshot.hasError) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 200),
          Center(child: Text('Ошибка: ${snapshot.error}')),
        ],
      );
    }
    final doctors = snapshot.data ?? [];
    if (doctors.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          PatientEmptyState(
            title: 'Нет доступных врачей',
            message:
                'Скоро добавим новых специалистов. Попробуйте обновить позже.',
            icon: Icons.health_and_safety_outlined,
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: doctors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final doctor = doctors[index];
        return _DoctorCard(
          doctor: doctor,
          canContactSupport: canContactSupport,
          onOpenDetail: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DoctorDetailScreen(doctor: doctor),
              ),
            );
          },
          onOpenMap: _isOpeningMap ? null : _openClinicLocation,
        );
      },
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.canContactSupport,
    required this.onOpenDetail,
    required this.onOpenMap,
  });

  final AppUser doctor;
  final bool canContactSupport;
  final VoidCallback onOpenDetail;
  final Future<void> Function()? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final specialty = doctor.specialties.isNotEmpty
        ? doctor.specialties.join(', ')
        : 'Специализация уточняется';
    final clinicLabel = doctor.clinics.isNotEmpty
        ? doctor.clinics.join(', ')
        : 'Наша клиника';

    return PatientCard(
      margin: const EdgeInsets.only(bottom: 0),
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
                      specialty,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            clinicLabel,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                    if (doctor.phone != null && doctor.phone!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            doctor.phone!,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpenDetail,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              PatientBadge(
                label: doctor.rating.toStringAsFixed(1),
                icon: Icons.star_rate_rounded,
                variant: PatientBadgeVariant.warning,
              ),
              const SizedBox(width: 8),
              Text(
                '${doctor.reviews} отзывов',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (canContactSupport)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppointmentRequestScreen(doctor: doctor),
                    ),
                  ),
                  child: const Text('Записаться'),
                ),
                OutlinedButton(
                  onPressed: onOpenDetail,
                  child: const Text('Профиль'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenMap == null ? null : () => onOpenMap!(),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Маршрут'),
                ),
              ],
            )
          else
            const Text(
              'Запись пациентов выполняется через мобильное приложение.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
        ],
      ),
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
        if (index < fullStars) {
          return Icon(Icons.star, color: Colors.orange.shade400, size: 18);
        } else if (index == fullStars && half) {
          return Icon(Icons.star_half, color: Colors.orange.shade400, size: 18);
        }
        return Icon(Icons.star_border, color: Colors.orange.shade200, size: 18);
      }),
    );
  }
}
