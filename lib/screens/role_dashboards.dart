import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/support_message.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  late Future<List<Appointment>> _appointmentsFuture;

  @override
  void initState() {
    super.initState();
    _appointmentsFuture = _loadAppointments();
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
      _appointmentsFuture = _loadAppointments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Рабочее место врача'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Appointment>>(
        future: _appointmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }
          final appointments = snapshot.data ?? [];
          final next = appointments
              .where((a) => a.startTime.isAfter(DateTime.now()))
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _DoctorStatsCard(total: appointments.length, upcoming: next.length),
                const SizedBox(height: 16),
                if (next.isNotEmpty) _NextAppointmentCard(appointment: next.first),
                const SizedBox(height: 16),
                const Text(
                  'Ближайшие приемы',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                if (appointments.isEmpty)
                  const Text('Нет записей на выбранный период.')
                else
                  ...appointments.map((appointment) => Card(
                        child: ListTile(
                          leading: Icon(
                            appointment.status == 'confirmed'
                                ? Icons.check_circle_outline
                                : Icons.schedule,
                            color:
                                appointment.status == 'confirmed' ? Colors.green : Colors.blue,
                          ),
                          title: Text('${appointment.patient?.fullName ?? 'Пациент'}'
                              ' • ${appointment.service}'),
                          subtitle: Text(
                              '${_formatDate(appointment.startTime)} · ${appointment.status}'),
                          trailing: const Icon(Icons.medical_services_outlined),
                        ),
                      )),
              ],
            ),
          );
        },
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

class _DoctorStatsCard extends StatelessWidget {
  const _DoctorStatsCard({required this.total, required this.upcoming});

  final int total;
  final int upcoming;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatItem(label: 'Всего визитов', value: '$total'),
            _StatItem(label: 'Предстоит', value: '$upcoming'),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ближайший пациент',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              appointment.patient?.fullName ?? 'Пациент',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(_format(appointment.startTime)),
            const SizedBox(height: 8),
            Text('Услуга: ${appointment.service}'),
          ],
        ),
      ),
    );
  }

  String _format(DateTime date) {
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day}.${date.month}.${date.year} · $time';
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
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
    setState(() {
      _messagesFuture = _loadMessages();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель администратора'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filter,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _filter = value;
                  _messagesFuture = _loadMessages();
                });
              },
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Открытые')),
                DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
                DropdownMenuItem(value: 'resolved', child: Text('Закрытые')),
                DropdownMenuItem(value: 'all', child: Text('Все')),
              ],
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<SupportMessage>>(
        future: _messagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final messages = snapshot.data ?? [];
          if (messages.isEmpty) {
            return const Center(child: Text('Нет обращений по выбранному фильтру.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
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
                        Text(message.content),
                        const SizedBox(height: 12),
                        Row(
                          children: [
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
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
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
}

class DirectorDashboard extends StatefulWidget {
  const DirectorDashboard({super.key});

  @override
  State<DirectorDashboard> createState() => _DirectorDashboardState();
}

class _DirectorDashboardState extends State<DirectorDashboard> {
  late Future<Map<String, List<AppUser>>> _usersFuture;
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'doctor';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Панель директора')),
      body: FutureBuilder<Map<String, List<AppUser>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final data = snapshot.data ?? {'doctor': [], 'admin': [], 'patient': []};
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                _buildUserSection('Врачи', data['doctor'] ?? []),
                const SizedBox(height: 16),
                _buildUserSection('Администраторы', data['admin'] ?? []),
                const SizedBox(height: 16),
                _buildUserSection('Пациенты', data['patient'] ?? []),
              ],
            ),
          );
        },
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
