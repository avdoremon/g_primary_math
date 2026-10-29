import 'arith_big_generators.dart';
import 'arithmetic_generators.dart';
import 'big_number_generators.dart';
import 'fraction_generators.dart';
import 'generator.dart';
import 'geometry_generators.dart';
import 'measure_more_generators.dart';
import 'measure_generators.dart';
import 'number_generators.dart';
import 'stats_generators.dart';

/// Tất cả dạng bài lớp 1–5, tra theo mã dùng trong JSON chương trình.
abstract class Generators {
  static const List<QuestionGenerator> all = [
    CountObjectsGenerator(),
    SplitNumberGenerator(),
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
    // Lớp 3–5
    DigitsGenerator(),
    RoundingGenerator(),
    RomanGenerator(),
    EvenOddGenerator(),
    FindUnknownGenerator(),
    MulDivBigGenerator(),
    TimesGenerator(),
    ExpressionGenerator(),
    StoryGenerator(),
    FractionGenerator(),
    DecimalGenerator(),
    PercentGenerator(),
    PerimeterAreaGenerator(),
    GeoGenerator(),
    UnitConvertGenerator(),
    TemperatureGenerator(),
    TimeCalcGenerator(),
    MotionGenerator(),
    MoneySumGenerator(),
    DataGenerator(),
  ];

  static final Map<String, QuestionGenerator> byId = {for (final g in all) g.id: g};

  static QuestionGenerator? find(String id) => byId[id];
}
