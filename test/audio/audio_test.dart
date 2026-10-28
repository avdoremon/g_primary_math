import 'package:flutter_test/flutter_test.dart';
import 'package:g_primary_math/audio/audio_service.dart';
import 'package:g_primary_math/audio/speech_planner.dart';

void main() {
  group('Tên file ghi âm', () {
    test('viết kiểu Telex, không trùng giữa các thanh', () {
      expect(viSlug('bảy'), 'bayr');
      expect(viSlug('bay'), 'bay');
      expect(viSlug('năm'), 'nawm');
      expect(viSlug('mười'), 'muwowif');
      expect(viSlug('bằng mấy'), 'bawngf_maays');
      expect(viSlug('Đúng rồi!'), 'ddungs_rooif');
      expect(viSlug('lẻ'), 'ler');
      expect(viSlug('lẽ'), 'lex');
    });
  });

  group('Ghép giọng đọc', () {
    final planner = SpeechPlanner(clips: ['bảy', 'cộng', 'năm', 'bằng mấy', 'mười', 'hai', 'chưa đúng rồi']);

    test('đọc được "Bảy cộng năm bằng mấy?" bằng các đoạn ghép', () {
      expect(planner.plan('Bảy cộng năm bằng mấy?'), const [
        ClipPart('bảy', 'audio/voice/bayr.m4a'),
        ClipPart('cộng', 'audio/voice/coongj.m4a'),
        ClipPart('năm', 'audio/voice/nawm.m4a'),
        ClipPart('bằng mấy', 'audio/voice/bawngf_maays.m4a'),
      ]);
    });

    test('chữ số được đổi thành chữ trước khi ghép', () {
      expect(planner.plan('7 cộng 5 bằng mấy?').length, 4);
      expect(planner.plan('12').map((p) => (p as ClipPart).phrase), ['mười', 'hai']);
    });

    test('thiếu một từ thì cả câu đọc bằng TTS; mỗi câu xét riêng, có ngắt nghỉ', () {
      final parts = planner.plan('Chưa đúng rồi. Bảy cộng năm bằng mười hai.');
      expect(parts, [
        const ClipPart('chưa đúng rồi', 'audio/voice/chuwa_ddungs_rooif.m4a'),
        const PausePart(),
        const TtsPart('Bảy cộng năm bằng mười hai.'),
      ]);
    });

    test('chưa có ghi âm nào thì đọc TTS nguyên câu', () {
      expect(SpeechPlanner().plan('Con giơ tay trái lên!'), const [TtsPart('Con giơ tay trái lên!')]);
    });
  });

  group('Dịch vụ âm thanh', () {
    test('đọc đoạn ghép và TTS theo thứ tự, tắt giọng thì không đọc', () async {
      final tts = SilentTts();
      final voice = SilentPlayer();
      final audio = AudioService(
        tts: tts,
        voicePlayer: voice,
        sfxPlayer: SilentPlayer(),
        planner: SpeechPlanner(clips: ['đúng rồi']),
      );
      await audio.init();
      await audio.say('Đúng rồi! Giỏi quá!');
      expect(voice.played, ['audio/voice/ddungs_rooif.m4a']);
      expect(tts.spoken, ['Giỏi quá!']);

      audio.voiceOn = false;
      await audio.say('Tuyệt vời!');
      expect(tts.spoken, ['Giỏi quá!']);
    });

    test('hiệu ứng: đúng file, tắt hiệu ứng thì không phát', () async {
      final sfx = SilentPlayer();
      final audio = AudioService(tts: SilentTts(), voicePlayer: SilentPlayer(), sfxPlayer: sfx);
      audio.play(Sfx.correct);
      await Future<void>.delayed(Duration.zero);
      expect(sfx.played, ['audio/sfx/correct.wav']);
      audio.sfxOn = false;
      audio.play(Sfx.wrong);
      await Future<void>.delayed(Duration.zero);
      expect(sfx.played.length, 1);
    });
  });
}
