import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user.dart';
import '../providers/session_provider.dart';
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
      _futureDoctors = context.read<SessionProvider>().apiService.fetchDoctors();
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
        opened = await launchUrl(
          webLink,
          mode: LaunchMode.externalApplication,
        );
        if (opened) {
          debugPrint('2GIS web link opened');
        }
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

    return Column(
      children: [
        Container(
          height: 180,
          color: Colors.grey[300],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Карта доступна в 2GIS. Откройте, чтобы построить маршрут до клиники.',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isOpeningMap ? null : _openClinicLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(_isOpeningMap ? 'Открываем...' : 'Открыть в 2GIS'),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Выберите врача для записи',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AppUser>>(
            future: _futureDoctors,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Ошибка: ${snapshot.error}'));
              }

              final doctors = snapshot.data ?? [];
              if (doctors.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Пока нет доступных врачей')),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    return _DoctorCard(
                      doctor: doctor,
                      canContactSupport: isPatient,
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
                ),
              );
            },
          ),
        ),
      ],
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
    final clinicLabel = doctor.clinics.isNotEmpty ? doctor.clinics.join(', ') : 'Наша клиника';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(doctor.firstName.isNotEmpty
                      ? doctor.firstName[0].toUpperCase()
                      : doctor.lastName.isNotEmpty
                          ? doctor.lastName[0].toUpperCase()
                          : '?'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.fullName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        specialty,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    clinicLabel,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
            if (doctor.phone != null && doctor.phone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 18, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(doctor.phone!),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 32),
            Row(
              children: [
                StarRating(value: doctor.rating),
                const SizedBox(width: 8),
                Text('${doctor.rating.toStringAsFixed(1)} · ${doctor.reviews} отзывов',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            if (canContactSupport)
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: onOpenDetail,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Профиль'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AppointmentRequestScreen(doctor: doctor),
                      ),
                    ),
                    child: const Text('Записаться'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onOpenMap == null ? null : () => onOpenMap!(),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('2GIS'),
                  ),
                ],
              )
            else
              const Text(
                'Запись пациентов выполняется через мобильное приложение.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
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
