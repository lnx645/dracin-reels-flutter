import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Bahasa chip yang SAMA untuk filter Jelajahi (interaktif) dan chip
/// tampil detail series (statis) — keluhan uwa: chip genre lama wrap
/// sampai ada chip yatim di baris kedua.
/// - Terpilih: isi oranye utama + teks putih tebal.
/// - Tidak terpilih: permukaan gelap + garis tepi halus + teks terang.
/// - Padding + radius konsisten di semua chip; teks tidak terpotong
///   (chip melebar mengikuti teks di baris geser, bukan wrap).
class SeriesFilterChip extends StatelessWidget {
  const SeriesFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.card,
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.bold : FontWeight.w600,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape: const StadiumBorder(),
    );
  }
}

/// Chip tampil saja (detail series): gaya visual sama dengan chip
/// filter yang tidak terpilih, tapi statis (tidak bisa diketuk).
class SeriesDisplayChip extends StatelessWidget {
  const SeriesDisplayChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.card,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape: const StadiumBorder(),
    );
  }
}
