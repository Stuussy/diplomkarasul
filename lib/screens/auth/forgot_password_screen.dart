import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../theme/clinic_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _codeSent = false;
  bool _obscurePassword = true;
  String _sentToEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_formKey1.currentState!.validate()) return;
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final api = context.read<SessionProvider>().apiService;
    try {
      final email = _emailController.text.trim().toLowerCase();
      await api.requestPasswordReset(email);
      _sentToEmail = email;
      if (mounted) setState(() => _codeSent = true);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: ClinicTheme.coral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey2.currentState!.validate()) return;
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final api = context.read<SessionProvider>().apiService;
    try {
      await api.resetPassword(
        email: _sentToEmail,
        code: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Пароль успешно изменён! Войдите заново.'),
        backgroundColor: ClinicTheme.mint,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: ClinicTheme.coral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, color: ClinicTheme.midnight),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
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
                                LucideIcons.keyRound,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Восстановление пароля',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: ClinicTheme.midnight,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                key: ValueKey(_codeSent),
                                _codeSent
                                    ? 'Код отправлен на $_sentToEmail'
                                    : 'Введите email — мы вышлем 6-значный код',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: ClinicTheme.slate,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: _codeSent
                                  ? _buildStep2(key: const ValueKey('step2'))
                                  : _buildStep1(key: const ValueKey('step1')),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1({Key? key}) {
    return Container(
      key: key,
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
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildField(
              controller: _emailController,
              label: 'Email',
              icon: LucideIcons.mail,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.isEmpty ? 'Введите email' : null,
            ),
            const SizedBox(height: 22),
            _PrimaryButton(
              label: 'Отправить код',
              isLoading: _isLoading,
              onPressed: _requestCode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2({Key? key}) {
    return Container(
      key: key,
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
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildField(
              controller: _codeController,
              label: '6-значный код',
              icon: LucideIcons.hash,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (v) =>
                  v == null || v.length != 6 ? 'Введите 6-значный код' : null,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _newPasswordController,
              label: 'Новый пароль',
              icon: LucideIcons.lock,
              obscure: _obscurePassword,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                  color: ClinicTheme.slate,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'Минимум 6 символов' : null,
            ),
            const SizedBox(height: 22),
            _PrimaryButton(
              label: 'Сменить пароль',
              isLoading: _isLoading,
              onPressed: _resetPassword,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _codeSent = false;
                          _codeController.clear();
                          _newPasswordController.clear();
                        }),
                child: const Text(
                  'Отправить код повторно',
                  style: TextStyle(
                    color: ClinicTheme.azure,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
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
