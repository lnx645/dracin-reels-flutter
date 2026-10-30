import 'package:flutter/foundation.dart';

/// Apakah ada video yang sedang diputar saat ini (PlayerPage maupun
/// preview Reels). Ditulis oleh pemutar, dibaca oleh gerbang updater:
/// prompt instal TIDAK PERNAH mengganggu saat pengguna sedang menonton
/// — saat itu update hanya tampil sebagai banner yang tidak mengganggu.
final ValueNotifier<bool> playbackActive = ValueNotifier<bool>(false);
