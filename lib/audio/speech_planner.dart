import '../content/vietnamese_number.dart';

/// Một đoạn của câu đọc.
sealed class SpeechPart {
  const SpeechPart();
}

/// Đoạn ghi âm sẵn (giọng người đọc), [asset] tính từ thư mục `assets/`.
class ClipPart extends SpeechPart {
  const ClipPart(this.phrase, this.asset);

  final String phrase;
  final String asset;

  @override
  bool operator ==(Object other) => other is ClipPart && other.asset == asset;

  @override
  int get hashCode => asset.hashCode;

  @override
  String toString() => 'Clip($phrase)';
}

/// Đọc bằng giọng tổng hợp của máy (TTS tiếng Việt) khi chưa có ghi âm.
class TtsPart extends SpeechPart {
  const TtsPart(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is TtsPart && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'Tts($text)';
}

/// Ngắt nghỉ giữa hai câu.
class PausePart extends SpeechPart {
  const PausePart([this.duration = const Duration(milliseconds: 250)]);

  final Duration duration;

  @override
  bool operator ==(Object other) => other is PausePart && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'Pause(${duration.inMilliseconds})';
}

/// Tách câu cần đọc thành các đoạn ghi âm sẵn.
///
/// Giọng đọc ghép từ các đoạn ghi âm ngắn (từ, cụm từ, số) theo danh sách [clips].
/// Mỗi câu (ngăn bởi . ! ? ; :) được ghép trọn bằng ghi âm nếu đủ đoạn; thiếu dù chỉ một từ
/// thì cả câu đọc bằng TTS, để không lẫn hai giọng trong một câu.
/// Chữ số trong câu được đổi sang chữ ("12" → "mười hai") trước khi ghép.
class SpeechPlanner {
  SpeechPlanner({Iterable<String> clips = const [], this.folder = 'audio/voice', this.extension = 'm4a'})
      : _clips = {for (final c in clips) normalize(c)},
        _maxWords = clips.isEmpty ? 1 : clips.map((c) => normalize(c).split(' ').length).reduce((a, b) => a > b ? a : b);

  final Set<String> _clips;
  final int _maxWords;
  final String folder;
  final String extension;

  bool get hasClips => _clips.isNotEmpty;

  static final _sentenceBreak = RegExp(r'[.!?;:…]+');
  static final _strip = RegExp(r'''[,"“”‘’'()«»\[\]–—-]''');
  static final _digits = RegExp(r'\d+');
  static final _spaces = RegExp(r'\s+');

  /// Chữ thường, bỏ dấu câu, gộp khoảng trắng.
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(_strip, ' ').replaceAll(_spaces, ' ').trim();

  String assetFor(String phrase) => '$folder/${viSlug(phrase)}.$extension';

  List<SpeechPart> plan(String text) {
    final parts = <SpeechPart>[];
    final sentences = text.split(_sentenceBreak);
    final breaks = _sentenceBreak.allMatches(text).toList();
    for (var i = 0; i < sentences.length; i++) {
      final raw = sentences[i].trim();
      if (raw.isEmpty) continue;
      if (parts.isNotEmpty) parts.add(const PausePart());
      final clips = _clipsFor(raw);
      if (clips != null) {
        parts.addAll(clips);
      } else {
        final end = i < breaks.length ? breaks[i].group(0)! : '';
        parts.add(TtsPart('$raw$end'));
      }
    }
    return parts;
  }

  /// Ghép một câu bằng ghi âm (khớp cụm dài nhất trước); null nếu thiếu đoạn.
  List<ClipPart>? _clipsFor(String sentence) {
    if (_clips.isEmpty) return null;
    final spoken = sentence.replaceAllMapped(_digits, (m) => VietnameseNumber.read(int.parse(m.group(0)!)));
    final words = normalize(spoken).split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final out = <ClipPart>[];
    var i = 0;
    while (i < words.length) {
      var matched = 0;
      for (var n = _maxWords; n >= 1; n--) {
        if (i + n > words.length) continue;
        final phrase = words.sublist(i, i + n).join(' ');
        if (_clips.contains(phrase)) {
          out.add(ClipPart(phrase, assetFor(phrase)));
          matched = n;
          break;
        }
      }
      if (matched == 0) return null;
      i += matched;
    }
    return out;
  }
}

// ------------------------------------------------------------------ tên file ghi âm

/// Nguyên âm có dấu → (nguyên âm gốc kiểu Telex, phím thanh). Thứ tự thanh: ngang, sắc, huyền, hỏi, ngã, nặng.
const _toneKeys = ['', 's', 'f', 'r', 'x', 'j'];
const _vowelRows = <String, String>{
  'a': 'aáàảãạ',
  'aw': 'ăắằẳẵặ',
  'aa': 'âấầẩẫậ',
  'e': 'eéèẻẽẹ',
  'ee': 'êếềểễệ',
  'i': 'iíìỉĩị',
  'o': 'oóòỏõọ',
  'oo': 'ôốồổỗộ',
  'ow': 'ơớờởỡợ',
  'u': 'uúùủũụ',
  'uw': 'ưứừửữự',
  'y': 'yýỳỷỹỵ',
};

final Map<String, (String, String)> _vowelMap = {
  for (final e in _vowelRows.entries)
    for (var t = 0; t < 6; t++) e.value[t]: (e.key, _toneKeys[t]),
};

/// Tên file ghi âm cho một cụm từ, viết kiểu Telex để không trùng giữa các thanh:
/// "bảy" → "bayr", "năm" → "nawm", "bằng mấy" → "bawngf_maays", "mười" → "muwowif".
String viSlug(String phrase) {
  final words = SpeechPlanner.normalize(phrase).split(' ').where((w) => w.isNotEmpty);
  return words.map(_slugWord).join('_');
}

String _slugWord(String word) {
  final b = StringBuffer();
  var tone = '';
  for (final ch in word.split('')) {
    final v = _vowelMap[ch];
    if (v != null) {
      b.write(v.$1);
      if (v.$2.isNotEmpty) tone = v.$2;
    } else if (ch == 'đ') {
      b.write('dd');
    } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
      b.write(ch);
    }
  }
  return '$b$tone';
}
