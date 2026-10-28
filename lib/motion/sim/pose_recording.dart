import 'dart:convert';

import '../../pose/pose_frame.dart';

/// Ghi và phát lại chuỗi khung xương (định dạng JSON Lines: mỗi dòng một khung).
///
/// Dùng để thu động tác thật của trẻ khi thử nghiệm, rồi chạy lại trong test
/// để tinh chỉnh ngưỡng mà không cần trẻ đứng trước camera.
class PoseRecording {
  PoseRecording([List<PoseFrame>? frames]) : frames = frames ?? <PoseFrame>[];

  final List<PoseFrame> frames;

  void add(PoseFrame f) => frames.add(f);

  Duration get duration => frames.isEmpty ? Duration.zero : frames.last.arrival - frames.first.arrival;

  String toJsonLines() => frames.map((f) => jsonEncode(f.toJson())).join('\n');

  factory PoseRecording.fromJsonLines(String text) {
    final out = <PoseFrame>[];
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      out.add(PoseFrame.fromJson(jsonDecode(line) as Map<String, dynamic>));
    }
    return PoseRecording(out);
  }
}
