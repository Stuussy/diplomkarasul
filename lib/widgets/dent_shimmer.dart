import 'package:flutter/material.dart';

import '../theme/clinic_theme.dart';

/// Skeleton shimmer loader for premium loading states.
class DentShimmer extends StatefulWidget {
  const DentShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = ClinicTheme.radiusM,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<DentShimmer> createState() => _DentShimmerState();
}

class _DentShimmerState extends State<DentShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * _controller.value, 0),
              end: Alignment(-0.5 + 3 * _controller.value, 0),
              colors: const [
                ClinicTheme.mist,
                Color(0xFFE0E5EA),
                ClinicTheme.mist,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Convenient shimmer card preset.
class DentShimmerCard extends StatelessWidget {
  const DentShimmerCard({super.key, this.height = 100});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: ClinicTheme.snow,
        borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
        boxShadow: ClinicTheme.shadowSm,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          DentShimmer(width: 150, height: 14, borderRadius: 7),
          SizedBox(height: 12),
          DentShimmer(width: double.infinity, height: 12, borderRadius: 6),
          SizedBox(height: 8),
          DentShimmer(width: 200, height: 12, borderRadius: 6),
        ],
      ),
    );
  }
}
