import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/clinic_theme.dart';

/// Kaspi-styled payment sheet (demo).
///
/// Shows a branded payment screen, a processing spinner, then an animated
/// success check. Pops `true` when the simulated payment completes so the
/// caller can mark the fine as paid on the backend.
class KaspiPaymentSheet extends StatefulWidget {
  const KaspiPaymentSheet({super.key, required this.amount});

  final num amount;

  /// Shows the sheet as a modal bottom sheet. Returns `true` if paid.
  static Future<bool?> show(BuildContext context, num amount) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => KaspiPaymentSheet(amount: amount),
    );
  }

  @override
  State<KaspiPaymentSheet> createState() => _KaspiPaymentSheetState();
}

enum _PayStage { form, processing, success }

class _KaspiPaymentSheetState extends State<KaspiPaymentSheet>
    with TickerProviderStateMixin {
  static const _kaspiRed = Color(0xFFF14635);

  _PayStage _stage = _PayStage.form;
  late final AnimationController _checkController;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _stage = _PayStage.processing);
    HapticFeedback.lightImpact();

    // Simulate a network/payment round-trip.
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;

    setState(() => _stage = _PayStage.success);
    HapticFeedback.heavyImpact();
    _checkController.forward();

    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final amountLabel = '${widget.amount.toStringAsFixed(0)} ₸';
    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, 24 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: ClinicTheme.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 20),

          // Kaspi brand
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _kaspiRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Kaspi.kz',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 24),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStage(amountLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildStage(String amountLabel) {
    switch (_stage) {
      case _PayStage.form:
        return Column(
          key: const ValueKey('form'),
          children: [
            const Text(
              'Оплата штрафа',
              style: TextStyle(fontSize: 15, color: ClinicTheme.slate),
            ),
            const SizedBox(height: 8),
            Text(
              amountLabel,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: ClinicTheme.midnight,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Dental AI · Стоматология',
              style: TextStyle(fontSize: 13, color: ClinicTheme.slate),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _pay,
                style: FilledButton.styleFrom(
                  backgroundColor: _kaspiRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: Text('Оплатить $amountLabel'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена',
                  style: TextStyle(color: ClinicTheme.slate)),
            ),
          ],
        );

      case _PayStage.processing:
        return Column(
          key: const ValueKey('processing'),
          children: const [
            SizedBox(height: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: _kaspiRed,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Обработка платежа…',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ClinicTheme.midnight,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Подождите, идёт списание',
              style: TextStyle(fontSize: 13, color: ClinicTheme.slate),
            ),
            SizedBox(height: 16),
          ],
        );

      case _PayStage.success:
        return Column(
          key: const ValueKey('success'),
          children: [
            const SizedBox(height: 8),
            ScaleTransition(
              scale: CurvedAnimation(
                parent: _checkController,
                curve: Curves.elasticOut,
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: ClinicTheme.mint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.check,
                    color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Оплачено успешно!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ClinicTheme.midnight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$amountLabel · штраф погашен',
              style: const TextStyle(fontSize: 13, color: ClinicTheme.slate),
            ),
            const SizedBox(height: 16),
          ],
        );
    }
  }
}
