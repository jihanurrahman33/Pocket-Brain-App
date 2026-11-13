import 'package:flutter/widgets.dart';

/// Material 3 window size classes, by available width.
///
/// - compact:  phones in portrait            (< 600)
/// - medium:   large phones, small tablets   (600–839)
/// - expanded: tablets, small desktop windows (840–1199)
/// - large:    desktop                       (≥ 1200)
enum WindowSize {
  compact,
  medium,
  expanded,
  large;

  static const mediumMinWidth = 600.0;
  static const expandedMinWidth = 840.0;
  static const largeMinWidth = 1200.0;

  static WindowSize fromWidth(double width) => switch (width) {
    < mediumMinWidth => compact,
    < expandedMinWidth => medium,
    < largeMinWidth => expanded,
    _ => large,
  };

  bool get isCompact => this == compact;

  /// Wide enough for side-by-side panes.
  bool get hasTwoPanes => index >= expanded.index;

  bool operator >=(WindowSize other) => index >= other.index;
}

extension ResponsiveContext on BuildContext {
  WindowSize get windowSize => WindowSize.fromWidth(MediaQuery.sizeOf(this).width);

  /// Picks a value for the current window size, falling back to the next
  /// smaller size that has one.
  T responsive<T>({required T compact, T? medium, T? expanded, T? large}) => switch (windowSize) {
    WindowSize.compact => compact,
    WindowSize.medium => medium ?? compact,
    WindowSize.expanded => expanded ?? medium ?? compact,
    WindowSize.large => large ?? expanded ?? medium ?? compact,
  };
}
