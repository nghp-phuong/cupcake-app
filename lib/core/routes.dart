import 'models/day_summary.dart';

abstract final class AppRoutes {
  static const menu = '/';
  static const day = '/day';
  static const summary = '/summary'; // arguments: DaySummaryArgs
  static const upgrades = '/upgrades';
  static const decor = '/decor';
  static const recipes = '/recipes';
  static const store = '/store';
  static const settings = '/settings';
}

class DaySummaryArgs {
  const DaySummaryArgs(this.summary);

  final DaySummary summary;
}
