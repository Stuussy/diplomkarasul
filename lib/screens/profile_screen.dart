import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';
import '../widgets/dent_card.dart';
import '../widgets/dent_badge.dart';
import '../widgets/dent_shimmer.dart';
import '../widgets/patient_ui.dart';
import 'medical_records_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<dynamic>> _finesFuture;

  @override
  void initState() {
    super.initState();
    _finesFuture = _loadFines();
  }

  Future<List<dynamic>> _loadFines() async {
    try {
      final api = context.read<SessionProvider>().apiService;
      return await api.fetchFines();
    } catch (_) {
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() => _finesFuture = _loadFines());
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: ClinicTheme.coral),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<SessionProvider>().logout();
  }

  Future<void> _editProfile() async {
    final user = context.read<SessionProvider>().user;
    if (user == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(user: user),
    );
  }

  Future<void> _changePassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сменить пароль'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Текущий пароль'),
                validator: (v) => v == null || v.isEmpty ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Новый пароль'),
                validator: (v) =>
                    v == null || v.length < 6 ? 'Минимум 6 символов' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final api = context.read<SessionProvider>().apiService;
    try {
      await api.changePassword(
        currentPassword: oldController.text,
        newPassword: newController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Пароль изменён ✓'),
            backgroundColor: ClinicTheme.mint,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: const BoxDecoration(color: ClinicTheme.mist),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 110 + MediaQuery.of(context).padding.bottom),
          children: [
            // Hero card
            DentCard(
              gradient: ClinicTheme.heroGradient,
              borderRadius: ClinicTheme.radiusL,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: Center(
                          child: Text(
                            _initials(user),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _editProfile,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(LucideIcons.pencil, color: Colors.white, size: 17),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.shieldCheck, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _roleLabel(user.role),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Info card
            DentCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _InfoRow(icon: LucideIcons.mail, label: 'Email', value: user.email),
                  const Divider(height: 0, indent: 60),
                  _InfoRow(icon: LucideIcons.phone, label: 'Телефон', value: user.phone ?? 'Не указан'),
                  const Divider(height: 0, indent: 60),
                  _InfoRow(icon: LucideIcons.badge, label: 'Роль', value: _roleLabel(user.role)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Actions card
            DentCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (user.role == 'patient')
                    _ActionRow(
                      icon: LucideIcons.folderHeart,
                      label: 'Медицинская карта',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MedicalRecordsScreen()),
                      ),
                    ),
                  if (user.role == 'patient') const Divider(height: 0, indent: 60),
                  _ActionRow(
                    icon: LucideIcons.lock,
                    label: 'Сменить пароль',
                    onTap: _changePassword,
                  ),
                  const Divider(height: 0, indent: 60),
                  _ActionRow(
                    icon: LucideIcons.logOut,
                    label: 'Выйти из аккаунта',
                    color: ClinicTheme.coral,
                    onTap: _logout,
                  ),
                ],
              ),
            ),

            // Fines
            const SizedBox(height: 24),
            FutureBuilder<List<dynamic>>(
              future: _finesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const DentShimmerCard(height: 80);
                }
                final fines = snapshot.data ?? [];
                if (fines.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Штрафы', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ...fines.map((fine) {
                      final isPaid = fine['status'] == 'paid';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DentCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? ClinicTheme.mintSoft
                                      : ClinicTheme.coralSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPaid ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                                  color: isPaid ? ClinicTheme.mint : ClinicTheme.coral,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${fine['amount']} ₸',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(
                                      fine['reason'] ?? 'Штраф',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              DentBadge(
                                label: isPaid ? 'Оплачен' : 'Не оплачен',
                                variant: isPaid ? DentBadgeVariant.success : DentBadgeVariant.error,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _initials(AppUser user) {
    final f = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final l = user.lastName.isNotEmpty ? user.lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'patient':
        return 'Пациент';
      case 'doctor':
        return 'Врач';
      case 'admin':
        return 'Администратор';
      default:
        return role;
    }
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.user});
  final AppUser user;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final session = context.read<SessionProvider>();
    final error = await session.updateProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: ClinicTheme.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Профиль обновлён ✓'),
        backgroundColor: ClinicTheme.mint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: ClinicTheme.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: ClinicTheme.heroGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.userCog, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Редактировать профиль',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ClinicTheme.midnight,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildField(_firstNameController, 'Имя', LucideIcons.user,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Введите имя' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField(_lastNameController, 'Фамилия', LucideIcons.user,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Введите фамилию' : null)),
                  ],
                ),
                const SizedBox(height: 14),
                _buildField(
                  _phoneController, 'Номер телефона', LucideIcons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))],
                  validator: (v) {
                    final raw = v?.trim() ?? '';
                    if (raw.isEmpty) return null;
                    final digits = raw.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 10) return 'Некорректный номер';
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: ClinicTheme.heroGradient,
                borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
                boxShadow: [
                  BoxShadow(
                    color: ClinicTheme.azure.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ClinicTheme.radiusS)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Сохранить',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: ClinicTheme.midnight, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: ClinicTheme.slate, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: ClinicTheme.azure, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: ClinicTheme.slate, size: 18),
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
        errorStyle: const TextStyle(color: ClinicTheme.coral),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ClinicTheme.azureSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: ClinicTheme.azure, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? ClinicTheme.midnight;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (color ?? ClinicTheme.azure).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color ?? ClinicTheme.azure, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(color: resolved, fontWeight: FontWeight.w500))),
            Icon(LucideIcons.chevronRight, color: ClinicTheme.slate, size: 18),
          ],
        ),
      ),
    );
  }
}
