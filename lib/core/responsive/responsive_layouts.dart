import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'window_size.dart';

/// Centres content, caps its width and applies window-aware padding.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.readableWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// A scrollable page body with consistent responsive padding and width.
class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.children,
    this.maxWidth = AppSpacing.readableWidth,
    this.bottomPadding = AppSpacing.xxl,
    this.controller,
  });

  final List<Widget> children;
  final double maxWidth;
  final double bottomPadding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pagePadding(context);
    return ResponsiveCenter(
      maxWidth: maxWidth,
      child: ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(horizontal, AppSpacing.sm, horizontal, bottomPadding),
        children: children,
      ),
    );
  }
}

/// Shows [primary] and [secondary] side by side on expanded/large windows
/// and stacked (primary first) on smaller ones.
///
/// Both panes scroll independently when side by side; when stacked, they
/// share one scroll view.
class AdaptiveTwoPane extends StatelessWidget {
  const AdaptiveTwoPane({
    super.key,
    required this.primary,
    required this.secondary,
    this.footer = const [],
    this.secondaryWidth = AppSpacing.sidePaneWidth,
    this.maxWidth = AppSpacing.wideContentWidth,
    this.bottomPadding = AppSpacing.xxl,
  });

  /// Main content, as a list of widgets.
  final List<Widget> primary;

  /// Supporting content shown in the side pane.
  final List<Widget> secondary;

  /// Ends the primary pane side by side, or the whole page when stacked
  /// (e.g. a form's save buttons).
  final List<Widget> footer;
  final double secondaryWidth;
  final double maxWidth;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final padding = AppSpacing.pagePadding(context);
    if (!context.windowSize.hasTwoPanes) {
      return ResponsiveListView(
        bottomPadding: bottomPadding,
        children: [...primary, ...secondary, ...footer],
      );
    }
    EdgeInsets paneInsets({required bool leading}) => EdgeInsets.fromLTRB(
      leading ? padding : AppSpacing.md,
      AppSpacing.sm,
      leading ? AppSpacing.md : padding,
      bottomPadding,
    );
    return ResponsiveCenter(
      maxWidth: maxWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(padding: paneInsets(leading: true), children: [...primary, ...footer]),
          ),
          SizedBox(
            width: secondaryWidth,
            child: ListView(padding: paneInsets(leading: false), children: secondary),
          ),
        ],
      ),
    );
  }
}

/// Number of grid columns that fit, between [min] and [max].
int adaptiveColumns(BuildContext context, {int min = 1, int max = 4}) =>
    context.responsive(compact: 1, medium: 2, expanded: 3, large: 4).clamp(min, max);
