import '../factories/robot_factory.dart';

/// State shared by the steps of the running scenario.
///
/// [gherkinPatrolTest] opens a world before the scenario's first step and
/// closes it after the last one, pass or fail, so nothing leaks between
/// scenarios. Add a field here when steps need to hand data to later steps.
class FeatureWorld {
  static FeatureWorld? _current;

  final RobotFactory robots;

  FeatureWorld._(this.robots);

  static FeatureWorld get current =>
      _current ?? (throw StateError('A step ran outside gherkinPatrolTest'));

  static void open(RobotFactory robots) => _current = FeatureWorld._(robots);

  static void close() => _current = null;
}
