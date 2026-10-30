/// Satu cue subtitle: teks yang tampil selama [start]–[end].
class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

/// Parse subtitle WebVTT maupun SubRip (SRT) menjadi daftar cue.
///
/// Satu parser untuk keduanya: baris yang memuat `-->` memulai cue,
/// baris-baris tak kosong sesudahnya adalah teks sampai baris kosong.
/// Dengan begitu baris id cue SRT ("1", "2", ...) dan header WEBVTT
/// (termasuk blok STYLE/NOTE sebelum cue pertama) terlewati secara
/// alami — bukan ditebak per format. Tag HTML VTT (`<c.xxx>`, `<b>`,
/// dsb.) dibuang dari teks tampil. Parse gagal / kosong → daftar
/// kosong; pemanggil menampilkan video tanpa overlay (bukan teks
/// contoh).
List<SubtitleCue> parseSubtitle(String raw) {
  final cues = <SubtitleCue>[];
  Duration? start;
  Duration? end;
  final textLines = <String>[];

  void flush() {
    if (start != null && end != null && textLines.isNotEmpty) {
      final text = textLines.join(' ').trim();
      if (text.isNotEmpty && end! > start!) {
        cues.add(SubtitleCue(start: start!, end: end!, text: text));
      }
    }
    start = null;
    end = null;
    textLines.clear();
  }

  for (final rawLine in raw.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flush();
      continue;
    }
    final arrow = line.indexOf('-->');
    if (arrow >= 0) {
      flush();
      final startText = line.substring(0, arrow).trim();
      var endText = line.substring(arrow + 3).trim();
      // VTT bisa membawa setelan posisi sesudah timestamp akhir.
      final space = endText.indexOf(' ');
      if (space >= 0) {
        endText = endText.substring(0, space);
      }
      start = _parseTimestamp(startText);
      end = _parseTimestamp(endText);
      if (start == null || end == null) {
        start = null;
        end = null;
      }
      continue;
    }
    if (start != null) {
      // Buang tag HTML VTT + entitas umum, rapatkan spasi.
      final clean = line
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (clean.isNotEmpty) {
        textLines.add(clean);
      }
    }
    // Baris lain di luar cue (header WEBVTT, nomor SRT, blok STYLE)
    // diabaikan.
  }
  flush();
  cues.sort((a, b) => a.start.compareTo(b.start));
  return cues;
}

/// `HH:MM:SS.mmm` (VTT) atau `HH:MM:SS,mmm` (SRT); null bila tak valid.
Duration? _parseTimestamp(String text) {
  final parts = text.split(':');
  if (parts.length != 3) {
    return null;
  }
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  final secondsParts = parts[2].replaceAll(',', '.').split('.');
  if (secondsParts.isEmpty) {
    return null;
  }
  final seconds = int.tryParse(secondsParts[0]);
  var millis = 0;
  if (secondsParts.length > 1) {
    final msText = secondsParts[1].padRight(3, '0').substring(0, 3);
    millis = int.tryParse(msText) ?? 0;
  }
  if (hours == null || minutes == null || seconds == null) {
    return null;
  }
  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: millis,
  );
}

/// Cue yang berlaku pada [position], atau null bila tidak ada cue
/// yang mencakup posisi itu (subtitle disembunyikan, bukan teks lama
/// yang menggantung).
SubtitleCue? cueAt(List<SubtitleCue> cues, Duration position) {
  for (final cue in cues) {
    if (position >= cue.start && position < cue.end) {
      return cue;
    }
  }
  return null;
}
