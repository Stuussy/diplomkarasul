import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/appointment.dart';
import '../models/clinic.dart';
import '../models/review.dart';
import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';
import '../widgets/dent_card.dart';
import '../widgets/dent_badge.dart';
import '../widgets/dent_shimmer.dart';
import '../widgets/section_header.dart';

const _twoGisWebUrl =
    'https://2gis.kz/astana/search/%D1%81%D1%82%D0%BE%D0%BC%D0%B0%D1%82%D0%BE%D0%BB%D0%BE%D0%B3%D0%B8%D1%8F/filters/sort%3Drating/firm/70000001041371459?m=71.421132%2C51.123988%2F18&immersive=on';
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
  late Future<_ClinicPageData> _future;
  bool _isOpeningMap = false;
  bool _isOpeningTaxi = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ClinicPageData> _load() async {
    final api = context.read<SessionProvider>().apiService;
    // Грузим всё параллельно: клинику, отзывы, визиты пациента для оценки.
    final clinicsF = api.fetchClinics(status: 'active');
    final reviewsF = api.fetchClinicReviews(limit: 10);
    final now = DateTime.now();
    final apptsF = api
        .fetchAppointments(from: now.subtract(const Duration(days: 365)), to: now)
        .catchError((_) => <Appointment>[]);

    final clinics = await clinicsF;
    final reviews = await reviewsF;
    final appts = await apptsF;

    Clinic? clinic;
    if (clinics.isNotEmpty) {
      clinic = clinics.firstWhere((c) => c.address != null && c.address!.isNotEmpty,
          orElse: () => clinics.first);
    }
    // Завершённые визиты без отзыва — по ним можно оставить оценку.
    final reviewable = appts
        .where((a) => a.status == 'completed' && a.review == null)
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return _ClinicPageData(clinic: clinic, reviews: reviews, reviewable: reviewable);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<bool> _tryLaunch(String url) async {
    try {
      final uri = Uri.parse(url);
      final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
      return await launchUrl(uri, mode: mode, webOnlyWindowName: '_blank');
    } catch (_) {
      return false;
    }
  }

  Future<void> _callTaxi(Clinic? clinic) async {
    if (_isOpeningTaxi) return;
    setState(() => _isOpeningTaxi = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      bool opened = false;
      final deepLink = clinic?.taxiDeepLink?.isNotEmpty == true ? clinic!.taxiDeepLink! : _taxiDeepLink;
      if (!kIsWeb) opened = await _tryLaunch(deepLink);
      if (!opened) opened = await _tryLaunch(_taxiWebUrl);
      if (!opened && mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Не удалось открыть Яндекс Такси.')));
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
      bool opened = false;
      if (!kIsWeb) opened = await _tryLaunch(_twoGisDeepLink);
      if (!opened) opened = await _tryLaunch(_twoGisWebUrl);
      if (!opened && mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Не удалось открыть карту 2GIS.')));
      }
    } finally {
      if (mounted) setState(() => _isOpeningMap = false);
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final ok = await _tryLaunch('tel:$cleaned');
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть звонилку.')),
      );
    }
  }

  Future<void> _sendEmail(String email) async {
    final ok = await _tryLaunch('mailto:$email');
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть почту.')),
      );
    }
  }

  Future<void> _leaveReview(Appointment appointment) async {
    double rating = 5;
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Оставить отзыв'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'О приёме у ${appointment.doctor?.fullName ?? 'врача'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClinicTheme.slate),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () => setLocal(() => rating = i + 1.0),
                    icon: Icon(
                      LucideIcons.star,
                      color: i < rating ? ClinicTheme.amber : ClinicTheme.mist,
                      size: 28,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Ваш комментарий'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Отправить')),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.submitReview(
        appointmentId: appointment.id,
        rating: rating.round(),
        comment: controller.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Спасибо за отзыв!'), backgroundColor: ClinicTheme.mint),
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: ClinicTheme.mist),
      child: FutureBuilder<_ClinicPageData>(
        future: _future,
        builder: (context, snapshot) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _buildBody(snapshot),
          );
        },
      ),
    );
  }

  Widget _buildBody(AsyncSnapshot<_ClinicPageData> snapshot) {
    final bottomInset = 110 + MediaQuery.of(context).padding.bottom;
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
        children: const [
          DentShimmerCard(height: 170),
          SizedBox(height: 16),
          DentShimmerCard(height: 220),
          SizedBox(height: 16),
          DentShimmerCard(height: 160),
        ],
      );
    }

    final data = snapshot.data;
    final clinic = data?.clinic;
    final reviews = data?.reviews;
    final reviewable = data?.reviewable ?? const <Appointment>[];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
      children: [
        _heroCard(clinic),
        const SizedBox(height: 16),
        _workingHoursCard(clinic),
        const SizedBox(height: 16),
        _contactsCard(clinic),
        if (clinic != null && clinic.services.where((s) => s.isActive).isNotEmpty) ...[
          const SizedBox(height: 16),
          _servicesCard(clinic),
        ],
        const SizedBox(height: 24),
        _reviewsSection(reviews, reviewable),
      ],
    );
  }

  // ── Адрес + маршрут ─────────────────────────────────────────────
  Widget _heroCard(Clinic? clinic) {
    final s = context.s;
    final name = (clinic?.name.isNotEmpty == true) ? clinic!.name : 'Наша клиника';
    final address = (clinic?.address?.isNotEmpty == true)
        ? clinic!.address!
        : 'Астана, постройте маршрут до клиники';
    return DentCard(
      gradient: ClinicTheme.heroGradient,
      borderRadius: ClinicTheme.radiusL,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.building2, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                name,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.mapPin, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _isOpeningMap ? null : _openClinicLocation,
                icon: const Icon(LucideIcons.navigation, size: 16),
                label: Text(_isOpeningMap ? s.loading : s.mapOpenRoute),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ClinicTheme.azure,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isOpeningTaxi ? null : () => _callTaxi(clinic),
                icon: const Icon(LucideIcons.car, size: 16),
                label: Text(_isOpeningTaxi ? s.loading : s.mapTaxi),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Часы работы + статус ────────────────────────────────────────
  Widget _workingHoursCard(Clinic? clinic) {
    final hours = clinic?.workingHours ?? const <ClinicWorkingHour>[];
    final now = DateTime.now();
    final todayKey = now.weekday == 7 ? 0 : now.weekday; // backend: 0=Вс
    final open = _isOpenNow(hours, now, todayKey);

    return DentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 18, color: ClinicTheme.azure),
              const SizedBox(width: 8),
              Text('Часы работы', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              DentBadge(
                label: open ? 'Открыто' : 'Закрыто',
                icon: open ? LucideIcons.check : LucideIcons.x,
                variant: open ? DentBadgeVariant.success : DentBadgeVariant.error,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hours.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Пн–Пт 09:00–18:00, Сб 10:00–15:00, Вс — выходной',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ClinicTheme.slate),
              ),
            )
          else
            ...List.generate(7, (i) {
              // Показываем по порядку Пн..Вс (день 1..6, затем 0)
              final dayKey = i == 6 ? 0 : i + 1;
              final wh = hours.where((h) => h.day == dayKey);
              final entry = wh.isNotEmpty ? wh.first : null;
              final isToday = dayKey == todayKey;
              return _hourRow(dayKey, entry, isToday);
            }),
        ],
      ),
    );
  }

  Widget _hourRow(int dayKey, ClinicWorkingHour? entry, bool isToday) {
    const names = {
      1: 'Понедельник', 2: 'Вторник', 3: 'Среда', 4: 'Четверг',
      5: 'Пятница', 6: 'Суббота', 0: 'Воскресенье',
    };
    final closed = entry == null || entry.isClosed || entry.open == null || entry.close == null;
    final value = closed ? 'Выходной' : '${entry!.open} – ${entry.close}';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isToday ? ClinicTheme.azureSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            names[dayKey] ?? '',
            style: TextStyle(
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? ClinicTheme.azure : ClinicTheme.midnight,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 6),
            const Text('• сегодня', style: TextStyle(fontSize: 11, color: ClinicTheme.azure)),
          ],
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: closed ? ClinicTheme.slate : ClinicTheme.midnight,
            ),
          ),
        ],
      ),
    );
  }

  bool _isOpenNow(List<ClinicWorkingHour> hours, DateTime now, int todayKey) {
    final wh = hours.where((h) => h.day == todayKey);
    if (wh.isEmpty) return false;
    final entry = wh.first;
    if (entry.isClosed || entry.open == null || entry.close == null) return false;
    final openM = _toMinutes(entry.open!);
    final closeM = _toMinutes(entry.close!);
    if (openM == null || closeM == null) return false;
    final nowM = now.hour * 60 + now.minute;
    return nowM >= openM && nowM < closeM;
  }

  int? _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  // ── Контакты ────────────────────────────────────────────────────
  Widget _contactsCard(Clinic? clinic) {
    final phone = clinic?.contacts?.phone;
    final email = clinic?.contacts?.email;
    final hasPhone = phone != null && phone.isNotEmpty;
    final hasEmail = email != null && email.isNotEmpty;
    return DentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.phone, size: 18, color: ClinicTheme.azure),
              const SizedBox(width: 8),
              Text('Контакты', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          _contactRow(
            icon: LucideIcons.phone,
            label: hasPhone ? phone : 'Телефон не указан',
            actionIcon: hasPhone ? LucideIcons.phone : null,
            onTap: hasPhone ? () => _callPhone(phone) : null,
          ),
          const SizedBox(height: 10),
          _contactRow(
            icon: LucideIcons.mail,
            label: hasEmail ? email : 'Email не указан',
            actionIcon: hasEmail ? LucideIcons.send : null,
            onTap: hasEmail ? () => _sendEmail(email) : null,
          ),
        ],
      ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    IconData? actionIcon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ClinicTheme.azure.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: ClinicTheme.azure),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: onTap != null ? ClinicTheme.midnight : ClinicTheme.slate,
                ),
              ),
            ),
            if (actionIcon != null) Icon(actionIcon, size: 18, color: ClinicTheme.azure),
          ],
        ),
      ),
    );
  }

  // ── Услуги и цены ───────────────────────────────────────────────
  Widget _servicesCard(Clinic clinic) {
    final services = clinic.services.where((s) => s.isActive).toList();
    return DentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clipboardList, size: 18, color: ClinicTheme.azure),
              const SizedBox(width: 8),
              Text('Услуги и цены', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          ...services.map((svc) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(svc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (svc.durationMinutes > 0)
                            Text('${svc.durationMinutes} мин',
                                style: const TextStyle(fontSize: 12, color: ClinicTheme.slate)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      svc.price > 0 ? '${svc.price} ₸' : 'по запросу',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ClinicTheme.azure),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Отзывы ──────────────────────────────────────────────────────
  Widget _reviewsSection(ClinicReviews? reviews, List<Appointment> reviewable) {
    final avg = reviews?.average ?? 0;
    final count = reviews?.count ?? 0;
    final list = reviews?.reviews ?? const <Review>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Отзывы о клинике',
          subtitle: 'Что говорят наши пациенты',
        ),
        const SizedBox(height: 12),
        // Сводка
        DentCard(
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    avg > 0 ? avg.toStringAsFixed(1) : '—',
                    style: const TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w800, color: ClinicTheme.midnight),
                  ),
                  _StarRow(value: avg),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  count > 0
                      ? '$count ${_plural(count)} от пациентов клиники'
                      : 'Пока нет отзывов — станьте первым!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ClinicTheme.slate),
                ),
              ),
            ],
          ),
        ),
        // Кнопка «Оставить отзыв» — если есть завершённый визит без оценки
        if (reviewable.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _leaveReview(reviewable.first),
              icon: const Icon(LucideIcons.star, size: 18),
              label: const Text('Оставить отзыв о визите'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (list.isEmpty)
          DentCard(
            child: Row(
              children: [
                const Icon(LucideIcons.messageCircle, size: 20, color: ClinicTheme.slate),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Отзывов пока нет. После визита вы сможете оценить приём.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClinicTheme.slate),
                  ),
                ),
              ],
            ),
          )
        else
          ...list.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewCard(review: r),
              )),
      ],
    );
  }

  String _plural(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'отзыв';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'отзыва';
    return 'отзывов';
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final name = review.patient?.fullName ?? 'Пациент';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final date = '${review.createdAt.day.toString().padLeft(2, '0')}.'
        '${review.createdAt.month.toString().padLeft(2, '0')}.${review.createdAt.year}';
    return DentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ClinicTheme.azure.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: ClinicTheme.azure, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (review.doctor != null)
                      Text('Врач: ${review.doctor!.fullName}',
                          style: const TextStyle(fontSize: 12, color: ClinicTheme.slate)),
                  ],
                ),
              ),
              Text(date, style: const TextStyle(fontSize: 11, color: ClinicTheme.slate)),
            ],
          ),
          const SizedBox(height: 8),
          _StarRow(value: review.rating.toDouble(), size: 16),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!, style: const TextStyle(height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.value, this.size = 18});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final full = value.floor();
    final half = value - full >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < full || (i == full && half);
        return Icon(
          LucideIcons.star,
          size: size,
          color: filled ? ClinicTheme.amber : ClinicTheme.mist,
        );
      }),
    );
  }
}

class _ClinicPageData {
  _ClinicPageData({required this.clinic, required this.reviews, required this.reviewable});
  final Clinic? clinic;
  final ClinicReviews? reviews;
  final List<Appointment> reviewable;
}
