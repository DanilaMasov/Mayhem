import 'package:flutter/material.dart';

import '../../../core/design_system/tokens/tokens.dart';
import '../domain/progress_models.dart';

Color rankFamilyColor(RankFamily family) => switch (family) {
  RankFamily.spark => MayhemColors.brandSignalSoft,
  RankFamily.mover => MayhemColors.traitConnection,
  RankFamily.catalyst => MayhemColors.traitInitiation,
  RankFamily.maverick => MayhemColors.semanticWarning,
  RankFamily.icon => MayhemColors.brandColdLight,
  RankFamily.mayhem => MayhemColors.traitExpression,
};

IconData rankFamilyIcon(RankFamily family) => switch (family) {
  RankFamily.spark => Icons.bolt,
  RankFamily.mover => Icons.arrow_upward,
  RankFamily.catalyst => Icons.change_history,
  RankFamily.maverick => Icons.explore_outlined,
  RankFamily.icon => Icons.star_outline,
  RankFamily.mayhem => Icons.flare,
};
