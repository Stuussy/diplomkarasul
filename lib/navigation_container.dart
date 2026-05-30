import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'l10n/app_strings.dart';
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
import 'widgets/language_toggle.dart';

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
  Timer? _unreadTimer;

  late final List<Widget> _options;

  @override
  void initState() {
    super.initState();
    _options = const [
      HomeScreen(),
      MapScreen(),
      AppointmentsScreen(),
      ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().refreshUnreadNotifications();
    });
    _unreadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) context.read<SessionProvider>().refreshUnreadNotifications();
    });
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    HapticFeedback.selectionClick();
    // Always refresh appointments when the tab is selected.
    if (index == 2) {
      context.read<SessionProvider>().notifyBooked();
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final titles = [s.navHome, s.navMap, s.navAppointments, s.navProfile];
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
                    titles[_selectedIndex],
                    key: ValueKey(titles[_selectedIndex]),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                actions: [
                  // ── Language toggle ────────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: LanguageToggle(),
                  ),
                  _NavAction(
                    icon: LucideIcons.bot,
                    tooltip: s.navAi,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiConsultationScreen()),
                    ),
                  ),
                  _NavAction(
                    icon: LucideIcons.messageCircle,
                    tooltip: s.navSupport,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SupportScreen()),
                    ),
                  ),
                  _NavAction(
                    icon: LucideIcons.bell,
                    tooltip: s.navNotifications,
                    badge: context.watch<SessionProvider>().unreadNotifications,
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                      if (mounted) {
                        context
                            .read<SessionProvider>()
                            .refreshUnreadNotifications();
                      }
                    },
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
          final bottomPadding = safeBottom > 0 ? safeBottom * 0.5 + 6 : 12.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding),
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
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(LucideIcons.home),
                      selectedIcon: const Icon(LucideIcons.home, color: ClinicTheme.azure),
                      label: context.s.navHome,
                    ),
                    NavigationDestination(
                      icon: const Icon(LucideIcons.mapPin),
                      selectedIcon: const Icon(LucideIcons.mapPin, color: ClinicTheme.azure),
                      label: context.s.navMap,
                    ),
                    NavigationDestination(
                      icon: const Icon(LucideIcons.calendarDays),
                      selectedIcon: const Icon(LucideIcons.calendarDays, color: ClinicTheme.azure),
                      label: context.s.navAppointments,
                    ),
                    NavigationDestination(
                      icon: const Icon(LucideIcons.userCircle),
                      selectedIcon: const Icon(LucideIcons.userCircle, color: ClinicTheme.azure),
                      label: context.s.navProfile,
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
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22, color: ClinicTheme.slate),
    );
    if (badge <= 0) return button;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        button,
        Positioned(
          top: 8,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
