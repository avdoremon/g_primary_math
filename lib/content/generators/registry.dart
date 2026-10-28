import 'arithmetic_generators.dart';
import 'generator.dart';
import 'measure_generators.dart';
import 'number_generators.dart';
import 'stats_generators.dart';

/// Tất cả dạng bài lớp 1–2, tra theo mã dùng trong JSON chương trình.
abstract class Generators {
  static const List<QuestionGenerator> all = [
    CountObjectsGenerator(),
    PlaceValueGenerator(),
    CompareGenerator(),
    OrderNumbersGenerator(),
    NeighborsGenerator(),
    AddSubGenerator(),
    WordProblemGenerator(),
    MulDivGenerator(),
    SkipCountGenerator(),
    PolylineLengthGenerator(),
    PositionGenerator(),
    ShapeIdentifyGenerator(),
    LengthCompareGenerator(),
    UnitChooseGenerator(),
    TimeGenerator(),
    MoneyIdentifyGenerator(),
    PictographGenerator(),
    LikelihoodGenerator(),
  ];

  static final Map<String, QuestionGenerator> byId = {for (final g in all) g.id: g};

  static QuestionGenerator? find(String id) => byId[id];
}
