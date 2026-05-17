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

Color statusColor(String status) {
  switch (status) {
    case 'issue':
      return const Color(0xFFFF8A65);
    case 'treated':
      return const Color(0xFF42B89E);
    case 'missing':
      return const Color(0xFFB0BEC5);
    case 'healthy':
      return const Color(0xFFFFFFFF);
    default:
      return const Color(0xFFF1F4F8);
  }
}

Color statusOutline(String status) {
  switch (status) {
    case 'issue':
      return const Color(0xFFE36A45);
    case 'treated':
      return const Color(0xFF2C9B85);
    case 'missing':
      return const Color(0xFF8A99A3);
    case 'healthy':
      return const Color(0xFFC8D2DE);
    default:
      return const Color(0xFFCFD7E3);
  }
}

String statusLabel(String status) {
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

// Dental notation: 14 teeth per arch (left 7 + right 7).
// Anatomical types: 1-2 incisors, 3 canine, 4-5 premolars, 6-7 molars.
String _toothType(int positionFromCenter) {
  if (positionFromCenter <= 2) return 'incisor';
  if (positionFromCenter == 3) return 'canine';
  if (positionFromCenter <= 5) return 'premolar';
  return 'molar';
}

double _toothWidth(int positionFromCenter) {
  switch (_toothType(positionFromCenter)) {
    case 'incisor':
      return 22;
    case 'canine':
      return 24;
    case 'premolar':
      return 28;
    case 'molar':
      return 32;
  }
  return 26;
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

  void _cycleStatus(String arch, int index) {
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ArchHeader(label: 'Верхняя челюсть', icon: Icons.arrow_upward_rounded),
        const SizedBox(height: 8),
        _buildArchRow(context, arch: 'upper'),
        const SizedBox(height: 6),
        const _GumLine(),
        const SizedBox(height: 18),
        const _GumLine(),
        const SizedBox(height: 6),
        _buildArchRow(context, arch: 'lower'),
        const SizedBox(height: 8),
        _ArchHeader(label: 'Нижняя челюсть', icon: Icons.arrow_downward_rounded),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: _statusOrder
              .where((status) => status != 'none')
              .map(
                (status) => _LegendItem(
                  color: statusColor(status),
                  outline: statusOutline(status),
                  label: statusLabel(status),
                ),
              )
              .toList(),
        ),
        if (_editable) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.touch_app_rounded, size: 14, color: ClinicTheme.slate),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Нажимайте на зуб, чтобы менять статус',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ClinicTheme.slate,
                      ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildArchRow(BuildContext context, {required String arch}) {
    // Order: index 1 = patient's right molar, 7 = right central incisor,
    // 8 = left central incisor, 14 = left molar. We render left-to-right
    // as the dentist sees it (mirrored), so 1..14 left to right.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(14, (i) {
            final index = i + 1;
            // Distance from center (centerline between 7 and 8).
            final positionFromCenter = index <= 7 ? 8 - index : index - 7;
            final status = _statusFor(arch, index);
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: index == 7 ? 6 : 2,
              ),
              child: _ToothCell(
                number: index,
                width: _toothWidth(positionFromCenter),
                type: _toothType(positionFromCenter),
                arch: arch,
                status: status,
                onTap: _editable ? () => _cycleStatus(arch, index) : null,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ToothCell extends StatelessWidget {
  const _ToothCell({
    required this.number,
    required this.width,
    required this.type,
    required this.arch,
    required this.status,
    this.onTap,
  });

  final int number;
  final double width;
  final String type;
  final String arch;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLower = arch == 'lower';
    final tooth = SizedBox(
      width: width,
      height: 50,
      child: CustomPaint(
        painter: _ToothPainter(
          color: statusColor(status),
          outline: statusOutline(status),
          type: type,
          flip: isLower,
        ),
      ),
    );
    final label = Text(
      number.toString(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ClinicTheme.slate,
            fontSize: 10,
          ),
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: isLower
            ? [tooth, const SizedBox(height: 2), label]
            : [label, const SizedBox(height: 2), tooth],
      ),
    );
  }
}

class _ToothPainter extends CustomPainter {
  _ToothPainter({
    required this.color,
    required this.outline,
    required this.type,
    required this.flip,
  });

