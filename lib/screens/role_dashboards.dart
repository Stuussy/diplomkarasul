import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/appointment.dart';
import '../models/clinic.dart';
import '../models/profile_summary.dart';
import '../models/support_message.dart';
import '../models/slot.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';
import '../widgets/appointment_calendar.dart';
import '../widgets/dent_badge.dart';
import '../widgets/dent_card.dart';
import '../widgets/dent_shimmer.dart';
import '../widgets/role_profile_overview.dart';
import 'medical_records_screen.dart';
import 'treatment_plan_screen.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  late Future<RoleProfileSummary> _profileFuture;
  late Future<List<Appointment>> _appointmentsFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    _appointmentsFuture = _loadAppointments();
  }

  Future<RoleProfileSummary> _loadProfile() {
    final api = context.read<SessionProvider>().apiService;
    return api.fetchRoleProfileSummary();
  }

  Future<List<Appointment>> _loadAppointments() {
    final api = context.read<SessionProvider>().apiService;
    final now = DateTime.now();
    return api.fetchAppointments(
      from: now.subtract(const Duration(days: 1)),
      to: now.add(const Duration(days: 30)),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadProfile();
      _appointmentsFuture = _loadAppointments();
    });
  }

  Future<void> _completeAppointment(Appointment appointment) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<SessionProvider>().apiService;
    final patientName = appointment.patient?.fullName ?? 'пациент';
    final s = context.sRead;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(s.dashDoctorComplete),
          content: Text(
            'Приём «$patientName» (${appointment.service}) будет помечен как завершённый.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.cancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(LucideIcons.checkCheck, size: 16),
              label: Text(s.dashDoctorComplete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await api.completeAppointment(appointment.id);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(s.success)));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _logout() async {
    await context.read<SessionProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: ClinicTheme.mist,
        appBar: AppBar(
          backgroundColor: ClinicTheme.snow,
          foregroundColor: ClinicTheme.midnight,
          elevation: 0,
          title: Text(s.dashDoctorTitle),
          actions: [
            IconButton(onPressed: _refresh, icon: const Icon(LucideIcons.refreshCcw, size: 20)),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') _logout();
                else if (value == 'change_password') showChangePasswordDialog(context);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'change_password', child: Text(s.profileChangePassword)),
                PopupMenuItem(value: 'logout', child: Text(s.logout)),
              ],
            ),
          ],
          bottom: TabBar(
            labelColor: ClinicTheme.azure,
            unselectedLabelColor: ClinicTheme.slate,
            indicatorColor: ClinicTheme.azure,
            tabs: [
              Tab(icon: const Icon(LucideIcons.layoutDashboard, size: 20), text: 'Обзор'),
              Tab(icon: const Icon(LucideIcons.calendarCheck, size: 20), text: s.navAppointments),
              Tab(icon: const Icon(LucideIcons.clipboardList, size: 20), text: 'Планы'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _buildDoctorOverviewTab(),
          _buildDoctorAppointmentsTab(),
          _buildDoctorPlansTab(),
        ]),
      ),
    );
  }

  Widget _buildDoctorOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          FutureBuilder<RoleProfileSummary>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _doctorShimmer(80);
              }
              if (!snapshot.hasData) return const SizedBox.shrink();
              return RoleProfileOverview(summary: snapshot.data!);
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Appointment>>(
            future: _appointmentsFuture,
            builder: (context, snap) {
              final all = snap.data ?? [];
              final today = DateTime.now();
              final todayAppts = all.where((a) =>
                a.startTime.year == today.year &&
                a.startTime.month == today.month &&
                a.startTime.day == today.day).toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));
              final activeCount = all.where((a) => a.status == 'scheduled' || a.status == 'confirmed').length;
              final doneCount = all.where((a) => a.status == 'completed').length;
              if (snap.connectionState == ConnectionState.waiting) return _doctorShimmer(72);
              return Row(children: [
                _doctorStatCard('Сегодня', '${todayAppts.length}', LucideIcons.calendarCheck, ClinicTheme.azure, ClinicTheme.azureSoft),
                const SizedBox(width: 10),
                _doctorStatCard('Активных', '$activeCount', LucideIcons.clock, ClinicTheme.amber, ClinicTheme.amberSoft),
                const SizedBox(width: 10),
                _doctorStatCard('Завершено', '$doneCount', LucideIcons.checkCircle, ClinicTheme.mint, ClinicTheme.mintSoft),
              ]);
            },
          ),
          const SizedBox(height: 16),
          // Today's schedule
          FutureBuilder<List<Appointment>>(
            future: _appointmentsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return _doctorShimmer(160);
              final today = DateTime.now();
              final todayAppts = (snap.data ?? []).where((a) =>
                a.startTime.year == today.year &&
                a.startTime.month == today.month &&
                a.startTime.day == today.day).toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));
              if (todayAppts.isEmpty) {
                return DentCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    const Icon(LucideIcons.calendarX, size: 36, color: ClinicTheme.slate),
                    const SizedBox(height: 8),
                    Text('Приёмов сегодня нет', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ClinicTheme.slate)),
                  ]),
                );
              }
              return DentCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Text('Расписание на сегодня', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    ...todayAppts.map((a) => _doctorApptRow(a, compact: true)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorAppointmentsTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Appointment>>(
        future: _appointmentsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              _doctorShimmer(90), const SizedBox(height: 12),
              _doctorShimmer(90), const SizedBox(height: 12),
              _doctorShimmer(90),
            ]);
          }
          final appointments = (snap.data ?? [])
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
          if (appointments.isEmpty) {
            return ListView(padding: const EdgeInsets.all(24), children: [
              const SizedBox(height: 60),
              const Icon(LucideIcons.calendarX, size: 48, color: ClinicTheme.slate),
              const SizedBox(height: 16),
              Center(child: Text(context.s.dashDoctorNoAppointments, style: const TextStyle(color: ClinicTheme.slate, fontSize: 16))),
            ]);
          }
          // Group by date
          final grouped = <String, List<Appointment>>{};
          for (final a in appointments) {
            final key = '${a.startTime.day.toString().padLeft(2,'0')}.${a.startTime.month.toString().padLeft(2,'0')}.${a.startTime.year}';
            grouped.putIfAbsent(key, () => []).add(a);
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: grouped.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DentCard(
                padding: EdgeInsets.zero,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, color: ClinicTheme.azure, fontSize: 13)),
                  ),
                  const Divider(height: 1),
                  ...e.value.map((a) => _doctorApptRow(a)),
                ]),
              ),
            )).toList(),
          );
        },
      ),
    );
  }

  Widget _doctorApptRow(Appointment a, {bool compact = false}) {
    final isActive = a.status == 'scheduled' || a.status == 'confirmed';
    final isCompleted = a.status == 'completed';
    final color = isCompleted ? ClinicTheme.mint : isActive ? ClinicTheme.azure : ClinicTheme.slate;
    final bgColor = isCompleted ? ClinicTheme.mintSoft : isActive ? ClinicTheme.azureSoft : ClinicTheme.mist;
    final icon = isCompleted ? LucideIcons.checkCheck : a.status == 'confirmed' ? LucideIcons.checkCircle : LucideIcons.clock;
    final time = '${a.startTime.hour.toString().padLeft(2,'0')}:${a.startTime.minute.toString().padLeft(2,'0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: color),
            Text(time, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.patient?.fullName ?? 'Пациент', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: ClinicTheme.midnight), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(a.service, style: const TextStyle(fontSize: 12, color: ClinicTheme.slate), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (isActive) ...[
          IconButton(
            tooltip: 'Завершить',
            onPressed: () => _completeAppointment(a),
            icon: const Icon(LucideIcons.checkCheck, size: 20, color: ClinicTheme.mint),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
        IconButton(
          tooltip: 'План лечения',
          onPressed: a.patient == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TreatmentPlanScreen(patientId: a.patient!.id, patientName: a.patient!.fullName, isStaff: true))),
          icon: const Icon(LucideIcons.clipboardList, size: 20, color: ClinicTheme.azure),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        IconButton(
          tooltip: 'Медкарта',
          onPressed: a.patient == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MedicalRecordsScreen(patientId: a.patient!.id, title: 'Карта: ${a.patient!.fullName}', allowCreate: true, allowEdit: true))),
          icon: const Icon(LucideIcons.folderHeart, size: 20, color: ClinicTheme.slate),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ]),
    );
  }

  Widget _buildDoctorPlansTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Appointment>>(
        future: _appointmentsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _doctorShimmer(80),
                const SizedBox(height: 12),
                _doctorShimmer(72),
                const SizedBox(height: 12),
                _doctorShimmer(72),
              ],
            );
          }

          final appointments = snap.data ?? [];
          // Deduplicate patients by id
          final seen = <String>{};
          final patients = <_PatientEntry>[];
          for (final a in appointments) {
            final p = a.patient;
            if (p != null && seen.add(p.id)) {
              patients.add(_PatientEntry(id: p.id, fullName: p.fullName));
            }
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Header card
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A4DD3), Color(0xFF2E8BFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(ClinicTheme.radiusL),
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(LucideIcons.clipboardList, color: Colors.white, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Планы лечения пациентов',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Нажмите на пациента для управления планами',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${patients.length}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (patients.isEmpty) ...[
                const SizedBox(height: 40),
                const Icon(LucideIcons.users, size: 48, color: ClinicTheme.slate),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Нет пациентов с приёмами',
                    style: TextStyle(fontSize: 16, color: ClinicTheme.slate),
                  ),
                ),
              ] else
                ...patients.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DentCard(
                      padding: EdgeInsets.zero,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TreatmentPlanScreen(
                            patientId: p.id,
                            patientName: p.fullName,
                            isStaff: true,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: ClinicTheme.azureSoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.users, size: 18, color: ClinicTheme.azure),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: ClinicTheme.midnight),
                                  ),
                                  const Text(
                                    'Нажмите, чтобы открыть планы',
                                    style: TextStyle(fontSize: 12, color: ClinicTheme.slate),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(LucideIcons.chevronRight, size: 18, color: ClinicTheme.slate),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _doctorStatCard(String label, String value, IconData icon, Color color, Color bg) {
    return Expanded(child: DentCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, size: 17, color: color)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: ClinicTheme.slate)),
      ]),
    ));
  }

  Widget _doctorShimmer(double h) => Container(height: h, margin: const EdgeInsets.only(bottom: 4), decoration: BoxDecoration(color: ClinicTheme.mist, borderRadius: BorderRadius.circular(14)));

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$day.$month.${date.year} · $time';
  }
}

