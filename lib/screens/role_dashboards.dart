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
                        (appointment) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            appointment.status == 'confirmed'
                                ? LucideIcons.checkCircle
                                : LucideIcons.clock,
                            color: appointment.status == 'confirmed' ? const Color(0xFF1AAB8A) : const Color(0xFF2E7CF6),
                          ),
                          title: Text(
                              '${appointment.patient?.fullName ?? 'Пациент'} • ${appointment.service}'),
                          subtitle:
                              Text('${_formatDate(appointment.startTime)} · ${appointment.status}'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
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
                        ),
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
  final Map<String, TextEditingController> _replyControllers = {};

  @override
  void initState() {
    super.initState();
    _messagesFuture = _loadMessages();
  }

  @override
  void dispose() {
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<List<SupportMessage>> _loadMessages() {
    final api = context.read<SessionProvider>().apiService;
    return api.fetchSupportMessages(status: _filter == 'all' ? null : _filter);
  }

  Future<void> _refresh() async {
    final future = _loadMessages();
    setState(() { _messagesFuture = future; });
    await future;
  }

  TextEditingController _controllerForThread(String id) {
    return _replyControllers.putIfAbsent(id, TextEditingController.new);
  }

  Future<void> _sendSupportReply(SupportMessage message) async {
    final controller = _controllerForThread(message.id);
    if (controller.text.trim().isEmpty) return;
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.replySupportMessage(messageId: message.id, content: controller.text.trim());
      controller.clear();
      if (!mounted) return;
      final future = _loadMessages();
      setState(() { _messagesFuture = future; });
      await future;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Не удалось отправить ответ: $error')));
    }
  }

  Future<void> _updateStatus(SupportMessage message, String status) async {
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.updateSupportMessageStatus(message.id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Статус обращения обновлен на "$status"')),
      );
      _refresh();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить: $error')),
      );
    }
  }

  Future<void> _logout() async {
    await context.read<SessionProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поддержка пользователей'),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: _filter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Все')),
                DropdownMenuItem(value: 'open', child: Text('Открытые')),
                DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
                DropdownMenuItem(value: 'resolved', child: Text('Решенные')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _filter = value;
                  _messagesFuture = _loadMessages();
                });
              },
              decoration: const InputDecoration(
                labelText: 'Фильтр статуса',
                border: OutlineInputBorder(),
              ),
            ),
          ),
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
                      padding: const EdgeInsets.all(16),
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('Нет обращений')),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final controller = _controllerForThread(message.id);
                    final patientId = message.patient?.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.patient?.fullName ?? 'Пользователь',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text('Категория: ${message.category} • Статус: ${message.status}'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final entry in message.history)
                                    _SupportChatBubble(
                                      entry: entry,
                                      isPatient: entry.sender?.id == patientId ||
                                          entry.sender?.role == 'patient',
                                    ),
                                  if (message.history.isEmpty)
                                    Text(
                                      message.content,
                                      style: const TextStyle(color: Color(0xFF6E7681)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _updateStatus(message, 'in_progress'),
                                  child: const Text('В работу'),
                                ),
                                TextButton(
                                  onPressed: () => _updateStatus(message, 'resolved'),
                                  child: const Text('Решить'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: controller,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'Ответ клиенту',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  onPressed: () => _sendSupportReply(message),
                                  icon: const Icon(LucideIcons.send, size: 20),
                                ),
                              ),
                            ),
                          ],
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
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Пользователь создан')));
      _firstNameController.clear();
      _lastNameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() {
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
          const Text(
            'Создать нового сотрудника',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(labelText: 'Имя'),
                            validator: (value) =>
                                value == null || value.isEmpty ? 'Введите имя' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(labelText: 'Фамилия'),
                            validator: (value) =>
                                value == null || value.isEmpty ? 'Введите фамилию' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          value != null && value.contains('@') ? null : 'Введите email',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Пароль'),
                      obscureText: true,
                      validator: (value) =>
                          value != null && value.length >= 6 ? null : 'Мин. 6 символов',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      items: const [
                        DropdownMenuItem(value: 'doctor', child: Text('Врач')),
                        DropdownMenuItem(value: 'admin', child: Text('Администратор')),
                        DropdownMenuItem(value: 'support_manager', child: Text('Менеджер поддержки')),
                      ],
                      onChanged: (value) => setState(() => _role = value ?? 'doctor'),
                      decoration: const InputDecoration(labelText: 'Роль'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _createUser,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Создать'),
                      ),
                    ),
                  ],
                ),
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
  return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (users.isEmpty)
              const Text('Пока нет данных.')
            else
              ...users.map(
                (user) => ListTile(
                  leading: CircleAvatar(child: Text(user.firstName[0].toUpperCase())),
                  title: Text(user.fullName),
                  subtitle: Text('${user.email} • ${user.isActive ? 'активен' : 'заблокирован'}'),
                  trailing: TextButton(
                    onPressed: () async {
                      final api = context.read<SessionProvider>().apiService;
                      await api.updateUserStatus(user.id, !user.isActive);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            user.isActive ? 'Пользователь деактивирован' : 'Пользователь активирован',
                          ),
                        ),
                      );
                    },
                    child: Text(user.isActive ? 'Деактивировать' : 'Активировать'),
                  ),
                ),
              ),
          ],
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Color(0xFF6E7681))),
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
