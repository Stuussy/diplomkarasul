import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'providers/session_provider.dart';
import 'screens/ai_consultation_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/role_dashboards.dart';
import 'screens/support_screen.dart';
import 'screens/notifications_screen.dart';
import 'theme/clinic_theme.dart';

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final role = session.user?.role;

    switch (role) {
      case 'patient':
        return const _PatientNavigationShell();
      case 'doctor':
        return const DoctorDashboard();
      case 'admin':
        return const AdminDashboard();
      case 'support_manager':
        return const SupportManagerDashboard();
      case 'superadmin':
        return const SuperAdminDashboard();
      default:
        return const Scaffold(
          body: Center(child: Text('Неизвестная роль пользователя.')),
        );
    }
  }
}

class _PatientNavigationShell extends StatefulWidget {
  const _PatientNavigationShell();

  @override
  State<_PatientNavigationShell> createState() =>
      _PatientNavigationShellState();
}

class _PatientNavigationShellState extends State<_PatientNavigationShell> {
  int _selectedIndex = 0;

  late final List<Widget> _options;
  late final List<String> _titles;

  @override
  void initState() {
    super.initState();
    _options = const [
      HomeScreen(),
      MapScreen(),
      AppointmentsScreen(),
      ProfileScreen(),
    ];
    _titles = const ['Главная', 'Карта', 'Записи', 'Профиль'];
  }

  void _onItemTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(color: ClinicTheme.mist),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              AppBar(
                backgroundColor: ClinicTheme.snow,
                foregroundColor: ClinicTheme.midnight,
                elevation: 0,
                scrolledUnderElevation: 0,
                titleSpacing: 24,
                toolbarHeight: 64,
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _titles[_selectedIndex],
                    key: ValueKey(_titles[_selectedIndex]),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                actions: [
                  _NavAction(
                    icon: LucideIcons.bot,
                    tooltip: 'ИИ-ассистент',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiConsultationScreen()),
                    ),
                  ),
                  _NavAction(
                    icon: LucideIcons.messageCircle,
                    tooltip: 'Чат-поддержка',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SupportScreen()),
                    ),
                  ),
                  _NavAction(
                    icon: LucideIcons.bell,
                    tooltip: 'Уведомления',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _options,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Builder(
        builder: (context) {
          final safeBottom = MediaQuery.paddingOf(context).bottom;
          final bottomPadding = safeBottom > 0 ? safeBottom : 12.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: ClinicTheme.snow,
                boxShadow: ClinicTheme.shadowMd,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  height: 64,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  indicatorColor: ClinicTheme.azure.withValues(alpha: 0.12),
                  animationDuration: const Duration(milliseconds: 400),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(LucideIcons.home),
                      selectedIcon: Icon(LucideIcons.home, color: ClinicTheme.azure),
                      label: 'Главная',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.mapPin),
                      selectedIcon: Icon(LucideIcons.mapPin, color: ClinicTheme.azure),
                      label: 'Карта',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.calendarDays),
                      selectedIcon: Icon(LucideIcons.calendarDays, color: ClinicTheme.azure),
                      label: 'Записи',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.userCircle),
                      selectedIcon: Icon(LucideIcons.userCircle, color: ClinicTheme.azure),
                      label: 'Профиль',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavAction extends StatelessWidget {
  const _NavAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22, color: ClinicTheme.slate),
    );
  }
}
