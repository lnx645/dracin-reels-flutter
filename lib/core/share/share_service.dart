import 'package:flutter/services.dart';

/// Berbagi lewat share sheet sistem Android (chooser).
///
/// Tanpa package baru: memakai MethodChannel yang sama dengan updater
/// (`dev.uwa.dracinreels/updater`) + Intent ACTION_SEND di MainActivity.
/// Teks saja — tidak pernah mengarang tautan web (belum ada pemutar
/// web publik untuk series). Gagal → PlatformException diteruskan,
/// pemanggil menampilkan pesan asli (bukan sheet placeholder).
class DracinShare {
  static const MethodChannel _channel =
      MethodChannel('dev.uwa.dracinreels/updater');

  static Future<void> shareText(String text) async {
    await _channel.invokeMethod<String>('shareText', text);
  }
}
