import 'package:flutter/material.dart';

/// Token warna Dracin Reels (satu sumber kebenaran visual).
///
/// Nilai inti dipertahankan dari tema lama (latar gelap + aksen oranye)
/// agar tidak ada layar yang berubah warna diam-diam; token baru hanya
/// MENAMBAH (emas bintang, sukses, bahaya, skeleton) untuk komponen
/// custom rombak total.
class DracinColors {
  static const Color background = Color(0xFF0B0E14);
  static const Color surface = Color(0xFF161B26);
  static const Color card = Color(0xFF1E2433);
  static const Color border = Color(0xFF2E3547);
  static const Color accent = Color(0xFFFF6B35);
  static const Color accentTeal = Color(0xFF2DD4BF);
  static const Color gold = Color(0xFFFFC107);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFF43F5E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB9C0CC);
  static const Color textHint = Color(0xFF8A93A5);
  static const Color scrim = Color(0x88000000);
  static const Color skeletonBase = Color(0xFF232A3A);
  static const Color skeletonHighlight = Color(0xFF2E3547);
}

/// Skala jarak 4pt + radius standar. Semua layar custom memakai token
/// ini (bukan angka lepas) agar satu bahasa visual.
class DracinSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const double radiusCard = 16;
  static const double radiusSheet = 24;
  static const double radiusButton = 24;
  static const double radiusChip = 20;
  static const double radiusInput = 12;
  static const double radiusThumb = 8;
  static const double radiusPill = 999;
}
