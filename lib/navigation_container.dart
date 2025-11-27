import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/session_provider.dart';
import 'screens/appointments_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/role_dashboards.dart';

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
        return const Scaffold(body: Center(child: Text('Неизвестная роль пользователя.')));
    }
  }
}

class _PatientNavigationShell extends StatefulWidget {
  const _PatientNavigationShell();

  @override
  State<_PatientNavigationShell> createState() => _PatientNavigationShellState();
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
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body: IndexedStack(index: _selectedIndex, children: _options),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Карта',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Записи',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