class _PatientEntry {
  const _PatientEntry({required this.id, required this.fullName});
  final String id;
  final String fullName;
}

class _WorkingHourEntry {
  _WorkingHourEntry({
    required this.day,
    required String open,
    required String close,
  })  : openController = TextEditingController(text: open),
        closeController = TextEditingController(text: close),
        isClosed = false;

  final int day;
  final TextEditingController openController;
  final TextEditingController closeController;
  bool isClosed;

  void dispose() {
    openController.dispose();
    closeController.dispose();
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<RoleProfileSummary> _profileFuture;
  late Future<List<AppUser>> _doctorsFuture;
  late Future<List<Appointment>> _appointmentsFuture;
  List<Clinic> _clinics = [];
  String? _selectedClinicId;
  Future<List<Slot>>? _slotsFuture;
  String? _selectedDoctorId;
  String? _apptFilterDoctorId; // фильтр вкладки «Записи» (null = все врачи)
  DateTime? _slotDate;
  TimeOfDay? _slotStart;
  TimeOfDay? _slotEnd;
  bool _seedingSlots = false;
  DateTime _seedUntil = DateTime(2026, 6, 10);

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final List<_WorkingHourEntry> _workingHours = List.generate(
    7,
    (index) => _WorkingHourEntry(day: index, open: '09:00', close: '18:00'),
  );
  final _serviceNameController = TextEditingController();
  final _servicePriceController = TextEditingController();
  final _serviceDurationController = TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    _doctorsFuture = _loadDoctors();
    _appointmentsFuture = _loadAppointments();
    _loadClinics();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    for (final entry in _workingHours) entry.dispose();
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    _serviceDurationController.dispose();
    super.dispose();
  }

  Future<RoleProfileSummary> _loadProfile() =>
      context.read<SessionProvider>().apiService.fetchRoleProfileSummary();

  Future<List<Appointment>> _loadAppointments() {
    final api = context.read<SessionProvider>().apiService;
    final now = DateTime.now();
    return api.fetchAppointments(from: now.subtract(const Duration(days: 1)), to: now.add(const Duration(days: 30)));
  }

  Future<void> _loadClinics() async {
    final clinics = await context.read<SessionProvider>().apiService.fetchClinics();
    if (!mounted) return;
    setState(() {
      _clinics = clinics;
      if (_selectedClinicId == null && clinics.isNotEmpty) {
        _selectedClinicId = clinics.first.id;
        _fillClinicForm(clinics.first);
      }
    });
  }

  Future<List<AppUser>> _loadDoctors() async {
    final doctors = await context.read<SessionProvider>().apiService.fetchDoctors();
    if (_selectedDoctorId == null && doctors.isNotEmpty) {
      _selectedDoctorId = doctors.first.id;
      _slotsFuture = _loadSlots();
    }
    return doctors;
  }

