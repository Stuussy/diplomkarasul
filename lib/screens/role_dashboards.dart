import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/appointment.dart';
import '../models/clinic.dart';
import '../models/profile_summary.dart';
import '../models/support_message.dart';
import '../models/slot.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import '../widgets/role_profile_overview.dart';
import 'medical_records_screen.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Завершить приём?'),
          content: Text(
            'Приём «$patientName» (${appointment.service}) будет помечен как завершённый.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(LucideIcons.checkCheck, size: 16),
              label: const Text('Завершить'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await api.completeAppointment(appointment.id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Приём завершён ✓')));
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Рабочее место врача'),
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
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'change_password', child: Text('Сменить пароль')),
                PopupMenuItem(value: 'logout', child: Text('Выйти из аккаунта')),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(LucideIcons.layoutDashboard, size: 20), text: 'Обзор'),
              Tab(icon: Icon(LucideIcons.calendarCheck, size: 20), text: 'Записи'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDoctorOverviewTab(),
            _buildDoctorAppointmentsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          FutureBuilder<RoleProfileSummary>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard('Загружаем профиль');
              } else if (snapshot.hasError) {
                return _buildErrorCard('Ошибка профиля: ${snapshot.error}');
              } else if (!snapshot.hasData) {
                return _buildErrorCard('Нет данных профиля');
              }
              return RoleProfileOverview(summary: snapshot.data!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorAppointmentsTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          FutureBuilder<List<Appointment>>(
            future: _appointmentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard('Загружаем приемы');
              } else if (snapshot.hasError) {
                return _buildErrorCard('Ошибка загрузки приемов: ${snapshot.error}');
              }
              final appointments = snapshot.data ?? [];
              if (appointments.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Ближайшие приемы',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text('Нет записей на выбранный период.'),
                      ],
                    ),
                  ),
                );
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ближайшие приемы',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      ...appointments.map(
                        (appointment) {
                          final isActive = appointment.status == 'scheduled' ||
                              appointment.status == 'confirmed';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              appointment.status == 'completed'
                                  ? LucideIcons.checkCheck
                                  : appointment.status == 'confirmed'
                                      ? LucideIcons.checkCircle
                                      : LucideIcons.clock,
                              color: appointment.status == 'completed'
                                  ? const Color(0xFF1AAB8A)
                                  : appointment.status == 'confirmed'
                                      ? const Color(0xFF1AAB8A)
                                      : const Color(0xFF2E7CF6),
                            ),
                            title: Text(
                                '${appointment.patient?.fullName ?? 'Пациент'} • ${appointment.service}'),
                            subtitle: Text(
                                '${_formatDate(appointment.startTime)} · ${appointment.status}'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                if (isActive)
                                  IconButton(
                                    tooltip: 'Завершить приём',
                                    onPressed: () => _completeAppointment(appointment),
                                    icon: const Icon(LucideIcons.checkCheck,
                                        size: 20, color: Color(0xFF1AAB8A)),
                                  ),
                                IconButton(
                                  tooltip: 'Медкарта',
                                  onPressed: appointment.patient == null
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => MedicalRecordsScreen(
                                                patientId: appointment.patient!.id,
                                                title:
                                                    'Карта: ${appointment.patient!.fullName}',
                                                allowCreate: true,
                                                allowEdit: true,
                                              ),
                                            ),
                                          );
                                        },
                                  icon: const Icon(LucideIcons.folderHeart, size: 20),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
  List<Clinic> _clinics = [];
  String? _selectedClinicId;
  Future<List<Slot>>? _slotsFuture;
  String? _selectedDoctorId;
  DateTime? _slotDate;
  TimeOfDay? _slotStart;
  TimeOfDay? _slotEnd;

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
    for (final entry in _workingHours) {
      entry.dispose();
    }
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    _serviceDurationController.dispose();
    super.dispose();
  }

  Future<RoleProfileSummary> _loadProfile() {
    final api = context.read<SessionProvider>().apiService;
    return api.fetchRoleProfileSummary();
  }

  Future<void> _loadClinics() async {
    final api = context.read<SessionProvider>().apiService;
    final clinics = await api.fetchClinics();
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
    final api = context.read<SessionProvider>().apiService;
    final doctors = await api.fetchDoctors();
    if (_selectedDoctorId == null && doctors.isNotEmpty) {
      _selectedDoctorId = doctors.first.id;
      _slotsFuture = _loadSlots();
    }
    return doctors;
  }

  Future<List<Slot>> _loadSlots() {
    final api = context.read<SessionProvider>().apiService;
    return api.fetchSlots(doctorId: _selectedDoctorId, status: null);
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadProfile();
      _doctorsFuture = _loadDoctors();
      if (_selectedDoctorId != null) {
        _slotsFuture = _loadSlots();
      }
    });
    await _loadClinics();
  }

  Future<void> _logout() async {
    await context.read<SessionProvider>().logout();
  }

  void _fillClinicForm(Clinic clinic) {
    _nameController.text = clinic.name;
    _descriptionController.text = clinic.description ?? '';
    _cityController.text = clinic.city ?? '';
    _addressController.text = clinic.address ?? '';
    _phoneController.text = clinic.contacts?.phone ?? '';
    _emailController.text = clinic.contacts?.email ?? '';
    if (clinic.workingHours.isNotEmpty) {
      for (final entry in _workingHours) {
        final slot = clinic.workingHours.firstWhere(
          (item) => item.day == entry.day,
          orElse: () => ClinicWorkingHour(day: entry.day, open: '09:00', close: '18:00', isClosed: false),
        );
        entry.openController.text = slot.open ?? '09:00';
        entry.closeController.text = slot.close ?? '18:00';
        entry.isClosed = slot.isClosed;
      }
    }
  }

  List<Map<String, dynamic>> _buildWorkingHoursPayload() {
    return _workingHours
        .map(
          (entry) => {
            'day': entry.day,
            'open': entry.openController.text.trim(),
            'close': entry.closeController.text.trim(),
            'isClosed': entry.isClosed,
          },
        )
        .toList();
  }

  Future<void> _saveClinic({String? status}) async {
    final api = context.read<SessionProvider>().apiService;
    final payload = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'city': _cityController.text.trim(),
      'address': _addressController.text.trim(),
      'contacts': {
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      },
      'workingHours': _buildWorkingHoursPayload(),
      if (status != null) 'status': status,
    };

    try {
      if (_selectedClinicId == null) {
        final clinic = await api.createClinic(payload);
        if (!mounted) return;
        setState(() {
          _clinics = [..._clinics, clinic];
          _selectedClinicId = clinic.id;
        });
      } else {
        await api.updateClinic(_selectedClinicId!, payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные клиники сохранены.')),
      );
      _loadClinics();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $error')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Услуга добавлена.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка добавления услуги: $error')),
      );
    }
  }

  Future<void> _assignDoctor(String doctorId) async {
    if (_selectedClinicId == null) return;
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.addClinicDoctor(_selectedClinicId!, doctorId);
      await _loadClinics();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось назначить врача: $error')),
      );
    }
  }

  Future<void> _removeDoctor(String doctorId) async {
    if (_selectedClinicId == null) return;
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.removeClinicDoctor(_selectedClinicId!, doctorId);
      await _loadClinics();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось убрать врача: $error')),
      );
    }
  }

  Future<void> _pickSlotDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (result != null) {
      setState(() => _slotDate = result);
    }
  }

  Future<TimeOfDay?> _show24hTimePicker(TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Future<void> _pickStartTime() async {
    final result = await _show24hTimePicker(const TimeOfDay(hour: 9, minute: 0));
    if (result != null) setState(() => _slotStart = result);
  }

  Future<void> _pickEndTime() async {
    final result = await _show24hTimePicker(const TimeOfDay(hour: 9, minute: 30));
    if (result != null) setState(() => _slotEnd = result);
  }

  Future<void> _createSlot() async {
    if (_selectedDoctorId == null ||
        _selectedClinicId == null ||
        _slotDate == null ||
        _slotStart == null ||
        _slotEnd == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Заполните все поля расписания')));
      return;
    }

    final start = DateTime(
      _slotDate!.year,
      _slotDate!.month,
      _slotDate!.day,
      _slotStart!.hour,
      _slotStart!.minute,
    );
    final end = DateTime(
      _slotDate!.year,
      _slotDate!.month,
      _slotDate!.day,
      _slotEnd!.hour,
      _slotEnd!.minute,
    );

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Время окончания должно быть позже начала')),
      );
      return;
    }

    final api = context.read<SessionProvider>().apiService;
    try {
      await api.createSlot(
        doctorId: _selectedDoctorId!,
        clinicId: _selectedClinicId!,
        startTime: start,
        endTime: end,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Слот создан')));
      setState(() {
        _slotsFuture = _loadSlots();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка создания слота: $e')));
    }
  }

  Future<void> _deleteSlot(String slotId) async {
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.deleteSlot(slotId);
      if (!mounted) return;
      setState(() {
        _slotsFuture = _loadSlots();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить слот: $e')),
      );
    }
  }

  Clinic? get _selectedClinic {
    if (_selectedClinicId == null) return null;
    return _clinics.firstWhere(
      (clinic) => clinic.id == _selectedClinicId,
      orElse: () => _clinics.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Панель администратора клиники'),
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
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'change_password', child: Text('Сменить пароль')),
                PopupMenuItem(value: 'logout', child: Text('Выйти из аккаунта')),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(LucideIcons.userCircle, size: 20), text: 'Обзор'),
              Tab(icon: Icon(LucideIcons.building2, size: 20), text: 'Клиника'),
              Tab(icon: Icon(LucideIcons.calendarClock, size: 20), text: 'Расписание'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAdminOverviewTab(),
            _buildClinicManagementTab(),
            _buildAdminSchedulingTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          FutureBuilder<RoleProfileSummary>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard('Собираем информацию профиля');
              } else if (snapshot.hasError) {
                return _buildErrorCard('Ошибка профиля: ${snapshot.error}');
              } else if (!snapshot.hasData) {
                return _buildErrorCard('Нет данных профиля');
              }
              return RoleProfileOverview(summary: snapshot.data!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClinicManagementTab() {
    final selectedClinic = _selectedClinic;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_clinics.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _selectedClinicId,
              items: _clinics
                  .map((clinic) => DropdownMenuItem(
                        value: clinic.id,
                        child: Text(clinic.name),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedClinicId = value;
                  final clinic = _clinics.firstWhere((item) => item.id == value);
                  _fillClinicForm(clinic);
                });
              },
              decoration: const InputDecoration(
                labelText: 'Выберите клинику',
                border: OutlineInputBorder(),
              ),
            )
          else
            const Text('Клиника еще не создана. Заполните форму ниже.'),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Название клиники',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Описание',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'Город',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Адрес',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Телефон',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'График по дням',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._workingHours.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      _dayLabel(entry.day),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: entry.openController,
                      enabled: !entry.isClosed,
                      decoration: const InputDecoration(
                        labelText: 'Открытие',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: entry.closeController,
                      enabled: !entry.isClosed,
                      decoration: const InputDecoration(
                        labelText: 'Закрытие',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      const Text('Выходной', style: TextStyle(fontSize: 12)),
                      Switch(
                        value: entry.isClosed,
                        onChanged: (value) {
                          setState(() => entry.isClosed = value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _saveClinic(),
                child: const Text('Сохранить черновик'),
              ),
              if (selectedClinic != null)
                ElevatedButton(
                  onPressed: () => _saveClinic(status: 'active'),
                  child: const Text('Активировать'),
                ),
              if (selectedClinic != null)
                OutlinedButton(
                  onPressed: () => _saveClinic(status: 'inactive'),
                  child: const Text('Сделать неактивной'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Услуги',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _serviceNameController,
            decoration: const InputDecoration(
              labelText: 'Название услуги',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _servicePriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Цена',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _serviceDurationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Длительность (мин)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _addService,
            child: const Text('Добавить услугу'),
          ),
          const SizedBox(height: 12),
          if (selectedClinic != null && selectedClinic.services.isNotEmpty)
            Column(
              children: selectedClinic.services
                  .map(
                    (service) => ListTile(
                      title: Text(service.name),
                      subtitle: Text('${service.price} тг • ${service.durationMinutes} мин'),
                    ),
                  )
                  .toList(),
            )
          else
            const Text('Услуг пока нет.'),
          const SizedBox(height: 24),
          const Text(
            'Специалисты',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (selectedClinic == null)
            const Text('Сначала создайте клинику, чтобы назначать врачей.')
          else
            FutureBuilder<List<AppUser>>(
              future: _doctorsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final doctors = snapshot.data ?? [];
                if (doctors.isEmpty) {
                  return const Text('Нет доступных врачей.');
                }
                return Column(
                  children: doctors
                      .map((doctor) => ListTile(
                            title: Text(doctor.fullName),
                            subtitle: Text(doctor.specialties.join(', ')),
                            trailing: selectedClinic.doctors.contains(doctor.id)
                                ? TextButton(
                                    onPressed: () => _removeDoctor(doctor.id),
                                    child: const Text('Убрать'),
                                  )
                                : TextButton(
                                    onPressed: () => _assignDoctor(doctor.id),
                                    child: const Text('Назначить'),
                                  ),
                          ))
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAdminSchedulingTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          FutureBuilder<List<AppUser>>(
            future: _doctorsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return _buildLoadingCard('Загружаем врачей');
              }
              final doctors = snapshot.data ?? [];
              if (doctors.isEmpty) {
                return _buildErrorCard('Врачи не найдены');
              }
              return DropdownButtonFormField<String>(
                initialValue: _selectedDoctorId,
                items: doctors
                    .map((doctor) => DropdownMenuItem(
                          value: doctor.id,
                          child: Text(doctor.fullName),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDoctorId = value;
                    _slotsFuture = _loadSlots();
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Врач',
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickSlotDate,
                  child: Text(_slotDate == null
                      ? 'Выбрать дату'
                      : '${_slotDate!.day}.${_slotDate!.month}.${_slotDate!.year}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickStartTime,
                  child: Text(_slotStart == null
                      ? 'Начало'
                      : '${_slotStart!.hour.toString().padLeft(2, '0')}:${_slotStart!.minute.toString().padLeft(2, '0')}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickEndTime,
                  child: Text(_slotEnd == null
                      ? 'Конец'
                      : '${_slotEnd!.hour.toString().padLeft(2, '0')}:${_slotEnd!.minute.toString().padLeft(2, '0')}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _createSlot,
            child: const Text('Создать слот'),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Slot>>(
            future: _slotsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard('Загружаем слоты');
              }
              final slots = snapshot.data ?? [];
              if (slots.isEmpty) {
                return _buildErrorCard('Слоты не найдены');
              }
              return Column(
                children: slots
                    .map(
                      (slot) => ListTile(
                        title: Text('${_formatDate(slot.startTime)} - ${_formatTime(slot.endTime)}'),
                        subtitle: Text(slot.status),
                        trailing: slot.status == 'available'
                            ? IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 20),
                                onPressed: () => _deleteSlot(slot.id),
                              )
                            : null,
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

  Widget _buildLoadingCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(text),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String text) {
    return Card(
      color: const Color(0xFFFEE8E8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _dayLabel(int day) {
    switch (day) {
      case 0:
        return 'Вс';
      case 1:
        return 'Пн';
      case 2:
        return 'Вт';
      case 3:
        return 'Ср';
      case 4:
        return 'Чт';
      case 5:
        return 'Пт';
      case 6:
        return 'Сб';
      default:
        return '—';
    }
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F6),
      appBar: AppBar(
        title: const Text('Обращения'),
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
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'change_password', child: Text('Сменить пароль')),
              PopupMenuItem(value: 'logout', child: Text('Выйти из аккаунта')),
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
                  for (final entry in const [
                    ('all', 'Все'),
                    ('open', 'Открытые'),
                    ('in_progress', 'В работе'),
                    ('resolved', 'Решённые'),
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Панель superadmin'),
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
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'change_password', child: Text('Сменить пароль')),
              PopupMenuItem(value: 'logout', child: Text('Выйти из аккаунта')),
            ],
          ),
        ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(LucideIcons.layoutDashboard, size: 20), text: 'Обзор'),
              Tab(icon: Icon(LucideIcons.users, size: 20), text: 'Сотрудники'),
              Tab(icon: Icon(LucideIcons.building2, size: 20), text: 'Клиника'),
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
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          FutureBuilder<RoleProfileSummary>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard('Обновляем профиль');
              } else if (snapshot.hasError) {
                return _buildErrorCard('Ошибка профиля: ${snapshot.error}');
              } else if (!snapshot.hasData) {
                return _buildErrorCard('Нет данных профиля');
              }
              return RoleProfileOverview(summary: snapshot.data!);
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard('Собираем статистику');
              } else if (snapshot.hasError) {
                return _buildErrorCard('Ошибка статистики: ${snapshot.error}');
              }
              final stats = snapshot.data ?? {};
              return Row(
                children: [
                  _StatCard(label: 'Врачи', value: stats['doctors']?.toString() ?? '0'),
                  const SizedBox(width: 12),
                  _StatCard(label: 'Пациенты', value: stats['patients']?.toString() ?? '0'),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Записей',
                    value: stats['appointments']?.toString() ?? '0',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDirectorStaffTab() {
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
                        label: 'Врач',
                        icon: LucideIcons.stethoscope,
                        selected: _role == 'doctor',
                        color: const Color(0xFF2E7CF6),
                        onTap: () => setState(() => _role = 'doctor'),
                      ),
                      _RoleChip(
                        label: 'Администратор',
                        icon: LucideIcons.shieldCheck,
                        selected: _role == 'admin',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => setState(() => _role = 'admin'),
                      ),
                      _RoleChip(
                        label: 'Поддержка',
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
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Данные клиники',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  if (_clinics.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedClinicId,
                      items: _clinics
                          .map(
                            (clinic) => DropdownMenuItem(
                              value: clinic.id,
                              child: Text(clinic.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedClinicId = value;
                          final clinic =
                              _clinics.firstWhere((item) => item.id == value);
                          _clinicNameController.text = clinic.name;
                          _clinicAddressController.text = clinic.address ?? '';
                          _clinicEmailController.text = clinic.contacts?.email ?? '';
                          _clinicPhoneController.text = clinic.contacts?.phone ?? '';
                          _clinicStatus = clinic.status;
                          _clinicQrPayload = clinic.qrPayload;
                          _clinicQrUpdatedAt = clinic.qrUpdatedAt;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Клиника',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _clinicStatus,
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _clinicStatus = value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Статус',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clinicNameController,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clinicAddressController,
                    decoration: const InputDecoration(labelText: 'Адрес'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clinicEmailController,
                    decoration: const InputDecoration(labelText: 'Email поддержки'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clinicPhoneController,
                    decoration: const InputDecoration(labelText: 'Телефон поддержки'),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _clinicSaving ? null : _saveClinic,
                    child: _clinicSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить'),
                  ),
                ),
                const SizedBox(height: 24),
                if (_clinicQrPayload != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QR для подтверждения визита',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: QrImageView(
                          data: _clinicQrPayload!,
                          size: 200,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_clinicQrUpdatedAt != null)
                        Text(
                          'Обновлено: ${_clinicQrUpdatedAt!.day.toString().padLeft(2, '0')}.'
                          '${_clinicQrUpdatedAt!.month.toString().padLeft(2, '0')} '
                          '${_clinicQrUpdatedAt!.hour.toString().padLeft(2, '0')}:'
                          '${_clinicQrUpdatedAt!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Color(0xFF6E7681)),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _qrRefreshing ? null : _generateClinicQr,
                    icon: _qrRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.qrCode, size: 20),
                    label: const Text('Обновить QR-код подтверждения'),
                  ),
                ),
              ],
            ),
          ),
        ),
        ],
      ),
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
          title: const Text('Сменить пароль'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Текущий пароль'),
                  validator: (value) => value == null || value.isEmpty ? 'Введите пароль' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Новый пароль'),
                  validator: (value) =>
                      value != null && value.length >= 6 ? null : 'Мин. 6 символов',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : submit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Сохранить'),
            ),
          ],
        );
      });
    },
  );

  currentController.dispose();
  newController.dispose();
}
