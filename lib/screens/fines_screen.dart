import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/fine.dart';
import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';
import '../widgets/dent_badge.dart';
import '../widgets/dent_card.dart';
import '../widgets/dent_shimmer.dart';
import '../widgets/kaspi_payment_sheet.dart';
import '../widgets/patient_ui.dart';

class FinesScreen extends StatefulWidget {
  const FinesScreen({super.key});

  @override
  State<FinesScreen> createState() => _FinesScreenState();
}

class _FinesScreenState extends State<FinesScreen> {
  late Future<List<Fine>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Fine>> _load() async {
    final api = context.read<SessionProvider>().apiService;
    final list = await api.fetchFines();
    return list.cast<Fine>();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() { _future = future; });
    await future;
  }

  Future<void> _payAllFines(List<Fine> unpaid, double total) async {
    final paid = await KaspiPaymentSheet.show(context, total);
    if (paid != true || !mounted) return;

    final api = context.read<SessionProvider>().apiService;
    final messenger = ScaffoldMessenger.of(context);
    final s = context.sRead;
    try {
      for (final fine in unpaid) {
        await api.payFine(fine.id);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(s.kaspiPaidSuccess),
          backgroundColor: ClinicTheme.mint,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _payFineViaKaspi(Fine fine) async {
    final paid = await KaspiPaymentSheet.show(context, fine.amount);
    if (paid != true || !mounted) return;

    final api = context.read<SessionProvider>().apiService;
    final messenger = ScaffoldMessenger.of(context);
    final s = context.sRead;
    try {
      await api.payFine(fine.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(s.kaspiPaidSuccess),
          backgroundColor: ClinicTheme.mint,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      backgroundColor: ClinicTheme.mist,
      appBar: AppBar(
        backgroundColor: ClinicTheme.snow,
        foregroundColor: ClinicTheme.midnight,
        elevation: 0,
        title: Text(s.profileFines),
      ),
      body: FutureBuilder<List<Fine>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                DentShimmerCard(height: 120),
                SizedBox(height: 14),
                DentShimmerCard(height: 120),
              ],
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final fines = snapshot.data ?? [];
          if (fines.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  const SizedBox(height: 80),
                  PatientEmptyState(
                    title: s.finesEmpty,
                    message: '',
                    icon: LucideIcons.shieldCheck,
                  ),
                ],
              ),
            );
          }

          fines.sort((a, b) {
            if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
            return b.createdAt.compareTo(a.createdAt);
          });

          final unpaidTotal = fines
              .where((f) => !f.isPaid)
              .fold<double>(0, (sum, f) => sum + f.amount);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                if (unpaidTotal > 0)
                  _buildTotalBanner(
                    s,
                    unpaidTotal,
                    fines.where((f) => !f.isPaid).toList(),
                  ),
                ...fines.map((fine) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildFineCard(s, fine),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalBanner(AppStrings s, double total, List<Fine> unpaid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ClinicTheme.coralSoft,
        borderRadius: BorderRadius.circular(ClinicTheme.radiusL),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.wallet, color: ClinicTheme.coral),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  s.finesUnpaidTotal,
                  style: const TextStyle(
                    color: ClinicTheme.coral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${total.toStringAsFixed(0)} ₸',
                style: const TextStyle(
                  color: ClinicTheme.coral,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          if (unpaid.length > 1) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _payAllFines(unpaid, total),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF14635),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.creditCard, size: 18),
                label: Text('${s.finesPayAll} · ${total.toStringAsFixed(0)} ₸'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFineCard(AppStrings s, Fine fine) {
    final isPaid = fine.isPaid;
    final apt = fine.appointment;

    return DentCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPaid ? ClinicTheme.mintSoft : ClinicTheme.coralSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaid ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                  color: isPaid ? ClinicTheme.mint : ClinicTheme.coral,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fine.amount.toStringAsFixed(0)} ₸',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (fine.reason.isNotEmpty)
                      Text(
                        fine.reason,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              DentBadge(
                label: isPaid ? s.profileFinePaid : s.profileFineUnpaid,
                variant:
                    isPaid ? DentBadgeVariant.success : DentBadgeVariant.error,
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // For which appointment
          if (apt != null) ...[
            _infoRow(
              LucideIcons.stethoscope,
              s.fineForAppointment,
              '${apt.service}${apt.doctor != null ? ' · ${apt.doctor!.fullName}' : ''}',
            ),
            const SizedBox(height: 8),
            _infoRow(
              LucideIcons.calendarDays,
              s.bookSlot,
              _date(apt.startTime),
            ),
            const SizedBox(height: 8),
          ],

          _infoRow(LucideIcons.clock, s.fineIssuedOn, _date(fine.createdAt)),

          if (isPaid && fine.paidAt != null) ...[
            const SizedBox(height: 8),
            _infoRow(
              LucideIcons.badgeCheck,
              s.finePaidOn,
              _date(fine.paidAt!),
              valueColor: ClinicTheme.mint,
            ),
          ],

          if (!isPaid) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _payFineViaKaspi(fine),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF14635),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(LucideIcons.creditCard, size: 18),
              label: Text(s.profileFinePayKaspi),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: ClinicTheme.slate),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(color: ClinicTheme.slate, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? ClinicTheme.midnight,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
