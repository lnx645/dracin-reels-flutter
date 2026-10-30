import 'package:flutter/material.dart';

/// Progress upload dari byte yang benar-benar terkirim (bukan animasi).
class UploadProgress extends ChangeNotifier {
  int sent = 0;
  int total = 0;

  void update(int newSent, int newTotal) {
    sent = newSent;
    total = newTotal;
    notifyListeners();
  }

  double? get fraction =>
      total > 0 ? (sent / total).clamp(0.0, 1.0) : null;

  int get percent =>
      total > 0 ? ((sent / total) * 100).round().clamp(0, 100) : 0;

  /// Label "X / Y MB • Z%" (koma desimal Indonesia).
  String get label => '${_mb(sent)} / ${_mb(total)} MB • $percent%';

  static String _mb(int bytes) =>
      (bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');
}

/// Dialog progress upload yang PERSISTEN selama upload: tidak bisa
/// ditutup dengan ketuk di luar atau tombol kembali (barrierDismissible
/// false + PopScope canPop false). Pemanggil menutupnya lewat [close]
/// setelah upload selesai/gagal — lalu menampilkan status sukses atau
/// error asli lewat jalur normal formulir.
///
/// Sengaja HANYA dialog di aplikasi (tanpa notifikasi sistem Android):
/// upload http tidak berlanjut andal di background, dan notifikasi
/// sistem butuh izin POST_NOTIFICATIONS tambahan — dialog ini sudah
/// memenuhi perintah tanpa izin baru.
class UploadProgressDialog {
  UploadProgressDialog(this._progress);

  final UploadProgress _progress;
  bool _open = false;

  void show(BuildContext context, String title) {
    if (_open) {
      return;
    }
    _open = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title),
          content: ListenableBuilder(
            listenable: _progress,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LinearProgressIndicator(value: _progress.fraction),
                const SizedBox(height: 12),
                Text(_progress.label),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => _open = false);
  }

  void close(BuildContext context) {
    if (!_open) {
      return;
    }
    _open = false;
    Navigator.of(context, rootNavigator: true).pop();
  }
}
