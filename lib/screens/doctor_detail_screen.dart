import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/review.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';
import '../widgets/dent_card.dart';
import '../widgets/dent_badge.dart';
import 'appointment_request_screen.dart';

class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen({super.key, required this.doctor});

  final AppUser doctor;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final specialty = doctor.specialties.isNotEmpty
        ? doctor.specialties.join(', ')
        : s.homeSpecialties;
    final role = context.read<SessionProvider>().user?.role ?? 'patient';
    final isPatient = role == 'patient';

    return Scaffold(
      backgroundColor: ClinicTheme.mist,
      body: CustomScrollView(
        slivers: [
          // Hero SliverAppBar
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: ClinicTheme.azure,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: ClinicTheme.heroGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              _initials(doctor),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          doctor.fullName,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          specialty,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        ),
                        if (doctor.clinics.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(LucideIcons.mapPin, size: 14, color: Colors.white60),
                              const SizedBox(width: 4),
                              Text(
                                doctor.clinics.join(', '),
                                style: const TextStyle(color: Colors.white60, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  DentCard(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Row(
                      children: [
                        _StatColumn(
                          value: doctor.rating.toStringAsFixed(1),
                          label: s.doctorRating,
                        ),
                        _divider(),
                        _StatColumn(
                          value: '${doctor.reviews}',
                          label: s.doctorReviews,
                        ),
                        _divider(),
                        _StatColumn(
                          value: doctor.specialties.length.toString(),
                          label: s.doctorServices,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Services
                  if (doctor.specialties.isNotEmpty) ...[
                    Text(s.doctorServices, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: doctor.specialties.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: ClinicTheme.azureSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            color: ClinicTheme.azure,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Booking CTA
                  if (isPatient)
                    DentCard(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Записаться к врачу',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Выберите удобное время',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AppointmentRequestScreen(doctor: doctor),
                              ),
                            ),
                            icon: const Icon(LucideIcons.calendarPlus, size: 18),
                            label: Text(s.doctorBook),
                          ),
                        ],
                      ),
                    ),

                  if (isPatient) const SizedBox(height: 24),

                  // Reviews
                  Text(s.doctorReviews, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),

                  _DoctorReviewsSection(doctor: doctor),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: ClinicTheme.mist,
    );
  }

  String _initials(AppUser user) {
    final f = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final l = user.lastName.isNotEmpty ? user.lastName[0] : '';
    return '$f$l'.toUpperCase();
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.value});

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


class _DoctorReviewsSection extends StatelessWidget {
  const _DoctorReviewsSection({required this.doctor});
  final AppUser doctor;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final api = context.read<SessionProvider>().apiService;
    return FutureBuilder<List<Review>>(
      future: api.fetchDoctorReviews(doctor.id),
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final reviews = snapshot.data ?? const <Review>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DentCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    doctor.rating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StarRating(value: doctor.rating),
                        const SizedBox(height: 4),
                        Text(
                          doctor.reviews == 0
                              ? s.doctorNoReviews
                              : "${doctor.reviews} ${_pluralReviews(doctor.reviews)}",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (loading) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ] else if (reviews.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...reviews.take(10).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReviewCard(review: r),
              )),
            ],
          ],
        );
      },
    );
  }

  String _pluralReviews(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return "отзыв";
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return "отзыва";
    return "отзывов";
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final name = review.patient?.fullName ?? context.s.rolePatient;
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?";
    final dt = review.createdAt;
    final dateStr = "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
    return DentCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: ClinicTheme.azure.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: ClinicTheme.azure,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ClinicTheme.slate,
                          ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < review.rating;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 16,
                    color: filled ? ClinicTheme.amber : ClinicTheme.line,
                  );
                }),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: ClinicTheme.midnight,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

