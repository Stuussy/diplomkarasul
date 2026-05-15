import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../theme/clinic_theme.dart';
import '../../widgets/glass_container.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _bgAnimController;
  late Animation<Alignment> _bgAlign;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _bgAlign = AlignmentTween(
      begin: const Alignment(-1.0, -1.0),
      end: const Alignment(1.0, 0.5),
    ).animate(CurvedAnimation(
      parent: _bgAnimController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final session = context.read<SessionProvider>();
    final messenger = ScaffoldMessenger.of(context);

    String? error;
    try {
      final email = _emailController.text.trim().toLowerCase();
      if (_isLogin) {
        error = await session.login(email, _passwordController.text);
      } else {
        error = await session.register(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: email,
          password: _passwordController.text,
        );
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (error != null && mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: ClinicTheme.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgAlign,
            builder: (context, _) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: _bgAlign.value,
                  end: Alignment.bottomRight,
                  colors: const [
                    Color(0xFF1E3A5F),
                    Color(0xFF0D1117),
                    Color(0xFF0D1117),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Radial glow
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ClinicTheme.azure.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Violet glow bottom
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ClinicTheme.violet.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.stethoscope,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Добро пожаловать',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? 'Войдите в свой аккаунт'
                          : 'Создайте новый аккаунт',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),

                    const SizedBox(height: 32),

                    // Glass card with form
                    GlassContainer(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: Column(
                            children: [
                              AnimatedCrossFade(
                                duration: const Duration(milliseconds: 300),
                                crossFadeState: _isLogin
                                    ? CrossFadeState.showFirst
                                    : CrossFadeState.showSecond,
                                firstChild: const SizedBox.shrink(),
                                secondChild: Column(
                                  children: [
                                    _buildField(
                                      controller: _firstNameController,
                                      hint: 'Имя',
                                      icon: LucideIcons.user,
                                      validator: _isLogin
                                          ? null
                                          : (v) => v == null || v.isEmpty
                                              ? 'Введите имя'
                                              : null,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildField(
                                      controller: _lastNameController,
                                      hint: 'Фамилия',
                                      icon: LucideIcons.user,
                                      validator: _isLogin
                                          ? null
                                          : (v) => v == null || v.isEmpty
                                              ? 'Введите фамилию'
                                              : null,
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                ),
                              ),

                              _buildField(
                                controller: _emailController,
                                hint: 'Email',
                                icon: LucideIcons.mail,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Введите email'
                                    : null,
                              ),
                              const SizedBox(height: 14),

                              // Password
                              _buildField(
                                controller: _passwordController,
                                hint: 'Пароль',
                                icon: LucideIcons.lock,
                                obscure: _obscurePassword,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? LucideIcons.eye
                                        : LucideIcons.eyeOff,
                                    color: Colors.white60,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () =>
                                        _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                validator: (v) => v == null || v.length < 6
                                    ? 'Минимум 6 символов'
                                    : null,
                              ),

                              const SizedBox(height: 24),

                              // CTA
                              _PrimaryCTA(
                                label: _isLogin ? 'Войти' : 'Регистрация',
                                isLoading: _isLoading,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Toggle login/register
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? 'Нет аккаунта? Регистрация'
                            : 'Уже есть аккаунт? Войти',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),

                    if (_isLogin)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        child: const Text(
                          'Забыли пароль?',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white60, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: ClinicTheme.azure.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: ClinicTheme.coral.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        errorStyle: const TextStyle(color: ClinicTheme.coral),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

class _PrimaryCTA extends StatelessWidget {
  const _PrimaryCTA({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ClinicTheme.heroGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: ClinicTheme.azure.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
        ),
      ),
    );
  }
}
