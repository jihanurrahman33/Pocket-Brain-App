import 'package:flutter/widgets.dart';

import '../responsive/window_size.dart';

/// Spacing scale (4-pt grid). Use these instead of literal numbers.
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Room under scrolling content so a FAB never covers the last item.
  static const fabClearance = 96.0;

  static const radiusSm = 10.0;
  static const radiusMd = 14.0;
  static const radiusLg = 20.0;

  /// Readable line length for text-heavy screens.
  static const readableWidth = 760.0;

  /// Maximum width for grid-heavy screens.
  static const wideContentWidth = 1280.0;

  /// Width of side panels in two-pane layouts.
  static const sidePaneWidth = 340.0;

  /// Horizontal page padding grows with the window.
  static double pagePadding(BuildContext context) =>
      context.responsive(compact: lg, medium: xl, expanded: xl, large: xxl);
}
