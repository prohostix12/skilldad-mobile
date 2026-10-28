import 'package:flutter/material.dart';

import '../data/country_codes.dart';
import '../theme/app_colors.dart';

/// Compact "flag + dialing code" button that opens a searchable bottom
/// sheet to pick a country, matching the web app's CountrySelector.
class CountryCodeField extends StatelessWidget {
  const CountryCodeField({
    super.key,
    required this.selectedCode,
    required this.onSelected,
  });

  final String selectedCode;
  final ValueChanged<String> onSelected;

  CountryCode get _selected =>
      kCountryCodes.firstWhere((c) => c.code == selectedCode, orElse: () => kCountryCodes.first);

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CountryPickerSheet(),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPicker(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.fieldBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_selected.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              _selected.code,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final results = query.isEmpty
        ? kCountryCodes
        : kCountryCodes
              .where(
                (c) =>
                    c.name.toLowerCase().contains(query) || c.code.contains(query),
              )
              .toList();

    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.fieldBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TextField(
                autofocus: false,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search country or code',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: results.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.fieldBorder),
                itemBuilder: (context, index) {
                  final country = results[index];
                  return ListTile(
                    leading: Text(country.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(
                      country.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(
                      country.code,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(country.code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