  Future<List<Slot>> _loadSlots() =>
      context.read<SessionProvider>().apiService.fetchSlots(doctorId: _selectedDoctorId, status: null);

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadProfile();
      _doctorsFuture = _loadDoctors();
      _appointmentsFuture = _loadAppointments();
      if (_selectedDoctorId != null) _slotsFuture = _loadSlots();
    });
    await _loadClinics();
  }

  Future<void> _logout() => context.read<SessionProvider>().logout();

  void _fillClinicForm(Clinic clinic) {
    _nameController.text = clinic.name;
    _descriptionController.text = clinic.description ?? '';
    _cityController.text = clinic.city ?? '';
    _addressController.text = clinic.address ?? '';
    _phoneController.text = clinic.contacts?.phone ?? '';
    _emailController.text = clinic.contacts?.email ?? '';
    if (clinic.workingHours.isNotEmpty) {
      for (final entry in _workingHours) {
        final wh = clinic.workingHours.firstWhere(
          (item) => item.day == entry.day,
          orElse: () => ClinicWorkingHour(day: entry.day, open: '09:00', close: '18:00', isClosed: false),
        );
        entry.openController.text = wh.open ?? '09:00';
        entry.closeController.text = wh.close ?? '18:00';
        entry.isClosed = wh.isClosed;
      }
    }
  }

  List<Map<String, dynamic>> _buildWorkingHoursPayload() => _workingHours
      .map((e) => {'day': e.day, 'open': e.openController.text.trim(), 'close': e.closeController.text.trim(), 'isClosed': e.isClosed})
      .toList();

  Future<void> _saveClinic({String? status}) async {
    final api = context.read<SessionProvider>().apiService;
    final payload = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'city': _cityController.text.trim(),
      'address': _addressController.text.trim(),
      'contacts': {'phone': _phoneController.text.trim(), 'email': _emailController.text.trim()},
      'workingHours': _buildWorkingHoursPayload(),
      if (status != null) 'status': status,
    };
    try {
      if (_selectedClinicId == null) {
        final clinic = await api.createClinic(payload);
        if (!mounted) return;
        setState(() { _clinics = [..._clinics, clinic]; _selectedClinicId = clinic.id; });
      } else {
        await api.updateClinic(_selectedClinicId!, payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(_successSnack('Данные клиники сохранены'));
      _loadClinics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(_errorSnack('$e'));
    }
  }

  Future<void> _addService() async {
    if (_selectedClinicId == null) return;
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.addClinicService(_selectedClinicId!, {
        'name': _serviceNameController.text.trim(),
        'price': int.tryParse(_servicePriceController.text) ?? 0,
        'durationMinutes': int.tryParse(_serviceDurationController.text) ?? 30,
      });
      _serviceNameController.clear();
      _servicePriceController.clear();
      _serviceDurationController.text = '30';
      await _loadClinics();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(_successSnack('Услуга добавлена'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(_errorSnack('$e'));
    }
  }

  Future<void> _assignDoctor(String doctorId) async {
    if (_selectedClinicId == null) return;
    try {
      await context.read<SessionProvider>().apiService.addClinicDoctor(_selectedClinicId!, doctorId);
      await _loadClinics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(_errorSnack('$e'));
    }
  }

  Future<void> _removeDoctor(String doctorId) async {
    if (_selectedClinicId == null) return;
    try {
      await context.read<SessionProvider>().apiService.removeClinicDoctor(_selectedClinicId!, doctorId);
      await _loadClinics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(_errorSnack('$e'));
    }
  }

  Future<void> _pickSlotDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 60)));
    if (result != null) setState(() => _slotDate = result);
  }

  Future<void> _pickSeedUntil() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _seedUntil,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (result != null) setState(() => _seedUntil = result);
  }

  Future<TimeOfDay?> _show24hTimePicker(TimeOfDay initial) => showTimePicker(
    context: context,
    initialTime: initial,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child ?? const SizedBox.shrink(),
    ),
  );

  Future<void> _pickStartTime() async {
    final r = await _show24hTimePicker(const TimeOfDay(hour: 9, minute: 0));
    if (r != null) setState(() => _slotStart = r);
  }

  Future<void> _pickEndTime() async {
    final r = await _show24hTimePicker(const TimeOfDay(hour: 9, minute: 45));
    if (r != null) setState(() => _slotEnd = r);
  }

  Future<void> _createSlot() async {
    if (_selectedDoctorId == null || _selectedClinicId == null || _slotDate == null || _slotStart == null || _slotEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(_errorSnack('Заполните все поля'));
      return;
    }
    final start = DateTime(_slotDate!.year, _slotDate!.month, _slotDate!.day, _slotStart!.hour, _slotStart!.minute);
    final end = DateTime(_slotDate!.year, _slotDate!.month, _slotDate!.day, _slotEnd!.hour, _slotEnd!.minute);
    if (end.isBefore(start)) { ScaffoldMessenger.of(context).showSnackBar(_errorSnack('Конец раньше начала')); return; }
    try {
      await context.read<SessionProvider>().apiService.createSlot(doctorId: _selectedDoctorId!, clinicId: _selectedClinicId!, startTime: start, endTime: end);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(_successSnack('Слот создан'));
      setState(() => _slotsFuture = _loadSlots());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(_errorSnack('$e'));
    }
  }

  Future<void> _deleteSlot(String slotId) async {
    try {
      await context.read<SessionProvider>().apiService.deleteSlot(slotId);
      if (!mounted) return;
      setState(() => _slotsFuture = _loadSlots());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(_errorSnack('$e'));
    }
  }

  Future<void> _seedSlots() async {
    setState(() => _seedingSlots = true);
    final dateStr = '${_seedUntil.year}-${_seedUntil.month.toString().padLeft(2,'0')}-${_seedUntil.day.toString().padLeft(2,'0')}';
    try {
      final result = await context.read<SessionProvider>().apiService.seedSlots(untilDate: dateStr);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(_successSnack(result['message'] as String? ?? 'Слоты созданы'));
      setState(() => _slotsFuture = _loadSlots());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(_errorSnack('$e'));
    } finally {
      if (mounted) setState(() => _seedingSlots = false);
    }
  }

  Clinic? get _selectedClinic => _selectedClinicId == null ? null
      : _clinics.firstWhere((c) => c.id == _selectedClinicId, orElse: () => _clinics.first);

  SnackBar _successSnack(String msg) => SnackBar(
    content: Text(msg),
    backgroundColor: ClinicTheme.mint,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  SnackBar _errorSnack(String msg) => SnackBar(
    content: Text(msg),
    backgroundColor: ClinicTheme.coral,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: ClinicTheme.mist,
        appBar: AppBar(
          backgroundColor: ClinicTheme.snow,
          foregroundColor: ClinicTheme.midnight,
          elevation: 0,
          title: Text(s.dashAdminTitle),
          actions: [
            IconButton(onPressed: _refresh, icon: const Icon(LucideIcons.refreshCcw, size: 20)),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') _logout();
                else if (value == 'change_password') showChangePasswordDialog(context);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'change_password', child: Text(s.profileChangePassword)),
                PopupMenuItem(value: 'logout', child: Text(s.logout)),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: ClinicTheme.azure,
            unselectedLabelColor: ClinicTheme.slate,
            indicatorColor: ClinicTheme.azure,
            tabs: [
              Tab(icon: const Icon(LucideIcons.layoutDashboard, size: 20), text: 'Обзор'),
              Tab(icon: const Icon(LucideIcons.calendarCheck, size: 20), text: 'Записи'),
              Tab(icon: const Icon(LucideIcons.building2, size: 20), text: 'Клиника'),
              Tab(icon: const Icon(LucideIcons.calendarClock, size: 20), text: 'Слоты'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _buildOverviewTab(),
          _buildAppointmentsTab(),
          _buildClinicTab(),
          _buildScheduleTab(),
        ]),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    return FutureBuilder<List<AppUser>>(
      future: _doctorsFuture,
      builder: (context, docSnap) {
        final doctors = docSnap.data ?? [];
        return FutureBuilder<List<Appointment>>(
          future: _appointmentsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(padding: const EdgeInsets.all(16), children: const [
                DentShimmerCard(height: 320),
              ]);
            }
            final all = snap.data ?? [];
            // Только активные/будущие и подтверждённые — для обзвона клиентов
            final relevant = all
                .where((a) => a.status != 'cancelled')
                .where((a) => _apptFilterDoctorId == null || a.doctor?.id == _apptFilterDoctorId)
                .toList();

            final header = Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A4DD3), Color(0xFF2E8BFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(ClinicTheme.radiusL),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(LucideIcons.calendarCheck, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Записи клиники', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          'Выберите день в календаре, чтобы увидеть пациентов и позвонить для подтверждения.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Фильтр по врачу
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _doctorFilterChip(null, 'Все врачи'),
                        ...doctors.map((d) => _doctorFilterChip(d.id, d.fullName)),
                      ],
                    ),
                  ),
                ],
              ),
            );

            return AppointmentCalendar(
              appointments: relevant,
              header: header,
              emptyDayTitle: 'На этот день записей нет',
              emptyDayIcon: LucideIcons.calendarX,
              itemBuilder: (context, apt) => _AdminApptCard(appointment: apt),
            );
          },
        );
      },
    );
  }

  Widget _doctorFilterChip(String? doctorId, String label) {
    final selected = _apptFilterDoctorId == doctorId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _apptFilterDoctorId = doctorId),
        backgroundColor: ClinicTheme.snow,
        selectedColor: ClinicTheme.azure,
        labelStyle: TextStyle(
          color: selected ? Colors.white : ClinicTheme.slate,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? ClinicTheme.azure : ClinicTheme.line),
        ),
      ),
    );
  }

  // ──────────────────────────── OVERVIEW TAB ────────────────────────────

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          FutureBuilder<RoleProfileSummary>(
            future: _profileFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return _shimmer(80);
              if (!snap.hasData) return const SizedBox.shrink();
              return RoleProfileOverview(summary: snap.data!);
            },
          ),
          const SizedBox(height: 16),

          // Stats row
          FutureBuilder<List<Appointment>>(
            future: _appointmentsFuture,
            builder: (context, snap) {
              final appointments = snap.data ?? [];
              final today = DateTime.now();
              final todayCount = appointments.where((a) {
                return a.startTime.year == today.year &&
                    a.startTime.month == today.month &&
                    a.startTime.day == today.day &&
                    (a.status == 'scheduled' || a.status == 'confirmed');
              }).length;
              final activeCount = appointments.where((a) => a.status == 'scheduled' || a.status == 'confirmed').length;
              if (snap.connectionState == ConnectionState.waiting) return _shimmer(72);
              return Row(
                children: [
                  Expanded(child: _statCard('Сегодня', '$todayCount', LucideIcons.calendarCheck, ClinicTheme.azure, ClinicTheme.azureSoft)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Активных', '$activeCount', LucideIcons.clock, ClinicTheme.amber, ClinicTheme.amberSoft)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Врачей', '${_clinics.isEmpty ? "—" : _clinics.fold(0, (s, c) => s + c.doctors.length)}', LucideIcons.stethoscope, ClinicTheme.mint, ClinicTheme.mintSoft)),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Upcoming appointments
          FutureBuilder<List<Appointment>>(
            future: _appointmentsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return _shimmer(200);
              final all = snap.data ?? [];
              final upcoming = all
                  .where((a) => a.status == 'scheduled' || a.status == 'confirmed')
                  .toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));
              if (upcoming.isEmpty) {
                return DentCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.calendarX, size: 36, color: ClinicTheme.slate),
                      const SizedBox(height: 8),
                      Text('Нет предстоящих записей', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ClinicTheme.slate)),
                    ],
                  ),
                );
              }
              return DentCard(
                padding: const EdgeInsets.all(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Text('Ближайшие записи', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    ...upcoming.take(8).map((a) => _appointmentRow(a)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color bgColor) {
    return DentCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: ClinicTheme.slate)),
        ],
      ),
    );
  }

  Widget _appointmentRow(Appointment a) {
    final isPending = a.status == 'scheduled';
    final time = '${a.startTime.hour.toString().padLeft(2,'0')}:${a.startTime.minute.toString().padLeft(2,'0')}';
    final date = '${a.startTime.day.toString().padLeft(2,'0')}.${a.startTime.month.toString().padLeft(2,'0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: isPending ? ClinicTheme.azureSoft : ClinicTheme.mintSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isPending ? LucideIcons.clock : LucideIcons.checkCircle,
                size: 18, color: isPending ? ClinicTheme.azure : ClinicTheme.mint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.patient?.fullName ?? 'Пациент', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${a.service} • ${a.doctor?.fullName ?? ''}', style: const TextStyle(fontSize: 12, color: ClinicTheme.slate)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ClinicTheme.midnight)),
              Text(date, style: const TextStyle(fontSize: 11, color: ClinicTheme.slate)),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────── CLINIC TAB ────────────────────────────

  Widget _buildClinicTab() {
    final selectedClinic = _selectedClinic;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Clinic picker
          if (_clinics.length > 1)
            DentCard(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClinicId,
                  isExpanded: true,
                  icon: const Icon(LucideIcons.chevronDown, size: 18),
                  items: _clinics.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() { _selectedClinicId = v; _fillClinicForm(_clinics.firstWhere((c) => c.id == v)); });
                  },
                ),
              ),
            ),
          if (_clinics.length > 1) const SizedBox(height: 12),

          // Status badge
          if (selectedClinic != null)
            DentCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(LucideIcons.building2, color: ClinicTheme.azure, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(selectedClinic.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                  DentBadge(
                    label: selectedClinic.status == 'active' ? 'Активна' : selectedClinic.status == 'inactive' ? 'Неактивна' : 'Черновик',
                    variant: selectedClinic.status == 'active' ? DentBadgeVariant.success : DentBadgeVariant.error,
                  ),
                ],
              ),
            ),
          if (selectedClinic != null) const SizedBox(height: 12),

          // Info form
          _sectionCard(
            title: 'Основная информация',
            icon: LucideIcons.info,
            children: [
              _field(_nameController, 'Название клиники', LucideIcons.building2),
              _field(_descriptionController, 'Описание', LucideIcons.fileText, minLines: 2, maxLines: 3),
              _field(_cityController, 'Город', LucideIcons.mapPin),
              _field(_addressController, 'Адрес', LucideIcons.navigation),
              _field(_phoneController, 'Телефон', LucideIcons.phone, type: TextInputType.phone),
              _field(_emailController, 'Email', LucideIcons.mail, type: TextInputType.emailAddress),
            ],
          ),
          const SizedBox(height: 12),

          // Schedule
          _sectionCard(
            title: 'Режим работы',
            icon: LucideIcons.clock,
            children: [
              ..._workingHours.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 30, child: Text(_dayLabel(entry.day), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: entry.openController, enabled: !entry.isClosed, style: const TextStyle(fontSize: 13), decoration: _inputDec('Откр.'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: entry.closeController, enabled: !entry.isClosed, style: const TextStyle(fontSize: 13), decoration: _inputDec('Закр.'))),
                    const SizedBox(width: 4),
                    Switch.adaptive(
                      value: entry.isClosed,
                      onChanged: (v) => setState(() => entry.isClosed = v),
                      activeColor: ClinicTheme.coral,
                    ),
                  ],
                ),
              )),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _saveClinic(),
                  icon: const Icon(LucideIcons.save, size: 16),
                  label: const Text('Сохранить'),
                ),
              ),
              if (selectedClinic != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _saveClinic(status: selectedClinic.status == 'active' ? 'inactive' : 'active'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: selectedClinic.status == 'active' ? ClinicTheme.coral : ClinicTheme.mint,
                      side: BorderSide(color: selectedClinic.status == 'active' ? ClinicTheme.coral : ClinicTheme.mint),
                    ),
                    child: Text(selectedClinic.status == 'active' ? 'Деактивировать' : 'Активировать'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Services
          _sectionCard(
            title: 'Услуги',
            icon: LucideIcons.stethoscope,
            children: [
              if (selectedClinic != null && selectedClinic.services.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedClinic.services.map((svc) => Chip(
                    label: Text('${svc.name} • ${svc.price} ₸', style: const TextStyle(fontSize: 12)),
                    backgroundColor: ClinicTheme.azureSoft,
                    side: BorderSide.none,
                  )).toList(),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
              ],
              _field(_serviceNameController, 'Название услуги', LucideIcons.plus),
              Row(children: [
                Expanded(child: TextField(controller: _servicePriceController, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13), decoration: _inputDec('Цена ₸'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _serviceDurationController, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13), decoration: _inputDec('Мин'))),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addService,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Добавить услугу'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Doctors
          _sectionCard(
            title: 'Врачи клиники',
            icon: LucideIcons.users,
            children: [
              if (selectedClinic == null)
                const Text('Сначала создайте клинику', style: TextStyle(color: ClinicTheme.slate))
              else
                FutureBuilder<List<AppUser>>(
                  future: _doctorsFuture,
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                    final doctors = snap.data ?? [];
                    if (doctors.isEmpty) return const Text('Нет врачей', style: TextStyle(color: ClinicTheme.slate));
                    return Column(
                      children: doctors.map((doc) {
                        final assigned = selectedClinic.doctors.contains(doc.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  color: assigned ? ClinicTheme.mintSoft : ClinicTheme.mist,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(child: Text(doc.firstName.isNotEmpty ? doc.firstName[0].toUpperCase() : '?',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: assigned ? ClinicTheme.mint : ClinicTheme.slate))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(doc.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(doc.specialties.join(', '), style: const TextStyle(fontSize: 11, color: ClinicTheme.slate)),
                                ]),
                              ),
                              TextButton(
                                onPressed: assigned ? () => _removeDoctor(doc.id) : () => _assignDoctor(doc.id),
                                style: TextButton.styleFrom(
                                  foregroundColor: assigned ? ClinicTheme.coral : ClinicTheme.azure,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: Text(assigned ? 'Убрать' : 'Добавить', style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────── SCHEDULE TAB ────────────────────────────

  Widget _buildScheduleTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Bulk slot generator
          _sectionCard(
            title: 'Автогенерация слотов',
            icon: LucideIcons.zap,
            children: [
              Text(
                'Создаёт слоты для всех врачей (Пн–Пт, 09–17 ч, по 45 мин)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickSeedUntil,
                    icon: const Icon(LucideIcons.calendar, size: 16),
                    label: Text('До: ${_seedUntil.day.toString().padLeft(2,'0')}.${_seedUntil.month.toString().padLeft(2,'0')}.${_seedUntil.year}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _seedingSlots ? null : _seedSlots,
                    icon: _seedingSlots
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.zap, size: 16),
                    label: Text(_seedingSlots ? 'Создаём...' : 'Создать'),
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 12),

          // Doctor selector
          FutureBuilder<List<AppUser>>(
            future: _doctorsFuture,
            builder: (context, snap) {
              if (!snap.hasData) return _shimmer(56);
              final doctors = snap.data ?? [];
              if (doctors.isEmpty) return const SizedBox.shrink();
              return DentCard(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDoctorId,
                    isExpanded: true,
                    icon: const Icon(LucideIcons.chevronDown, size: 18),
                    hint: const Text('Выбрать врача'),
                    items: doctors.map((d) => DropdownMenuItem(value: d.id, child: Text(d.fullName))).toList(),
                    onChanged: (v) => setState(() { _selectedDoctorId = v; _slotsFuture = _loadSlots(); }),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Manual slot creator
          _sectionCard(
            title: 'Добавить один слот',
            icon: LucideIcons.plusCircle,
            children: [
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: _pickSlotDate,
                  icon: const Icon(LucideIcons.calendar, size: 14),
                  label: Text(_slotDate == null ? 'Дата' : '${_slotDate!.day.toString().padLeft(2,'0')}.${_slotDate!.month.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 13)),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(
                  onPressed: _pickStartTime,
                  child: Text(_slotStart == null ? 'Начало' : '${_slotStart!.hour.toString().padLeft(2,'0')}:${_slotStart!.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 13)),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(
                  onPressed: _pickEndTime,
                  child: Text(_slotEnd == null ? 'Конец' : '${_slotEnd!.hour.toString().padLeft(2,'0')}:${_slotEnd!.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 13)),
                )),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _createSlot, icon: const Icon(LucideIcons.plus, size: 16), label: const Text('Создать слот'))),
            ],
          ),
          const SizedBox(height: 12),

          // Slot list
          FutureBuilder<List<Slot>>(
            future: _slotsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return _shimmer(200);
              final slots = (snap.data ?? [])
                  .where((s) => s.startTime.isAfter(DateTime.now()))
                  .toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));
              if (slots.isEmpty) {
                return DentCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    const Icon(LucideIcons.calendarX, size: 36, color: ClinicTheme.slate),
                    const SizedBox(height: 8),
                    Text('Слоты не найдены', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ClinicTheme.slate)),
                  ]),
                );
              }
              final grouped = <String, List<Slot>>{};
              for (final slot in slots) {
                final key = '${slot.startTime.day.toString().padLeft(2,'0')}.${slot.startTime.month.toString().padLeft(2,'0')}.${slot.startTime.year}';
                grouped.putIfAbsent(key, () => []).add(slot);
              }
              return Column(
                children: grouped.entries.map((entry) => DentCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700, color: ClinicTheme.azure, fontSize: 13)),
                      ),
                      const Divider(height: 1),
                      ...entry.value.map((slot) => ListTile(
                        dense: true,
                        leading: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: slot.status == 'available' ? ClinicTheme.mintSoft : ClinicTheme.coralSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            slot.status == 'available' ? LucideIcons.clock : LucideIcons.lock,
                            size: 16, color: slot.status == 'available' ? ClinicTheme.mint : ClinicTheme.coral,
                          ),
                        ),
                        title: Text(
                          '${slot.startTime.hour.toString().padLeft(2,'0')}:${slot.startTime.minute.toString().padLeft(2,'0')} – ${slot.endTime.hour.toString().padLeft(2,'0')}:${slot.endTime.minute.toString().padLeft(2,'0')}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(slot.status == 'available' ? 'Свободен' : 'Занят', style: TextStyle(fontSize: 11, color: slot.status == 'available' ? ClinicTheme.mint : ClinicTheme.coral)),
                        trailing: slot.status == 'available'
                            ? IconButton(icon: const Icon(LucideIcons.trash2, size: 18, color: ClinicTheme.coral), onPressed: () => _deleteSlot(slot.id))
                            : null,
                      )),
                    ],
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ──────────────────────────── HELPERS ────────────────────────────

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return DentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: ClinicTheme.azure),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ClinicTheme.midnight)),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? type,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: type,
        minLines: minLines,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: _inputDec(label, icon: icon),
      ),
    );
  }

  InputDecoration _inputDec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: ClinicTheme.slate, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, size: 16, color: ClinicTheme.slate) : null,
      filled: true,
      fillColor: ClinicTheme.mist,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE1E4E8))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE1E4E8))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ClinicTheme.azure, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _shimmer(double height) => Container(
    height: height,
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: ClinicTheme.mist, borderRadius: BorderRadius.circular(14)),
  );

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}';

  String _dayLabel(int day) {
    const labels = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    return day >= 0 && day < labels.length ? labels[day] : '—';
  }
}

