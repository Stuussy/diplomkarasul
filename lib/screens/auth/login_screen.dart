import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../theme/clinic_theme.dart';
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
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  static final _passwordRegex = RegExp(r'^(?=.*[A-ZА-ЯЁ])(?=.*[!@#\$%^&*(),.?":{}|<>_\-+=/\\\[\]~`;]).{6,}$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
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
          phone: _phoneController.text.trim(),
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
      backgroundColor: ClinicTheme.mist,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ClinicTheme.azure.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ClinicTheme.mint.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      _BrandHeader(isLogin: _isLogin),
                      const SizedBox(height: 24),
                      _SegmentedToggle(
                        isLogin: _isLogin,
                        onChanged: (v) => setState(() => _isLogin = v),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ClinicTheme.radiusL),
                          border: Border.all(color: ClinicTheme.line),
                          boxShadow: [
                            BoxShadow(
                              color: ClinicTheme.azure.withValues(alpha: 0.06),
                              blurRadius: 32,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!_isLogin) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildField(
                                          controller: _firstNameController,
                                          label: 'Имя',
                                          icon: LucideIcons.user,
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                                  ? 'Введите имя'
                                                  : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildField(
                                          controller: _lastNameController,
                                          label: 'Фамилия',
                                          icon: LucideIcons.user,
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                                  ? 'Введите фамилию'
                                                  : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  _buildField(
                                    controller: _phoneController,
                                    label: 'Номер телефона',
                                    icon: LucideIcons.phone,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9+\-\s()]')),
                                    ],
                                    validator: (v) {
                                      final raw = v?.trim() ?? '';
                                      if (raw.isEmpty) {
                                        return 'Введите номер телефона';
                                      }
                                      final digits =
                                          raw.replaceAll(RegExp(r'\D'), '');
                                      if (digits.length < 10) {
                                        return 'Некорректный номер';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                _buildField(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: LucideIcons.mail,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    final raw = v?.trim() ?? '';
                                    if (raw.isEmpty) return 'Введите email';
                                    if (!raw.contains('@') ||
                                        !raw.contains('.')) {
                                      return 'Некорректный email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                _buildField(
                                  controller: _passwordController,
                                  label: 'Пароль',
                                  icon: LucideIcons.lock,
                                  obscure: _obscurePassword,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? LucideIcons.eye
                                          : LucideIcons.eyeOff,
                                      color: ClinicTheme.slate,
                                      size: 18,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (v) {
                                    final value = v ?? '';
                                    if (value.isEmpty) {
                                      return 'Введите пароль';
                                    }
                                    if (_isLogin) return null;
                                    if (value.length < 6) {
                                      return 'Минимум 6 символов';
                                    }
                                    if (!_passwordRegex.hasMatch(value)) {
                                      return 'Нужна заглавная буква и спец. символ';
                                    }
                                    return null;
                                  },
                                ),
                                if (!_isLogin) ...[
                                  const SizedBox(height: 14),
                                  _buildField(
                                    controller: _confirmPasswordController,
                                    label: 'Повторите пароль',
                                    icon: LucideIcons.shieldCheck,
                                    obscure: _obscureConfirm,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? LucideIcons.eye
                                            : LucideIcons.eyeOff,
                                        color: ClinicTheme.slate,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Подтвердите пароль';
                                      }
                                      if (v != _passwordController.text) {
                                        return 'Пароли не совпадают';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  const _PasswordHints(),
                                ],
                                const SizedBox(height: 22),
                                _PrimaryCTA(
                                  label: _isLogin ? 'Войти' : 'Создать аккаунт',
                                  icon: _isLogin
                                      ? LucideIcons.arrowRight
                                      : LucideIcons.userCheck,
                                  isLoading: _isLoading,
                                  onPressed: _submit,
                                ),
                                if (_isLogin) ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ForgotPasswordScreen(),
                                        ),
                                      ),
                                      child: const Text(
                                        'Забыли пароль?',
                                        style: TextStyle(
                                          color: ClinicTheme.azure,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            LucideIcons.shieldCheck,
                            size: 14,
                            color: ClinicTheme.slate,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Защищённое соединение',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: ClinicTheme.slate),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
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
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: ClinicTheme.midnight, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: ClinicTheme.slate, fontSize: 14),
        floatingLabelStyle: const TextStyle(
          color: ClinicTheme.azure,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: ClinicTheme.slate, size: 19),
        suffixIcon: suffix,
        filled: true,
        fillColor: ClinicTheme.mist.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
          borderSide: const BorderSide(color: ClinicTheme.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
          borderSide: const BorderSide(color: ClinicTheme.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
          borderSide: const BorderSide(color: ClinicTheme.azure, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
          borderSide: const BorderSide(color: ClinicTheme.coral),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
          borderSide: const BorderSide(color: ClinicTheme.coral, width: 1.5),
        ),
        errorStyle: const TextStyle(color: ClinicTheme.coral),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.isLogin});

  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: ClinicTheme.heroGradient,
            boxShadow: [
              BoxShadow(
                color: ClinicTheme.azure.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.stethoscope,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'RasulDent Clinic',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: ClinicTheme.midnight,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          isLogin
              ? 'Войдите, чтобы продолжить'
              : 'Создайте аккаунт за минуту',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ClinicTheme.slate,
              ),
        ),
      ],
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.isLogin, required this.onChanged});

  final bool isLogin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
        border: Border.all(color: ClinicTheme.line),
      ),
      child: Row(
        children: [
          _segment('Вход', isLogin, () => onChanged(true)),
          _segment('Регистрация', !isLogin, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: active ? ClinicTheme.heroGradient : null,
            borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: ClinicTheme.azure.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : ClinicTheme.slate,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordHints extends StatelessWidget {
  const _PasswordHints();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ClinicTheme.azureSoft,
        borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, color: ClinicTheme.azure, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Пароль: минимум 6 символов, одна заглавная буква и один спец. символ (!@#\$%…)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ClinicTheme.azure,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCTA extends StatelessWidget {
  const _PrimaryCTA({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ClinicTheme.heroGradient,
          borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
          boxShadow: [
            BoxShadow(
              color: ClinicTheme.azure.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
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
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
