import 'package:flutter/material.dart';
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
              icon: const Icon(Icons.refresh),
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
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Обзор'),
              Tab(icon: Icon(Icons.event_available_outlined), text: 'Записи'),
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
                                ? Icons.check_circle_outline
                                : Icons.schedule,
                            color: appointment.status == 'confirmed' ? Colors.green : Colors.blue,
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
                                icon: const Icon(Icons.folder_shared_outlined),
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

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<RoleProfileSummary> _profileFuture;
  String _filter = 'open';
  late Future<List<SupportMessage>> _messagesFuture;
  late Future<List<AppUser>> _doctorsFuture;
  Future<List<Slot>>? _slotsFuture;
  List<Clinic> _clinics = [];
  String? _selectedDoctorId;
  String? _selectedClinicId;
  DateTime? _slotDate;
  TimeOfDay? _slotStart;
  TimeOfDay? _slotEnd;
  final Map<String, TextEditingController> _replyControllers = {};

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    _messagesFuture = _loadMessages();
    _doctorsFuture = _loadDoctors();
    _loadClinics();
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
      _selectedClinicId ??= clinics.isNotEmpty ? clinics.first.id : null;
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

  Future<List<SupportMessage>> _loadMessages() {
    final api = context.read<SessionProvider>().apiService;
    return api.fetchSupportMessages(status: _filter == 'all' ? null : _filter);
  }

  Future<List<Slot>> _loadSlots() {
    final api = context.read<SessionProvider>().apiService;
    return api.fetchSlots(doctorId: _selectedDoctorId, status: null);
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadProfile();
      _messagesFuture = _loadMessages();
      _doctorsFuture = _loadDoctors();
      if (_selectedDoctorId != null) {
        _slotsFuture = _loadSlots();
      }
    });
  }

  Future<void> _logout() async {
    await context.read<SessionProvider>().logout();
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
      setState(() => _messagesFuture = _loadMessages());
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Панель администратора'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
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
              Tab(icon: Icon(Icons.person_outline), text: 'Обзор'),
              Tab(icon: Icon(Icons.schedule_outlined), text: 'Расписание'),
              Tab(icon: Icon(Icons.support_agent_outlined), text: 'Поддержка'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAdminOverviewTab(),
            _buildAdminSchedulingTab(),
            _buildAdminSupportTab(),
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard('Загружаем врачей');
              } else if (snapshot.hasError) {
                return _buildErrorCard('Ошибка врачей: ${snapshot.error}');
              }
              final doctors = snapshot.data ?? [];
              if (doctors.isEmpty) {
                return const Text('Нет врачей для составления расписания.');
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Создать слот расписания',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _selectedDoctorId ?? doctors.first.id,
                        items: doctors
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(d.fullName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDoctorId = value;
                            _slotsFuture = _loadSlots();
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Врач'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _selectedClinicId,
                        items: _clinics
                            .map((clinic) => DropdownMenuItem(
                                  value: clinic.id,
                                  child: Text(clinic.name),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedClinicId = value),
                        decoration: const InputDecoration(labelText: 'Клиника'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickSlotDate,
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(
                                _slotDate == null
                                    ? 'Дата'
                                    : '${_slotDate!.day}.${_slotDate!.month}.${_slotDate!.year}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickStartTime,
                              icon: const Icon(Icons.schedule_outlined),
                              label: Text(_slotStart == null ? 'Начало' : _slotStart!.format(context)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickEndTime,
                              icon: const Icon(Icons.schedule),
                              label: Text(_slotEnd == null ? 'Конец' : _slotEnd!.format(context)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _createSlot,
                          child: const Text('Добавить слот'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Slot>>(
            future: _slotsFuture,
            builder: (context, snapshot) {
              if (_slotsFuture == null) {
                return const SizedBox.shrink();
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard('Загружаем слоты');
              } else if (snapshot.hasError) {
                return _buildErrorCard('Ошибка слотов: ${snapshot.error}');
              }
              final slots = snapshot.data ?? [];
              if (slots.isEmpty) {
                return const Text('Нет слотов для выбранного врача.');
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Слоты расписания',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...slots.map((slot) {
                        final date =
                            '${slot.startTime.day.toString().padLeft(2, '0')}.${slot.startTime.month.toString().padLeft(2, '0')}';
                        final timeRange =
                            '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}'
                            ' - ${slot.endTime.hour.toString().padLeft(2, '0')}:${slot.endTime.minute.toString().padLeft(2, '0')}';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('$date · $timeRange'),
                          subtitle: Text('Статус: ${slot.status}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteSlot(slot.id),
                          ),
                        );
                      }),
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

  Widget _buildAdminSupportTab() {
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
                    'Фильтр обращений',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _filter,
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Открытые')),
                      DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
                      DropdownMenuItem(value: 'resolved', child: Text('Закрытые')),
                      DropdownMenuItem(value: 'all', child: Text('Все')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _filter = value;
                        _messagesFuture = _loadMessages();
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Статус'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<SupportMessage>>(
            future: _messagesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard('Загружаем обращения пациентов');
              } else if (snapshot.hasError) {
                return _buildErrorCard('Ошибка обращений: ${snapshot.error}');
              }

              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Нет обращений по выбранному фильтру.'),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Обращения пациентов',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ...messages.map((message) {
                    final controller = _controllerForThread(message.id);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  message.patient?.fullName ?? 'Пациент',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Chip(
                                  label: Text(message.status),
                                  backgroundColor: _statusColor(message.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...message.history.map((entry) {
                              final isPatient = entry.sender?.role == 'patient';
                              return Align(
                                alignment:
                                    isPatient ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        isPatient ? Colors.blue.shade50 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.sender?.fullName ?? 'Сотрудник',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(entry.content),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${entry.createdAt.day.toString().padLeft(2, '0')}.'
                                        '${entry.createdAt.month.toString().padLeft(2, '0')} '
                                        '${entry.createdAt.hour.toString().padLeft(2, '0')}:'
                                        '${entry.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            TextField(
                              controller: controller,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Ответить...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => _sendSupportReply(message),
                                  child: const Text('Отправить'),
                                ),
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: () => _updateStatus(message, 'in_progress'),
                                  child: const Text('В работу'),
                                ),
                                TextButton(
                                  onPressed: () => _updateStatus(message, 'resolved'),
                                  child: const Text('Закрыть'),
                                ),
                              ],
                            ),
                            if (message.patient != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => MedicalRecordsScreen(
                                          patientId: message.patient!.id,
                                          title: 'Карта: ${message.patient!.fullName}',
                                          allowCreate: true,
                                          allowEdit: true,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.folder_shared_outlined),
                                  label: const Text('Медкарта'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.green.shade100;
      case 'in_progress':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  void dispose() {
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
    return {
      'doctor': doctors,
      'admin': admins,
      'patient': patients,
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
        final clinic = clinics.first;
        _clinicNameController.text = clinic.name;
        _clinicAddressController.text = clinic.address ?? '';
        _clinicEmailController.text = clinic.supportEmail ?? '';
        _clinicPhoneController.text = clinic.supportPhone ?? '';
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
    if (_clinics.isEmpty) return;
    setState(() => _clinicSaving = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      final clinic = _clinics.first;
      await api.updateClinic(clinic.id, {
        'name': _clinicNameController.text.trim(),
        'address': _clinicAddressController.text.trim(),
        'supportEmail': _clinicEmailController.text.trim(),
        'supportPhone': _clinicPhoneController.text.trim(),
      });
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
    if (_clinics.isEmpty) return;
    setState(() => _qrRefreshing = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      final result = await api.generateClinicQr(_clinics.first.id);
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
          title: const Text('Панель директора'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
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
              Tab(icon: Icon(Icons.dashboard_customize_outlined), text: 'Обзор'),
              Tab(icon: Icon(Icons.group_outlined), text: 'Сотрудники'),
              Tab(icon: Icon(Icons.apartment_outlined), text: 'Клиника'),
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
                      // ignore: deprecated_member_use
                      value: _role,
                      items: const [
                        DropdownMenuItem(value: 'doctor', child: Text('Врач')),
                        DropdownMenuItem(value: 'admin', child: Text('Администратор')),
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

              final data = snapshot.data ?? {'doctor': [], 'admin': [], 'patient': []};
              return Column(
                children: [
                  _buildUserSection('Врачи', data['doctor'] ?? []),
                  const SizedBox(height: 16),
                  _buildUserSection('Администраторы', data['admin'] ?? []),
                  const SizedBox(height: 16),
                  _buildUserSection('Пациенты', data['patient'] ?? []),
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
                          style: const TextStyle(color: Colors.grey),
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
                        : const Icon(Icons.qr_code),
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

Widget _buildUserSection(String title, List<AppUser> users) {
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
                  subtitle: Text(user.email),
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
              Text(label, style: const TextStyle(color: Colors.grey)),
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