  final Color color;
  final Color outline;
  final String type;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (flip) {
      // Flip vertically for lower jaw (root pointing down).
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }
    final path = _toothPath(size, type);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, fill);

    // Subtle cusp lines on the crown for molars/premolars.
    if (type == 'molar' || type == 'premolar') {
      final cuspPaint = Paint()
        ..color = outline.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round;
      final w = size.width;
      final h = size.height;
      final crownTop = h * 0.45;
      final cuspY = h * 0.72;
      if (type == 'molar') {
        canvas.drawLine(Offset(w * 0.35, crownTop + 4), Offset(w * 0.35, cuspY), cuspPaint);
        canvas.drawLine(Offset(w * 0.65, crownTop + 4), Offset(w * 0.65, cuspY), cuspPaint);
        canvas.drawLine(Offset(w * 0.15, cuspY), Offset(w * 0.85, cuspY), cuspPaint);
      } else {
        canvas.drawLine(Offset(w * 0.5, crownTop + 4), Offset(w * 0.5, cuspY), cuspPaint);
      }
    }

    canvas.drawPath(path, stroke);
    canvas.restore();
  }

  Path _toothPath(Size size, String type) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Root section (top half), crown section (bottom half).
    // Root: narrower, tapered into the "gum".
    final rootWidth = type == 'molar' ? 0.78 : (type == 'premolar' ? 0.7 : 0.55);
    final crownWidth = type == 'molar' ? 1.0 : (type == 'premolar' ? 0.95 : 0.85);

    final rootLeft = (1 - rootWidth) / 2 * w;
    final rootRight = w - rootLeft;
    final crownLeft = (1 - crownWidth) / 2 * w;
    final crownRight = w - crownLeft;

    final rootTipY = h * 0.04;
    final neckY = h * 0.45; // gumline
    final crownBottomY = h * 0.97;

    // Start at root left tip
    path.moveTo(rootLeft + 1, rootTipY);
    // Root left side
    path.quadraticBezierTo(rootLeft - 2, h * 0.25, rootLeft, neckY);
    // Neck flare to crown left
    path.quadraticBezierTo(rootLeft - 1, neckY + 2, crownLeft, neckY + 4);
    // Crown left side
    path.quadraticBezierTo(crownLeft - 1, h * 0.78, crownLeft + 1, crownBottomY);

    // Crown bottom (chewing surface)
    if (type == 'molar') {
      // Two bumps
      path.quadraticBezierTo(w * 0.25, h + 1, w * 0.4, crownBottomY - 1);
      path.quadraticBezierTo(w * 0.5, crownBottomY - 4, w * 0.6, crownBottomY - 1);
      path.quadraticBezierTo(w * 0.75, h + 1, crownRight - 1, crownBottomY);
    } else if (type == 'premolar') {
      // Single shallow bump
      path.quadraticBezierTo(w * 0.5, h + 2, crownRight - 1, crownBottomY);
    } else if (type == 'canine') {
      // Pointy
      path.quadraticBezierTo(w * 0.35, crownBottomY, w * 0.5, h + 1);
      path.quadraticBezierTo(w * 0.65, crownBottomY, crownRight - 1, crownBottomY - 1);
    } else {
      // Incisor — flat with slight curve
      path.quadraticBezierTo(w * 0.5, h - 1, crownRight - 1, crownBottomY);
    }

    // Crown right side up
    path.quadraticBezierTo(crownRight + 1, h * 0.78, crownRight, neckY + 4);
    // Neck flare to root right
    path.quadraticBezierTo(rootRight + 1, neckY + 2, rootRight, neckY);
    // Root right side up to tip
    path.quadraticBezierTo(rootRight + 2, h * 0.25, rootRight - 1, rootTipY);
    // Root tip closing curve
    path.quadraticBezierTo(w * 0.5, rootTipY - 3, rootLeft + 1, rootTipY);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _ToothPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.outline != outline ||
      oldDelegate.type != type || oldDelegate.flip != flip;
}

class _ArchHeader extends StatelessWidget {
  const _ArchHeader({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: ClinicTheme.slate),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: ClinicTheme.midnight,
              ),
        ),
      ],
    );
  }
}

class _GumLine extends StatelessWidget {
  const _GumLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD6CF), Color(0xFFFFB2A6), Color(0xFFFFD6CF)],
        ),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.outline, required this.label});

  final Color color;
  final Color outline;
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
            shape: BoxShape.circle,
            border: Border.all(color: outline, width: 1.2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
