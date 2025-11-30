import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'navigation_container.dart';
import 'providers/session_provider.dart';
import 'screens/auth/login_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await _requestInitialPermissions();
  runApp(const DentalApp());
}

Future<void> _requestInitialPermissions() async {
  final permissions = <Permission>[
    Permission.camera,
    Permission.notification,
  ];
  for (final permission in permissions) {
    final status = await permission.status;
    if (!status.isGranted) {
      await permission.request();
    }
  }
}

class DentalApp extends StatelessWidget {
  const DentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(apiService),
        ),
      ],
      child: MaterialApp(
        title: 'Dental AI',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFFF4F7FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: IconThemeData(color: Colors.black),
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0.5,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const _AuthGate(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        if (session.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!session.isAuthenticated) {
          return const LoginScreen();
        }
        return const MainNavigationScreen();
      },
    );
  }
}