class SupportManagerDashboard extends StatefulWidget {
  const SupportManagerDashboard({super.key});

  @override
  State<SupportManagerDashboard> createState() => _SupportManagerDashboardState();
}

class _SupportManagerDashboardState extends State<SupportManagerDashboard> {
  String _filter = 'open';
  late Future<List<SupportMessage>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _loadMessages();
  }

  Future<List<SupportMessage>> _loadMessages() {
    final api = context.read<SessionProvider>().apiService;
    return api.fetchSupportMessages(status: _filter == 'all' ? null : _filter);
  }

  Future<void> _refresh() async {
    final future = _loadMessages();
    setState(() => _messagesFuture = future);
    await future;
  }

  Future<void> _logout() async {
    await context.read<SessionProvider>().logout();
  }

  void _openChat(SupportMessage message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupportChatSheet(
        message: message,
        onRefresh: _refresh,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return const Color(0xFF2E7CF6);
      case 'in_progress':
        return const Color(0xFFF5A524);
      case 'resolved':
        return const Color(0xFF1AAB8A);
      default:
        return const Color(0xFF6E7681);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Открыто';
      case 'in_progress':
        return 'В работе';
      case 'resolved':
        return 'Решено';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F6),
      appBar: AppBar(
        title: Text(s.dashSupportTitle),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D1117),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE1E4E8)),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(LucideIcons.refreshCcw, size: 20),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'change_password') {
                showChangePasswordDialog(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'change_password', child: Text(s.profileChangePassword)),
              PopupMenuItem(value: 'logout', child: Text(s.logout)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in [
                    ('all', s.filterAll),
                    ('open', s.dashSupportOpen),
                    ('in_progress', 'В работе'),
                    ('resolved', s.dashSupportClosed),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(entry.$2),
                        selected: _filter == entry.$1,
                        onSelected: (_) => setState(() {
                          _filter = entry.$1;
                          _messagesFuture = _loadMessages();
                        }),
                        selectedColor: const Color(0xFF2E7CF6),
                        labelStyle: TextStyle(
                          color: _filter == entry.$1
                              ? Colors.white
                              : const Color(0xFF0D1117),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        checkmarkColor: Colors.white,
                        backgroundColor: const Color(0xFFF0F3F6),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: FutureBuilder<List<SupportMessage>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 64),
                        const Icon(LucideIcons.messageSquare,
                            size: 48, color: Color(0xFF6E7681)),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'Нет обращений',
                            style: TextStyle(
                                color: Color(0xFF6E7681), fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, indent: 72, endIndent: 0),
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final lastEntry = msg.history.isNotEmpty
                          ? msg.history.last
                          : null;
                      final preview = lastEntry?.content ?? msg.content;
                      final isFromPatient = lastEntry == null ||
                          lastEntry.sender?.id == msg.patient?.id ||
                          lastEntry.sender?.role == 'patient';
                      final statusColor = _statusColor(msg.status);
                      final statusLabel = _statusLabel(msg.status);
                      return Material(
                        color: Colors.white,
                        child: InkWell(
                          onTap: () => _openChat(msg),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      const Color(0xFF2E7CF6).withValues(alpha: 0.12),
                                  child: Text(
                                    (msg.patient?.fullName ?? '?')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF2E7CF6),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              msg.patient?.fullName ??
                                                  'Пользователь',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: Color(0xFF0D1117),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (!isFromPatient)
                                            const Text(
                                              'Вы: ',
                                              style: TextStyle(
                                                color: Color(0xFF6E7681),
                                                fontSize: 13,
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              preview,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF6E7681),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Категория: ${msg.category}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(LucideIcons.chevronRight,
                                    size: 18, color: Color(0xFFD0D5DD)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const DirectorDashboard();
  }
}

class DirectorDashboard extends StatefulWidget {
  const DirectorDashboard({super.key});

  @override
  State<DirectorDashboard> createState() => _DirectorDashboardState();
}

class _DirectorDashboardState extends State<DirectorDashboard> {
  late Future<RoleProfileSummary> _profileFuture;
  late Future<Map<String, List<AppUser>>> _usersFuture;
  late Future<Map<String, dynamic>> _statsFuture;
  List<Clinic> _clinics = [];
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specialtyInputController = TextEditingController();
  final List<String> _specialties = [];
  String? _assignClinicId;
  final _clinicNameController = TextEditingController();
  final _clinicAddressController = TextEditingController();
  final _clinicEmailController = TextEditingController();
  final _clinicPhoneController = TextEditingController();
  String? _selectedClinicId;
  String _clinicStatus = 'draft';
  String _role = 'doctor';
  bool _isSubmitting = false;
  bool _clinicSaving = false;
  String? _clinicQrPayload;
  DateTime? _clinicQrUpdatedAt;
  bool _qrRefreshing = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    _usersFuture = _loadUsers();
    _statsFuture = _loadStats();
    _loadClinics();
  }

  Future<RoleProfileSummary> _loadProfile() {
    final api = context.read<SessionProvider>().apiService;
    return api.fetchRoleProfileSummary();
  }

  Future<Map<String, List<AppUser>>> _loadUsers() async {
    final api = context.read<SessionProvider>().apiService;
    final doctors = await api.fetchUsers(role: 'doctor');
    final admins = await api.fetchUsers(role: 'admin');
    final patients = await api.fetchUsers(role: 'patient');
    final supportManagers = await api.fetchUsers(role: 'support_manager');
    return {
      'doctor': doctors,
      'admin': admins,
      'patient': patients,
      'support_manager': supportManagers,
    };
  }

  Future<Map<String, dynamic>> _loadStats() {
    final api = context.read<SessionProvider>().apiService;
    return api.fetchStatsOverview();
  }

  Future<void> _loadClinics() async {
    final api = context.read<SessionProvider>().apiService;
    final clinics = await api.fetchClinics();
    if (!mounted) return;
    setState(() {
      _clinics = clinics;
      if (clinics.isNotEmpty) {
        _selectedClinicId ??= clinics.first.id;
        final clinic = clinics.firstWhere((item) => item.id == _selectedClinicId, orElse: () => clinics.first);
        _clinicNameController.text = clinic.name;
        _clinicAddressController.text = clinic.address ?? '';
        _clinicEmailController.text = clinic.contacts?.email ?? '';
        _clinicPhoneController.text = clinic.contacts?.phone ?? '';
        _clinicStatus = clinic.status;
        _clinicQrPayload = clinic.qrPayload;
        _clinicQrUpdatedAt = clinic.qrUpdatedAt;
      }
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadProfile();
      _usersFuture = _loadUsers();
      _statsFuture = _loadStats();
    });
    await _loadClinics();
  }

  Future<void> _logout() async {
    await context.read<SessionProvider>().logout();
  }

  void _addSpecialty() {
    final raw = _specialtyInputController.text.trim();
    if (raw.isEmpty) return;
    if (_specialties.contains(raw)) return;
    setState(() {
      _specialties.add(raw);
      _specialtyInputController.clear();
    });
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF6E7681), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF6E7681), size: 18),
      filled: true,
      fillColor: const Color(0xFFF0F3F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E7CF6), width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.createUser(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _role,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        specialties: _role == 'doctor' && _specialties.isNotEmpty
            ? List.of(_specialties)
            : null,
        clinics: (_role == 'doctor' || _role == 'admin') && _assignClinicId != null
            ? [_assignClinicId!]
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Пользователь создан')));
      _firstNameController.clear();
      _lastNameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
      _specialtyInputController.clear();
      setState(() {
        _specialties.clear();
        _assignClinicId = null;
        _usersFuture = _loadUsers();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveClinic() async {
    setState(() => _clinicSaving = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      final payload = {
        'name': _clinicNameController.text.trim(),
        'address': _clinicAddressController.text.trim(),
        'contacts': {
          'email': _clinicEmailController.text.trim(),
          'phone': _clinicPhoneController.text.trim(),
        },
        'status': _clinicStatus,
      };
      if (_selectedClinicId == null) {
        final created = await api.createClinic(payload);
        if (!mounted) return;
        setState(() {
          _clinics = [..._clinics, created];
          _selectedClinicId = created.id;
          _clinicStatus = created.status;
          _clinicQrPayload = created.qrPayload;
          _clinicQrUpdatedAt = created.qrUpdatedAt;
        });
      } else {
        await api.updateClinic(_selectedClinicId!, payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Данные клиники обновлены')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка обновления: $error')));
      }
    } finally {
      if (mounted) setState(() => _clinicSaving = false);
    }
  }

  Future<void> _generateClinicQr() async {
    if (_clinics.isEmpty || _selectedClinicId == null) return;
    setState(() => _qrRefreshing = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      final result = await api.generateClinicQr(_selectedClinicId!);
      if (!mounted) return;
      setState(() {
        _clinicQrPayload = result['payload'] as String?;
        _clinicQrUpdatedAt = result['updatedAt'] != null
            ? DateTime.parse(result['updatedAt'] as String)
            : DateTime.now();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('QR-код обновлён')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Не удалось обновить QR: $error')));
    } finally {
      if (mounted) setState(() => _qrRefreshing = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _specialtyInputController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _clinicEmailController.dispose();
    _clinicPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: ClinicTheme.mist,
        appBar: AppBar(
          backgroundColor: ClinicTheme.snow,
          foregroundColor: ClinicTheme.midnight,
          elevation: 0,
          title: Text(s.dashSuperTitle),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(LucideIcons.refreshCcw, size: 20),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                } else if (value == 'change_password') {
                  showChangePasswordDialog(context);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'change_password', child: Text(s.profileChangePassword)),
                PopupMenuItem(value: 'logout', child: Text(s.logout)),
              ],
            ),
          ],
          bottom: TabBar(
            labelColor: ClinicTheme.azure,
            unselectedLabelColor: ClinicTheme.slate,
            indicatorColor: ClinicTheme.azure,
            tabs: [
              Tab(icon: const Icon(LucideIcons.layoutDashboard, size: 20), text: s.dashAdminStats),
              Tab(icon: const Icon(LucideIcons.users, size: 20), text: 'Сотрудники'),
              Tab(icon: const Icon(LucideIcons.building2, size: 20), text: 'Клиника'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDirectorOverviewTab(),
            _buildDirectorStaffTab(),
            _buildDirectorClinicTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectorOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          FutureBuilder<RoleProfileSummary>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _directorShimmer(80);
              }
              if (!snapshot.hasData) return const SizedBox.shrink();
              return RoleProfileOverview(summary: snapshot.data!);
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _directorShimmer(72);
              }
              final stats = snapshot.data ?? {};
              return Row(
                children: [
                  _directorStatCard('Врачи', stats['doctors']?.toString() ?? '0', LucideIcons.stethoscope, ClinicTheme.azure, ClinicTheme.azureSoft),
                  const SizedBox(width: 10),
                  _directorStatCard('Пациенты', stats['patients']?.toString() ?? '0', LucideIcons.user, ClinicTheme.amber, ClinicTheme.amberSoft),
                  const SizedBox(width: 10),
                  _directorStatCard('Записей', stats['appointments']?.toString() ?? '0', LucideIcons.calendarCheck, ClinicTheme.mint, ClinicTheme.mintSoft),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, List<AppUser>>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return _directorShimmer(120);
              final data = snapshot.data ?? {};
              final admins = data['admin'] ?? [];
              final support = data['support_manager'] ?? [];
              if (admins.isEmpty && support.isEmpty) return const SizedBox.shrink();
              return DentCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Text('Сотрудники', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    ...[...admins, ...support].take(5).map((u) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: ClinicTheme.azureSoft, shape: BoxShape.circle),
                          child: Center(child: Text(u.firstName.isNotEmpty ? u.firstName[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: ClinicTheme.azure, fontSize: 15))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: ClinicTheme.midnight)),
                          Text(u.email, style: const TextStyle(fontSize: 12, color: ClinicTheme.slate)),
                        ])),
                      ]),
                    )),
                    const SizedBox(height: 4),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDirectorStaffTab() {
    final s = context.s;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E4E8)),
            ),
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF2E7CF6), Color(0xFF5B9BFF)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.userCheck,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Добавить сотрудника',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFF0D1117),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RoleChip(
                        label: s.roleDoctor,
                        icon: LucideIcons.stethoscope,
                        selected: _role == 'doctor',
                        color: const Color(0xFF2E7CF6),
                        onTap: () => setState(() => _role = 'doctor'),
                      ),
                      _RoleChip(
                        label: s.roleAdmin,
                        icon: LucideIcons.shieldCheck,
                        selected: _role == 'admin',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => setState(() => _role = 'admin'),
                      ),
                      _RoleChip(
                        label: s.roleSupportManager,
                        icon: LucideIcons.headphones,
                        selected: _role == 'support_manager',
                        color: const Color(0xFF1AAB8A),
                        onTap: () => setState(() => _role = 'support_manager'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: _fieldDecoration('Имя', LucideIcons.user),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Введите имя'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: _fieldDecoration('Фамилия', LucideIcons.user),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Введите фамилию'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _fieldDecoration('Email', LucideIcons.mail),
                    validator: (v) =>
                        v != null && v.contains('@') ? null : 'Введите email',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration:
                        _fieldDecoration('Телефон (необязательно)', LucideIcons.phone),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _fieldDecoration('Пароль', LucideIcons.lock),
                    validator: (v) => v != null && v.length >= 6
                        ? null
                        : 'Мин. 6 символов',
                  ),
                  if (_role == 'doctor') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Специальности',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6E7681),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _specialtyInputController,
                            decoration: _fieldDecoration(
                                'Например: Терапевт', LucideIcons.tags),
                            onFieldSubmitted: (_) => _addSpecialty(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _addSpecialty,
                          icon: const Icon(LucideIcons.plus, size: 18),
                          style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7CF6)),
                        ),
                      ],
                    ),
                    if (_specialties.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _specialties
                            .map((s) => InputChip(
                                  label: Text(s),
                                  onDeleted: () =>
                                      setState(() => _specialties.remove(s)),
                                  backgroundColor: const Color(0xFFE8F1FE),
                                  labelStyle: const TextStyle(
                                    color: Color(0xFF2E7CF6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  side: BorderSide.none,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                  if ((_role == 'doctor' || _role == 'admin') &&
                      _clinics.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _assignClinicId,
                      items: _clinics
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _assignClinicId = v),
                      decoration:
                          _fieldDecoration('Клиника', LucideIcons.building2),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _createUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(LucideIcons.userCheck, size: 18),
                      label: Text(
                        _isSubmitting ? 'Создание…' : 'Создать сотрудника',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<Map<String, List<AppUser>>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard('Обновляем список пользователей');
              } else if (snapshot.hasError) {
                return _buildErrorCard('Ошибка пользователей: ${snapshot.error}');
              }

              final data =
                  snapshot.data ?? {'doctor': [], 'admin': [], 'patient': [], 'support_manager': []};
              return Column(
                children: [
                  _buildUserSection(context, 'Врачи', data['doctor'] ?? []),
                  const SizedBox(height: 16),
                  _buildUserSection(context, 'Администраторы', data['admin'] ?? []),
                  const SizedBox(height: 16),
                  _buildUserSection(context, 'Поддержка', data['support_manager'] ?? []),
                  const SizedBox(height: 16),
                  _buildUserSection(context, 'Пациенты', data['patient'] ?? []),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDirectorClinicTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Clinic picker
          if (_clinics.length > 1) ...[
            DentCard(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClinicId,
                  isExpanded: true,
                  icon: const Icon(LucideIcons.chevronDown, size: 18),
                  items: _clinics.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedClinicId = value;
                      final clinic = _clinics.firstWhere((item) => item.id == value);
                      _clinicNameController.text = clinic.name;
                      _clinicAddressController.text = clinic.address ?? '';
                      _clinicEmailController.text = clinic.contacts?.email ?? '';
                      _clinicPhoneController.text = clinic.contacts?.phone ?? '';
                      _clinicStatus = clinic.status;
                      _clinicQrPayload = clinic.qrPayload;
                      _clinicQrUpdatedAt = clinic.qrUpdatedAt;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Status badge
          if (_clinics.isNotEmpty) ...[
            DentCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                const Icon(LucideIcons.building2, color: ClinicTheme.azure, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(_clinicNameController.text.isEmpty ? 'Клиника' : _clinicNameController.text,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                DentBadge(
                  label: _clinicStatus == 'active' ? 'Активна' : _clinicStatus == 'inactive' ? 'Неактивна' : _clinicStatus == 'blocked' ? 'Заблокирована' : 'Черновик',
                  variant: _clinicStatus == 'active' ? DentBadgeVariant.success : DentBadgeVariant.error,
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // Info form
          _directorSectionCard(
            title: 'Основная информация',
            icon: LucideIcons.info,
            children: [
              _directorField(_clinicNameController, 'Название клиники', LucideIcons.building2),
              _directorField(_clinicAddressController, 'Адрес', LucideIcons.navigation),
              _directorField(_clinicEmailController, 'Email поддержки', LucideIcons.mail, type: TextInputType.emailAddress),
              _directorField(_clinicPhoneController, 'Телефон поддержки', LucideIcons.phone, type: TextInputType.phone),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<String>(
                  value: _clinicStatus,
                  decoration: _directorInputDec('Статус', icon: LucideIcons.shieldCheck),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Черновик')),
                    DropdownMenuItem(value: 'inactive', child: Text('Неактивна')),
                    DropdownMenuItem(value: 'active', child: Text('Активна')),
                    DropdownMenuItem(value: 'blocked', child: Text('Заблокирована')),
                  ],
                  onChanged: (value) { if (value != null) setState(() => _clinicStatus = value); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _clinicSaving ? null : _saveClinic,
              icon: _clinicSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.save, size: 16),
              label: Text(_clinicSaving ? 'Сохранение...' : 'Сохранить'),
            ),
          ),
          const SizedBox(height: 16),

          // QR code section
          _directorSectionCard(
            title: 'QR-код подтверждения',
            icon: LucideIcons.qrCode,
            children: [
              if (_clinicQrPayload != null) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: ClinicTheme.snow, borderRadius: BorderRadius.circular(16), border: Border.all(color: ClinicTheme.mist)),
                    child: QrImageView(data: _clinicQrPayload!, size: 180),
                  ),
                ),
                const SizedBox(height: 8),
                if (_clinicQrUpdatedAt != null)
                  Center(child: Text(
                    'Обновлено: ${_clinicQrUpdatedAt!.day.toString().padLeft(2,'0')}.${_clinicQrUpdatedAt!.month.toString().padLeft(2,'0')} ${_clinicQrUpdatedAt!.hour.toString().padLeft(2,'0')}:${_clinicQrUpdatedAt!.minute.toString().padLeft(2,'0')}',
                    style: const TextStyle(fontSize: 12, color: ClinicTheme.slate),
                  )),
                const SizedBox(height: 12),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('QR-код не создан', style: const TextStyle(color: ClinicTheme.slate)),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _qrRefreshing ? null : _generateClinicQr,
                  icon: _qrRefreshing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.qrCode, size: 16),
                  label: const Text('Обновить QR-код'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _directorStatCard(String label, String value, IconData icon, Color color, Color bg) {
    return Expanded(child: DentCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, size: 17, color: color)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: ClinicTheme.slate)),
      ]),
    ));
  }

  Widget _directorSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return DentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: ClinicTheme.azure),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ClinicTheme.midnight)),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _directorField(TextEditingController controller, String label, IconData icon, {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(fontSize: 14),
        decoration: _directorInputDec(label, icon: icon),
      ),
    );
  }

  InputDecoration _directorInputDec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: ClinicTheme.slate, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, size: 16, color: ClinicTheme.slate) : null,
      filled: true,
      fillColor: ClinicTheme.mist,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE1E4E8))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE1E4E8))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ClinicTheme.azure, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _directorShimmer(double height) => Container(
    height: height,
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: ClinicTheme.mist, borderRadius: BorderRadius.circular(14)),
  );
}

