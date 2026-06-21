import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class FiltersScreen extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  const FiltersScreen({super.key, required this.currentFilters});

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  final List<String> _areas = [
    'All Areas',
    'Amman',
    'Zarqa',
    'Irbid',
    'Aqaba',
    'Madaba',
    'Karak',
    'Salt',
    'Mafraq',
  ];

  final List<String> _landTypes = ['Residential', 'Commercial', 'Agricultural'];

  late String _selectedArea;
  late RangeValues _priceRange;
  late RangeValues _sizeRange;
  late List<String> _selectedLandTypes;

  @override
  void initState() {
    super.initState();
    final f = widget.currentFilters;
    _selectedArea = f['area'] ?? 'All Areas';
    _priceRange = RangeValues(
      (f['minPrice'] ?? 0).toDouble(),
      (f['maxPrice'] ?? 1000000).toDouble(),
    );
    _sizeRange = RangeValues(
      (f['minSize'] ?? 0).toDouble(),
      (f['maxSize'] ?? 10000).toDouble(),
    );
    _selectedLandTypes = List<String>.from(f['landTypes'] ?? []);
  }

  void _reset() {
    setState(() {
      _selectedArea = 'All Areas';
      _priceRange = const RangeValues(0, 1000000);
      _sizeRange = const RangeValues(0, 10000);
      _selectedLandTypes = [];
    });
    // نرجع للـ home screen مع فلاتر فارغة مباشرة
    Navigator.of(context).pop(<String, dynamic>{});
  }

  void _apply() {
    final filters = <String, dynamic>{};
    if (_selectedArea != 'All Areas') filters['area'] = _selectedArea;
    if (_priceRange.start > 0) filters['minPrice'] = _priceRange.start;
    if (_priceRange.end < 1000000) filters['maxPrice'] = _priceRange.end;
    if (_sizeRange.start > 0) filters['minSize'] = _sizeRange.start;
    if (_sizeRange.end < 100000) filters['maxSize'] = _sizeRange.end;
    if (_selectedLandTypes.isNotEmpty)
      filters['landTypes'] = _selectedLandTypes;
    Navigator.of(context).pop(filters);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filters'),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionTitle('Area / Governorate'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _areas.map((area) {
              final selected = _selectedArea == area;
              return GestureDetector(
                onTap: () => setState(() => _selectedArea = area),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          selected ? AppTheme.primary : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Text(
                    area,
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.textDark,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          _SectionTitle('Price Range (JD)'),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_priceRange.start.toInt()} JD',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              Text('${_priceRange.end.toInt()} JD',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primary,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withValues(alpha: 0.1),
              inactiveTrackColor: const Color(0xFFE5E7EB),
            ),
            child: RangeSlider(
              values: _priceRange,
              min: 0,
              max: 1000000,
              divisions: 200,
              onChanged: (v) => setState(() => _priceRange = v),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Size Range (m²)'),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_sizeRange.start.toInt()} m²',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              Text('${_sizeRange.end.toInt()} m²',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primary,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withValues(alpha: 0.1),
              inactiveTrackColor: const Color(0xFFE5E7EB),
            ),
            child: RangeSlider(
              values: _sizeRange,
              min: 0,
              max: 100000,
              divisions: 100,
              onChanged: (v) => setState(() => _sizeRange = v),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Land Type'),
          const SizedBox(height: 12),
          ..._landTypes.map((type) {
            final selected = _selectedLandTypes.contains(type);
            return CheckboxListTile(
              value: selected,
              title: Text(type),
              activeColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedLandTypes.add(type);
                  } else {
                    _selectedLandTypes.remove(type);
                  }
                });
              },
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: ElevatedButton(
          onPressed: _apply,
          child: const Text('Apply Filters'),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.textDark,
      ),
    );
  }
}
