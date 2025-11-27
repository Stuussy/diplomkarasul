import 'package:flutter/material.dart';

import '../models/user.dart';

class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen({super.key, required this.doctor});

  final AppUser doctor;

  @override
  Widget build(BuildContext context) {
    final specialty = doctor.specialties.isNotEmpty
        ? doctor.specialties.join(', ')
        : 'Стоматолог';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль врача'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    doctor.firstName.isNotEmpty
                        ? doctor.firstName[0].toUpperCase()
                        : doctor.lastName.isNotEmpty
                            ? doctor.lastName[0].toUpperCase()
                            : '?',
                    style: const TextStyle(fontSize: 32, color: Colors.blue),
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        specialty,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              doctor.clinics.isNotEmpty
                                  ? doctor.clinics.join(', ')
                                  : 'Dental AI Clinic',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {},
                  child: const Text('Записаться'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoBubble(
                  icon: Icons.people_alt_outlined,
                  label: 'Пациентов',
                  value: '7 500+',
                ),
                _InfoBubble(
                  icon: Icons.school_outlined,
                  label: 'Опыт',
                  value: '10 лет',
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
            const SizedBox(height: 24),
            const Text(
              'О враче',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Современный специалист, использующий инновационные методики лечения и профилактики. '
              'Ведёт личный план лечения, подробно объясняет каждый этап.',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            const Text(
              'Рабочие часы',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _WorkingHours(),
            const SizedBox(height: 24),
            const Text(
              'Отзывы пациентов',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _ReviewCard(
              name: 'Динара',
              rating: 5.0,
              comment: 'Очень внимательный врач, быстро нашёл решение моей проблемы.',
            ),
            _ReviewCard(
              name: 'Ержан',
              rating: 4.8,
              comment: 'Отличный сервис и заботливое отношение.',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {},
              child: const Text(
                'Записаться на приём',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBubble extends StatelessWidget {
  const _InfoBubble({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _WorkingHours extends StatelessWidget {
  final List<String> days = const [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: days
          .map(
            (day) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(day),
                  const Text('09:00 - 18:00',
                      style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.name,
    required this.rating,
    required this.comment,
  });

  final String name;
  final double rating;
  final String comment;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(name[0])),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.orange.shade400),
                          Text(rating.toStringAsFixed(1)),
                          const SizedBox(width: 8),
                          const Text('11 месяцев назад',
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(comment),
          ],
        ),
      ),
    );
  }
}