Widget _buildUserSection(BuildContext context, String title, List<AppUser> users) {
  final roleColors = <String, Color>{
    'Врачи': const Color(0xFF2E7CF6),
    'Администраторы': const Color(0xFF8B5CF6),
    'Поддержка': const Color(0xFF1AAB8A),
    'Пациенты': const Color(0xFFF5A524),
  };
  final roleIcons = <String, IconData>{
    'Врачи': LucideIcons.stethoscope,
    'Администраторы': LucideIcons.shieldCheck,
    'Поддержка': LucideIcons.headphones,
    'Пациенты': LucideIcons.user,
  };
  final color = roleColors[title] ?? const Color(0xFF6E7681);
  final icon = roleIcons[title] ?? LucideIcons.users;

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE1E4E8)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF0D1117),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${users.length}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (users.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(LucideIcons.inbox, size: 18, color: color.withValues(alpha: 0.5)),
                const SizedBox(width: 10),
                const Text(
                  'Нет записей',
                  style: TextStyle(color: Color(0xFF6E7681)),
                ),
              ],
            ),
          )
        else
          ...users.asMap().entries.map((entry) {
            final i = entry.key;
            final user = entry.value;
            final isLast = i == users.length - 1;
            final initial = user.firstName.isNotEmpty
                ? user.firstName[0].toUpperCase()
                : '?';
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF0D1117),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6E7681),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _UserStatusToggle(user: user, color: color),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(height: 1, indent: 56),
              ],
            );
          }),
        const SizedBox(height: 4),
      ],
    ),
  );
}

