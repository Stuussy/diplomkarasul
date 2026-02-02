import 'package:flutter/material.dart';

import '../models/medical_record.dart';
import '../theme/clinic_theme.dart';

const List<String> _statusOrder = [
  'none',
  'issue',
  'treated',
  'missing',
  'healthy',
];

Color _statusColor(String status) {
  switch (status) {
    case 'issue':
      return const Color(0xFFFFA14C);
    case 'treated':
      return const Color(0xFF3ED1B8);
    case 'missing':
      return const Color(0xFFF38B7C);
    case 'healthy':
      return const Color(0xFF8FB4FF);
    default:
      return const Color(0xFFE3E9F4);
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'issue':
      return 'Проблема';
    case 'treated':
      return 'Лечение';
    case 'missing':
      return 'Отсутствует';
    case 'healthy':
      return 'Здоров';
    default:
      return 'Без отметки';
  }
}

class ToothChart extends StatelessWidget {
  const ToothChart({super.key, required this.toothMap, this.onChanged});

  final List<ToothMark> toothMap;
  final ValueChanged<List<ToothMark>>? onChanged;

  bool get _editable => onChanged != null;

  String _statusFor(String arch, int index) {
    final match = toothMap.firstWhere(
      (item) => item.arch == arch && item.index == index,
      orElse: () => ToothMark(arch: arch, index: index, status: 'none'),
    );
    return match.status;
  }

  void _updateStatus(String arch, int index) {
    final current = _statusFor(arch, index);
    final nextIndex = (_statusOrder.indexOf(current) + 1) % _statusOrder.length;
    final nextStatus = _statusOrder[nextIndex];

    final updated = toothMap
        .where((item) => !(item.arch == arch && item.index == index))
        .toList();
    if (nextStatus != 'none') {
      updated.add(ToothMark(arch: arch, index: index, status: nextStatus));
    }
    onChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildArch(context, 'upper', 'Верхняя челюсть'),
        const SizedBox(height: 16),
        _buildArch(context, 'lower', 'Нижняя челюсть'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: _statusOrder
              .where((status) => status != 'none')
              .map(
                (status) => _LegendItem(
                  color: _statusColor(status),
                  label: _statusLabel(status),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildArch(BuildContext context, String arch, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ClinicTheme.radiusL),
            border: Border.all(color: ClinicTheme.line, width: 0.6),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(14, (index) {
                final number = index + 1;
                final status = _statusFor(arch, number);
                final color = _statusColor(status);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: _editable ? () => _updateStatus(arch, number) : null,
                    child: Column(
                      children: [
                        Text(
                          number.toString(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 28,
                          height: 26,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: status == 'none'
                                  ? ClinicTheme.line
                                  : color.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
