import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import 'appointment_request_screen.dart';
import 'filter_sheet.dart';
import 'doctor_detail_screen.dart';

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
      _futureDoctors = context.read<SessionProvider>().apiService.fetchDoctors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
        await _refreshDoctors();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TopBar(userName: user?.firstName ?? 'Пациент'),
          const SizedBox(height: 16),
          _SearchBar(onFilter: () {
            showModalBottomSheet<Map<String, dynamic>>(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => const FilterSheet(),
            );
          }),
          const SizedBox(height: 20),
          _UpcomingCard(appointment: _nextAppointment, loading: _loading),
          const SizedBox(height: 20),
          _SpecialtyScroller(),
          const SizedBox(height: 16),
          if (_aiTip != null) _AiTipCard(tip: _aiTip!),
          const SizedBox(height: 16),
          const _SectionHeader(title: 'Лучшие врачи', actionLabel: 'Смотреть все'),
          const SizedBox(height: 8),
          FutureBuilder<List<AppUser>>(
            future: _futureDoctors,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Ошибка: ${snapshot.error}'));
              }
              final doctors = snapshot.data ?? [];
              if (doctors.isEmpty) {
                return const Center(child: Text('Пока нет доступных врачей'));
              }
              return Column(
                children: doctors
                    .map(
                      (doctor) => _DoctorTile(
                        doctor: doctor,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DoctorDetailScreen(doctor: doctor),
                  ),
                          );
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Локация', style: TextStyle(color: Colors.grey)),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: Colors.blue),
                const SizedBox(width: 4),
                const Text('Астана, Казахстан',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        const Spacer(),
        CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'P'),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onFilter});

  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Найти врача или услугу',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: onFilter,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.tune, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.appointment, required this.loading});

  final Appointment? appointment;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Ближайшая запись',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const CircularProgressIndicator(color: Colors.white)
          else if (appointment == null)
            const Text(
              'У вас пока нет предстоящих посещений.\nВыберите врача, чтобы запланировать визит.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            )
          else
            Builder(builder: (context) {
              final appt = appointment;
              if (appt == null) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appt.service,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(appt.startTime),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appt.doctor?.fullName ?? 'Врач уточняется',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              );
            }),
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
  @override
  Widget build(BuildContext context) {
    final specialties = ['Все', 'Терапевт', 'Хирург', 'Ортодонт', 'Гигиенист', 'Детский'];
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final active = index == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: active ? Colors.blue : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Text(
              specialties[index],
              style: TextStyle(color: active ? Colors.white : Colors.black87),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: specialties.length,
      ),
    );
  }
}

class _AiTipCard extends StatelessWidget {
  const _AiTipCard({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lightbulb_outline, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Совет от Dental AI',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionLabel});

  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        TextButton(onPressed: () {}, child: Text(actionLabel)),
      ],
    );
  }
}

class _DoctorTile extends StatelessWidget {
  const _DoctorTile({required this.doctor, required this.onTap});

  final AppUser doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = doctor.specialties.isNotEmpty
        ? doctor.specialties.join(', ')
        : 'Стоматолог';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.blue.shade50,
              child: Text(
                doctor.firstName.isNotEmpty
                    ? doctor.firstName[0].toUpperCase()
                    : doctor.lastName.isNotEmpty
                        ? doctor.lastName[0].toUpperCase()
                        : '?',
                style: const TextStyle(fontSize: 24, color: Colors.blue),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange.shade400, size: 18),
                      const SizedBox(width: 4),
                      Text(doctor.rating.toStringAsFixed(1)),
                      const SizedBox(width: 4),
                      Text('(${doctor.reviews})', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onTap,
                  child: const Text('Подробнее'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AppointmentRequestScreen(doctor: doctor),
                      ),
                    );
                  },
                  child: const Text('Записаться'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