/// Карточка записи для админа клиники: данные пациента + быстрый звонок.
class _AdminApptCard extends StatelessWidget {
  const _AdminApptCard({required this.appointment});

  final Appointment appointment;

  (Color, String, DentBadgeVariant) _statusInfo() {
    switch (appointment.status) {
      case 'confirmed':
        return (ClinicTheme.mint, 'Подтверждена', DentBadgeVariant.success);
      case 'completed':
        return (ClinicTheme.azure, 'Завершена', DentBadgeVariant.info);
      case 'no_show':
        return (ClinicTheme.coral, 'Не явился', DentBadgeVariant.error);
      default:
        return (ClinicTheme.amber, 'Запланирована', DentBadgeVariant.warning);
    }
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть набор номера')),
        );
      }
    }
  }

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel, variant) = _statusInfo();
    final patient = appointment.patient;
    final phone = patient?.phone;
    final hasPhone = phone != null && phone.trim().isNotEmpty;

    return DentCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Время
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _time(appointment.startTime),
                  style: TextStyle(fontWeight: FontWeight.w800, color: statusColor, fontSize: 15),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient?.fullName ?? 'Пациент',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ClinicTheme.midnight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      appointment.service,
                      style: const TextStyle(fontSize: 12, color: ClinicTheme.slate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              DentBadge(label: statusLabel, variant: variant),
            ],
          ),
          const Divider(height: 18),
          // Врач
          Row(children: [
            const Icon(LucideIcons.stethoscope, size: 14, color: ClinicTheme.slate),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                appointment.doctor?.fullName ?? 'Врач не указан',
                style: const TextStyle(fontSize: 13, color: ClinicTheme.midnight, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // Телефон + действия
          Row(children: [
            const Icon(LucideIcons.phone, size: 14, color: ClinicTheme.slate),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasPhone ? phone : 'Телефон не указан',
                style: TextStyle(
                  fontSize: 13,
                  color: hasPhone ? ClinicTheme.midnight : ClinicTheme.slate,
                  fontWeight: hasPhone ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (hasPhone) ...[
              IconButton(
                tooltip: 'Скопировать',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Номер скопирован')),
                  );
                },
                icon: const Icon(Icons.content_copy, size: 16, color: ClinicTheme.slate),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: () => _call(context, phone),
                style: FilledButton.styleFrom(
                  backgroundColor: ClinicTheme.mint,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(LucideIcons.phone, size: 15),
                label: const Text('Позвонить', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ]),
          if (patient?.email != null && patient!.email.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(LucideIcons.mail, size: 14, color: ClinicTheme.slate),
              const SizedBox(width: 6),
              Expanded(
                child: Text(patient.email,
                    style: const TextStyle(fontSize: 12, color: ClinicTheme.slate),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserStatusToggle extends StatefulWidget {
  const _UserStatusToggle({required this.user, required this.color});
  final AppUser user;
  final Color color;

  @override
  State<_UserStatusToggle> createState() => _UserStatusToggleState();
}

class _UserStatusToggleState extends State<_UserStatusToggle> {
  bool _loading = false;

  Future<void> _toggle() async {
    setState(() => _loading = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.updateUserStatus(widget.user.id, !widget.user.isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.user.isActive
                ? '${widget.user.firstName} деактивирован'
                : '${widget.user.firstName} активирован',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.user.isActive;
    if (_loading) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFEE8E8)
              : const Color(0xFFE6F7F1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isActive ? 'Откл.' : 'Вкл.',
          style: TextStyle(
            color: isActive
                ? const Color(0xFFEF4444)
                : const Color(0xFF1AAB8A),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

Widget _buildLoadingCard(String message) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

Widget _buildErrorCard(String message) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message),
    ),
  );
}

class _SupportChatSheet extends StatefulWidget {
  const _SupportChatSheet({required this.message, required this.onRefresh});

  final SupportMessage message;
  final Future<void> Function() onRefresh;

  @override
  State<_SupportChatSheet> createState() => _SupportChatSheetState();
}

class _SupportChatSheetState extends State<_SupportChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late SupportMessage _message;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _message = widget.message;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.replySupportMessage(
          messageId: _message.id, content: _controller.text.trim());
      _controller.clear();
      final refreshed = await api.fetchSupportMessages();
      final updated =
          refreshed.where((m) => m.id == _message.id).toList();
      if (mounted && updated.isNotEmpty) {
        setState(() => _message = updated.first);
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      }
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.updateSupportMessageStatus(_message.id, status: status);
      widget.onRefresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientId = _message.patient?.id;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F3F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD0D5DD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          // Header
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      const Color(0xFF2E7CF6).withValues(alpha: 0.12),
                  child: Text(
                    (_message.patient?.fullName ?? '?')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF2E7CF6),
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
                        _message.patient?.fullName ?? 'Пользователь',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF0D1117),
                        ),
                      ),
                      Text(
                        'Категория: ${_message.category}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6E7681)),
                      ),
                    ],
                  ),
                ),
                if (_message.status != 'in_progress')
                  TextButton(
                    onPressed: () => _updateStatus('in_progress'),
                    child: const Text('В работу',
                        style: TextStyle(fontSize: 13)),
                  ),
                if (_message.status != 'resolved')
                  TextButton(
                    onPressed: () => _updateStatus('resolved'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1AAB8A)),
                    child: const Text('Решить',
                        style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _message.history.isEmpty
                  ? 1
                  : _message.history.length,
              itemBuilder: (context, index) {
                if (_message.history.isEmpty) {
                  return _SupportChatBubble(
                    entry: SupportMessageEntry(
                      sender: _message.patient,
                      content: _message.content,
                      createdAt: DateTime.now(),
                    ),
                    isPatient: true,
                  );
                }
                final entry = _message.history[index];
                final isPatient = entry.sender?.id == patientId ||
                    entry.sender?.role == 'patient';
                return _SupportChatBubble(
                    entry: entry, isPatient: isPatient);
              },
            ),
          ),
          // Reply bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Ответ клиенту…',
                      hintStyle:
                          const TextStyle(color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: const Color(0xFFF0F3F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _sending
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : GestureDetector(
                        onTap: _send,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2E7CF6),
                                Color(0xFF5B9BFF)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(LucideIcons.send,
                              color: Colors.white, size: 20),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportChatBubble extends StatelessWidget {
  const _SupportChatBubble({required this.entry, required this.isPatient});

  final SupportMessageEntry entry;
  final bool isPatient;

  @override
  Widget build(BuildContext context) {
    final senderName = entry.sender?.fullName ??
        (isPatient ? 'Пациент' : 'Поддержка');
    final time = '${entry.createdAt.day.toString().padLeft(2, '0')}.'
        '${entry.createdAt.month.toString().padLeft(2, '0')} '
        '${entry.createdAt.hour.toString().padLeft(2, '0')}:'
        '${entry.createdAt.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: isPatient ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: isPatient ? Colors.white : const Color(0xFFDDEBFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3E7EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$senderName • $time',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6E7681),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(entry.content),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE1E4E8)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D1117),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6E7681),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showChangePasswordDialog(BuildContext context) async {
  final currentController = TextEditingController();
  final newController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isSubmitting = false;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(builder: (context, setState) {
        final s = context.sRead;
        Future<void> submit() async {
          if (isSubmitting) return;
          if (!formKey.currentState!.validate()) return;
          setState(() => isSubmitting = true);
          final api = context.read<SessionProvider>().apiService;
          try {
            await api.changePassword(
              currentPassword: currentController.text,
              newPassword: newController.text,
            );
            if (!context.mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Пароль обновлен')));
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Ошибка: $error')));
            }
          } finally {
            if (context.mounted) setState(() => isSubmitting = false);
          }
        }

        return AlertDialog(
          title: Text(s.profileChangePassword),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: s.profileCurrentPassword),
                  validator: (value) => value == null || value.isEmpty ? 'Введите пароль' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: s.profileNewPassword),
                  validator: (value) =>
                      value != null && value.length >= 6 ? null : 'Мин. 6 символов',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
              child: Text(s.cancel),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : submit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.save),
            ),
          ],
        );
      });
    },
  );

  currentController.dispose();
  newController.dispose();
}
