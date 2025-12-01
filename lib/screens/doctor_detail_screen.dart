import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/review.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/patient_ui.dart';
import 'appointment_request_screen.dart';

class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({super.key, required this.doctor});

  final AppUser doctor;

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  late Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = context.read<ApiService>().fetchDoctorReviews(
      widget.doctor.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final specialty = doctor.specialties.isNotEmpty
        ? doctor.specialties.join(', ')
        : 'Стоматолог';
    final String? servicesSummary = doctor.services.isNotEmpty
        ? doctor.services.join(', ')
        : null;
    final String? servicesDetails = servicesSummary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Профиль врача'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F9FC), Color(0xFFEFF3FA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderCard(doctor: doctor, specialty: specialty),
              const SizedBox(height: 20),
              _InfoChips(doctor: doctor),
              const SizedBox(height: 20),
              PatientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'О враче',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      doctor.bio?.isNotEmpty == true
                          ? doctor.bio!
                          : 'Врач использует современный подход к диагностике и лечению, подробно объясняет каждый этап и сопровождает пациента после процедуры.',
                      style: const TextStyle(height: 1.5),
                    ),
                    if (servicesDetails != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Услуги',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(servicesDetails),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PatientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ближайшие слоты',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AppointmentRequestScreen(doctor: doctor),
                          ),
                        );
                      },
                      child: const Text('Записаться на приём'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PatientSectionTitle(
                title: 'Отзывы пациентов',
                subtitle: 'Честные впечатления от посещений',
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Review>>(
                future: _reviewsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text('Ошибка загрузки отзывов: ${snapshot.error}');
                  }
                  final reviews = snapshot.data ?? [];
                  if (reviews.isEmpty) {
                    return const PatientEmptyState(
                      title: 'Отзывов пока нет',
                      message:
                          'Станьте первым, кто поделится впечатлениями о приёме.',
                      icon: Icons.reviews_outlined,
                    );
                  }
                  final average =
                      reviews.map((e) => e.rating).reduce((a, b) => a + b) /
                      reviews.length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PatientCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Средняя оценка',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                  Text(
                                    average.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _RatingStars(value: average.round()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...reviews.map(
                        (review) => PatientCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Text(
                                      review.patient?.firstName
                                              .substring(0, 1)
                                              .toUpperCase() ??
                                          'P',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          review.patient?.fullName ?? 'Пациент',
                                        ),
                                        _RatingStars(value: review.rating),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                review.comment?.isNotEmpty == true
                                    ? review.comment!
                                    : 'Без комментария',
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.doctor, required this.specialty});

  final AppUser doctor;
  final String specialty;

  @override
  Widget build(BuildContext context) {
    return PatientCard(
      gradient: PatientPalette.hero,
      color: PatientPalette.primary,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  doctor.firstName.isNotEmpty
                      ? doctor.firstName[0].toUpperCase()
                      : doctor.lastName.isNotEmpty
                      ? doctor.lastName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.fullName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialty,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            doctor.clinics.isNotEmpty
                                ? doctor.clinics.join(', ')
                                : 'Dental AI Clinic',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              PatientBadge(
                label: '${doctor.rating.toStringAsFixed(1)} · рейтинг',
                icon: Icons.star_rounded,
                color: Colors.white,
              ),
              PatientBadge(
                label: '${doctor.reviews} отзывов',
                icon: Icons.reviews_outlined,
                color: Colors.white,
              ),
              if (doctor.experienceYears > 0)
                PatientBadge(
                  label: '${doctor.experienceYears}+ лет опыта',
                  icon: Icons.school_outlined,
                  color: Colors.white,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChips extends StatelessWidget {
  const _InfoChips({required this.doctor});

  final AppUser doctor;

  @override
  Widget build(BuildContext context) {
    return PatientCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _InfoBubble(
            icon: Icons.people_alt_outlined,
            label: 'Пациентов',
            value: '${doctor.reviews * 15 + 50}+',
          ),
          _InfoBubble(
            icon: Icons.school_outlined,
            label: 'Опыт',
            value: doctor.experienceYears > 0
                ? '${doctor.experienceYears} лет'
                : '—',
          ),
          _InfoBubble(
            icon: Icons.star_rate_rounded,
            label: 'Рейтинг',
            value: doctor.rating.toStringAsFixed(1),
          ),
          _InfoBubble(
            icon: Icons.reviews_outlined,
            label: 'Отзывы',
            value: '${doctor.reviews}',
          ),
        ],
      ),
    );
  }
}

class _InfoBubble extends StatelessWidget {
  const _InfoBubble({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: PatientPalette.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: PatientPalette.primary),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) => Icon(
          index < value ? Icons.star : Icons.star_border,
          color: Colors.orange,
          size: 18,
        ),
      ),
    );
  }
}
