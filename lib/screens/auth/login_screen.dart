import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../widgets/clinic_card.dart';
import '../../widgets/patient_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLogin = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final session = context.read<SessionProvider>();
    String? error;

    if (_isLogin) {
      error = await session.login(_emailController.text.trim(), _passwordController.text.trim());
    } else {
      error = await session.register(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    }

    setState(() => _isSubmitting = false);

    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: PatientPalette.background),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: PatientPalette.primary.withValues(alpha: 0.15),
                          child: Icon(
                            Icons.medical_services_outlined,
                            color: PatientPalette.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isLogin ? 'Добро пожаловать' : 'Создайте аккаунт',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isLogin
                              ? 'Войдите в личный кабинет пациента'
                              : 'Это займет меньше минуты',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClinicCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_isLogin) ...[
                            TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(labelText: 'Имя'),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Введите имя' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(labelText: 'Фамилия'),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Введите фамилию' : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(labelText: 'Email'),
                            validator: (value) =>
                                value == null || !value.contains('@') ? 'Введите email' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(labelText: 'Пароль'),
                            obscureText: true,
                            validator: (value) =>
                                value == null || value.length < 6 ? 'Мин. 6 символов' : null,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(_isLogin ? 'Войти' : 'Создать аккаунт'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _isLogin = !_isLogin),
                      child:
                          Text(_isLogin ? 'Нет аккаунта? Регистрация' : 'У меня уже есть аккаунт'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
