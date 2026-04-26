import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/clinic_theme.dart';

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  String? _sortOrder;
  double? _minRating;
  bool _instantBooking = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: ClinicTheme.snow,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ClinicTheme.mist,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Фильтры', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, size: 22),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Sort
              Text('Сортировка', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip('По рейтингу', 'rating'),
                  _buildChip('По отзывам', 'reviews'),
                ],
              ),

              const SizedBox(height: 24),

              // Rating
              Text('Минимальный рейтинг', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...([4.5, 4.0, 3.5, 3.0] as List<double>).map((r) {
                final selected = _minRating == r;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _minRating = selected ? null : r);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: selected ? ClinicTheme.azureSoft : ClinicTheme.mist,
                      borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? ClinicTheme.azure : ClinicTheme.slate,
                              width: 2,
                            ),
                            color: selected ? ClinicTheme.azure : Colors.transparent,
                          ),
                          child: selected
                              ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: List.generate(5, (i) => Icon(
                            LucideIcons.star,
                            size: 16,
                            color: i < r ? ClinicTheme.amber : ClinicTheme.mist,
                          )),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${r.toStringAsFixed(1)}+',
                          style: TextStyle(
                            color: selected ? ClinicTheme.azure : ClinicTheme.midnight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Instant booking toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: ClinicTheme.mist,
                  borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Мгновенная запись'),
                  subtitle: const Text('Только врачи с открытыми слотами'),
                  value: _instantBooking,
                  activeColor: ClinicTheme.azure,
                  onChanged: (v) => setState(() => _instantBooking = v),
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _sortOrder = null;
                          _minRating = null;
                          _instantBooking = false;
                        });
                      },
                      child: const Text('Сбросить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, {
                        'sort': _sortOrder,
                        'rating': _minRating,
                        'instantBooking': _instantBooking,
                      }),
                      child: const Text('Применить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip(String label, String value) {
    final selected = _sortOrder == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _sortOrder = selected ? null : value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? ClinicTheme.azure : ClinicTheme.snow,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: ClinicTheme.mist),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : ClinicTheme.midnight,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
