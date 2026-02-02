import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/session_provider.dart';
import 'screens/appointments_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/role_dashboards.dart';
import 'widgets/patient_ui.dart';

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
      case 'director':
        return const DirectorDashboard();
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
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: PatientPalette.background,
        ),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.black87,
                elevation: 0,
                titleSpacing: 24,
                toolbarHeight: 72,
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _titles[_selectedIndex],
                    key: ValueKey(_titles[_selectedIndex]),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Чат-поддержка',
                    onPressed: () {},
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
                  IconButton(
                    tooltip: 'Уведомления',
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              Expanded(
                child: IndexedStack(index: _selectedIndex, children: _options),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                height: 64,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                backgroundColor: Colors.white.withValues(alpha: 0.95),
                indicatorColor: PatientPalette.primary.withValues(alpha: 0.12),
                animationDuration: const Duration(milliseconds: 400),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Главная',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    selectedIcon: Icon(Icons.map_rounded),
                    label: 'Карта',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.event_outlined),
                    selectedIcon: Icon(Icons.event_available_rounded),
                    label: 'Записи',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Профиль',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
