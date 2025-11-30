import 'package:flutter/material.dart';

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  final List<String> _specialties = ['Все', 'Терапевт', 'Ортодонт', 'Хирург', 'Детский'];
  int _specialtyIndex = 0;
  final List<double> _ratings = [4.5, 4.0, 3.5, 3.0, 2.5];
  double _selectedRating = 4.5;
  double _distance = 50;
  bool _instantBook = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Специализация', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: List.generate(_specialties.length, (index) {
                final selected = _specialtyIndex == index;
                return ChoiceChip(
                  label: Text(_specialties[index]),
                  selected: selected,
                  onSelected: (_) => setState(() => _specialtyIndex = index),
                );
              }),
            ),
            const SizedBox(height: 20),
            const Text('Рейтинг', style: TextStyle(fontWeight: FontWeight.bold)),
            Column(
              children: _ratings.map((rating) {
                final selected = _selectedRating == rating;
                return InkWell(
                  onTap: () => setState(() => _selectedRating = rating),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.blue : Colors.grey.shade400,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: selected
                              ? Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        ...List.generate(
                          5,
                          (index) => Icon(
                            Icons.star,
                            color: index < rating ? Colors.orange : Colors.grey.shade300,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$rating+',
                            style: TextStyle(
                              color: selected ? Colors.black : Colors.black54,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Дистанция (км)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${_distance.round()} км'),
              ],
            ),
            Slider(
              value: _distance,
              min: 1,
              max: 150,
              divisions: 15,
              label: '${_distance.round()} км',
              onChanged: (value) => setState(() => _distance = value),
              activeColor: Colors.blue,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Мгновенная запись'),
              subtitle: const Text('Без ожидания подтверждения администратора'),
              value: _instantBook,
              onChanged: (value) => setState(() => _instantBook = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _specialtyIndex = 0;
                        _selectedRating = 4.5;
                        _distance = 50;
                        _instantBook = true;
                      });
                    },
                    child: const Text('Сбросить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop({
                      'specialty': _specialties[_specialtyIndex],
                      'rating': _selectedRating,
                      'distance': _distance,
                      'instantBook': _instantBook,
                    }),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
