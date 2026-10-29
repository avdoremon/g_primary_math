import 'dart:math' as math;

import '../question.dart';
import 'generator.dart';

/// Lớp 2: đọc biểu đồ tranh, nêu nhận xét đơn giản.
class PictographGenerator extends QuestionGenerator {
  const PictographGenerator();

  @override
  String get id => 'pictograph';

  static const themes = <String, Map<String, String>>{
    'fruit': {'apple': 'quả táo', 'orange': 'quả cam', 'banana': 'quả chuối', 'mango': 'quả xoài'},
    'pets': {'cat': 'con mèo', 'dog': 'con chó', 'fish': 'con cá', 'rabbit': 'con thỏ'},
  };

  @override
  Question generate(GenParams p, math.Random r) {
    final theme = themes[pick(themes.keys.toList(), r)]!;
    final kinds = theme.keys.toList()..shuffle(r);
    final rows = kinds.take(p.intOf('rows', 3)).toList();
    final maxCount = p.intOf('maxCount', 6);
    final counts = <String, int>{};
    for (final k in rows) {
      var c = between(r, 1, maxCount);
      while (counts.values.contains(c) && counts.length < maxCount) {
        c = between(r, 1, maxCount);
      }
      counts[k] = c;
    }
    final data = {
      'kind': 'pictograph',
      'rows': [
        for (final k in rows) {'item': k, 'count': counts[k]},
      ],
    };

    final ask = pick(p.strList('ask', const ['count', 'most', 'difference']), r);
    switch (ask) {
      case 'most':
      case 'least':
        final most = ask == 'most';
        final sorted = [...rows]..sort((a, b) => counts[a]!.compareTo(counts[b]!));
        final target = most ? sorted.last : sorted.first;
        final word = most ? 'nhiều nhất' : 'ít nhất';
        final o = textOptions(r, theme[target]!, [for (final k in rows) theme[k]!], p.answers);
        return Question(
          generator: id,
          prompt: 'Loại nào có $word?',
          speech: 'Nhìn biểu đồ tranh, loại nào có $word?',
          options: o.options,
          answer: o.answer,
          explanation: '${cap(theme[target]!)}: ${counts[target]} – $word.',
          explanationSpeech: '${cap(theme[target]!)} có ${say(counts[target]!)}, $word.',
          data: data,
        );
      case 'difference':
        final a = rows[0], b = rows[1];
        final big = counts[a]! >= counts[b]! ? a : b;
        final small = big == a ? b : a;
        final diff = counts[big]! - counts[small]!;
        final o = numericOptions(r, diff, p.answers,
            max: maxCount, preferred: [counts[big]!, counts[small]!, diff + 1, counts[big]! + counts[small]!]);
        return Question(
          generator: id,
          prompt: 'Số ${theme[big]} nhiều hơn số ${theme[small]} bao nhiêu?',
          speech: 'Số ${theme[big]} nhiều hơn số ${theme[small]} bao nhiêu?',
          options: o.options,
          answer: o.answer,
          explanation: '${counts[big]} − ${counts[small]} = $diff',
          explanationSpeech: '${cap(say(counts[big]!))} trừ ${say(counts[small]!)} bằng ${say(diff)}.',
          data: data,
        );
      default:
        final k = pick(rows, r);
        final n = counts[k]!;
        final o = numericOptions(r, n, p.answers, min: 1, max: maxCount + 2, preferred: [n + 1, n - 1]);
        return Question(
          generator: id,
          prompt: 'Có bao nhiêu ${theme[k]}?',
          speech: 'Nhìn biểu đồ tranh, có bao nhiêu ${theme[k]}?',
          options: o.options,
          answer: o.answer,
          explanation: 'Hàng ${theme[k]} có $n hình: $n ${theme[k]}.',
          explanationSpeech: 'Đếm hàng ${theme[k]}, có ${say(n)} hình.',
          data: data,
        );
    }
  }
}

/// Lớp 2: làm quen với khả năng xảy ra – "chắc chắn", "có thể", "không thể".
class LikelihoodGenerator extends QuestionGenerator {
  const LikelihoodGenerator();

  @override
  String get id => 'likelihood';

  static const _colors = ['xanh', 'đỏ', 'vàng'];
  static const options = ['Chắc chắn', 'Có thể', 'Không thể'];

  @override
  Question generate(GenParams p, math.Random r) {
    final colors = [..._colors]..shuffle(r);
    final mixed = r.nextBool();
    final inBox = mixed ? colors.take(2).toList() : [colors.first];
    final boxText = mixed ? 'Hộp có bóng ${inBox[0]} và bóng ${inBox[1]}.' : 'Hộp chỉ có bóng ${inBox[0]}.';

    // Chọn màu hỏi: có trong hộp hoặc không có trong hộp.
    final askIn = r.nextInt(3) != 0;
    final asked = askIn ? pick(inBox, r) : colors.last;
    final int answer;
    final String reason;
    if (!inBox.contains(asked)) {
      answer = 2;
      reason = 'Trong hộp không có bóng $asked.';
    } else if (inBox.length == 1) {
      answer = 0;
      reason = 'Trong hộp chỉ có bóng $asked.';
    } else {
      answer = 1;
      reason = 'Trong hộp có cả bóng ${inBox[0]} và bóng ${inBox[1]}.';
    }
    final q = 'Lấy ra một quả bóng. Lấy được bóng $asked là:';
    return Question(
      generator: id,
      prompt: '$boxText $q',
      speech: '$boxText Không nhìn, lấy ra một quả bóng. Lấy được bóng $asked là chắc chắn, có thể hay không thể?',
      options: options,
      answer: answer,
      explanation: '$reason Nên: ${options[answer].toLowerCase()}.',
      explanationSpeech: '$reason Nên lấy được bóng $asked là ${options[answer].toLowerCase()}.',
      data: {'box': inBox, 'asked': asked},
    );
  }
}
