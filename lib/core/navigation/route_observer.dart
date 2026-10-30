import 'package:flutter/material.dart';

/// Observer rute tunggal aplikasi (dipakai MaterialApp + halaman yang
/// perlu tahu kapan tertutup/dibuka kembali, mis. feed video agar
/// berhenti saat Player didorong di atasnya). Didefinisikan di core
/// agar tidak ada import siklis app ↔ halaman.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
