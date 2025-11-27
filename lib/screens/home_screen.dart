import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/appointment.dart';
import '../providers/session_provider.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/support_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Appointment? _nextAppointment;
  String? _aiTip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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

  Future<void> _openQrScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
  }

  Future<void> _openSupport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SupportScreen()),
    );
  }

  Future<void> _openTaxi() async {
    const uri = 'yandexnavi://';
    final success = await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Установите приложение Яндекс.Такси')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;
    final greeting = user != null ? 'Добро пожаловать,\n${user.fullName}!' : 'Добро пожаловать!';

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            greeting,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildNextAppointmentCard(),
          const SizedBox(height: 20),
          _buildActionsRow(),
          const SizedBox(height: 20),
          _buildAiTipCard(),
          if (_loading) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildNextAppointmentCard() {
    if (_nextAppointment == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _loading ? 'Загружаем следующую запись...' : 'У вас пока нет предстоящих визитов.',
          ),
        ),
      );
    }

    final appointment = _nextAppointment!;
    final start = appointment.startTime;
    final date =
        '${start.day.toString().padLeft(2, '0')}.${start.month.toString().padLeft(2, '0')}.${start.year}';
    final time = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    return Card(
      color: Colors.blue[700],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Следующая запись',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              '$date в $time',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${appointment.service} — ${appointment.doctor?.fullName ?? ''}',
              style: const TextStyle(color: Colors.white),
            ),
            if (appointment.clinic?.name != null) ...[
              const SizedBox(height: 4),
              Text(
                appointment.clinic!.name,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openQrScanner,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Сканировать QR'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openSupport,
            icon: const Icon(Icons.support_agent),
            label: const Text('Поддержка'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openTaxi,
            icon: const Icon(Icons.local_taxi),
            label: const Text('Яндекс Такси'),
          ),
        ),
      ],
    );
  }

  Widget _buildAiTipCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 36),
        title: const Text('Совет от Dental AI'),
        subtitle: Text(_aiTip ?? 'Получаем персональный совет...'),
      ),
    );
  }
}
