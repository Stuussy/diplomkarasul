import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() {
    return context.read<SessionProvider>().apiService.fetchNotifications();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _markAllRead() async {
    final api = context.read<SessionProvider>().apiService;
    await api.markAllNotificationsRead();
    await _refresh();
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    final api = context.read<SessionProvider>().apiService;
    await api.markNotificationRead(notification.id);
    await _refresh();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$day.$month • $time';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'appointment':
        return LucideIcons.calendarCheck;
      case 'support':
        return LucideIcons.headphones;
      default:
        return LucideIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClinicTheme.mist,
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          TextButton.icon(
            onPressed: _markAllRead,
            icon: const Icon(LucideIcons.checkCheck, size: 16),
            label: const Text('Все'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('Ошибка: ${snapshot.error}')),
                ],
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(LucideIcons.bellOff, size: 48, color: ClinicTheme.slate),
                        const SizedBox(height: 12),
                        Text(
                          'Пока нет уведомлений',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = items[index];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: notification.isRead ? ClinicTheme.snow : ClinicTheme.azureSoft,
                    borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
                    border: notification.isRead
                        ? null
                        : Border(
                            left: BorderSide(color: ClinicTheme.azure, width: 3),
                          ),
                    boxShadow: notification.isRead ? null : ClinicTheme.shadowSm,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ClinicTheme.azure.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForType(notification.type),
                        color: ClinicTheme.azure,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      notification.title,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(notification.createdAt),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () => _markRead(notification),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
