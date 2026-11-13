import 'package:flutter/material.dart';

import '../error/failure.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Marks AI-generated content so it is never confused with the user's own
/// words.
class AiBadge extends StatelessWidget {
  const AiBadge({super.key, this.label = 'AI-generated'});

  final String label;

  static const _iconSize = 12.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: scheme.aiContainer,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: _iconSize, color: scheme.onAiContainer),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onAiContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  static const _iconSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: _iconSize, color: theme.colorScheme.outline),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}

/// A full-page loading indicator.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// A full-page error with a retry button.
class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: failure is NotFoundFailure ? Icons.search_off_rounded : Icons.error_outline_rounded,
    title: failure is NotFoundFailure ? 'Not found' : 'Something went wrong',
    message: failure.message,
    action: onRetry == null
        ? null
        : OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
  );
}

/// A small inline spinner for buttons and status rows.
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key});

  static const _size = 16.0;
  static const _stroke = 2.0;

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: _size,
    child: CircularProgressIndicator(strokeWidth: _stroke),
  );
}

extension SnackBarMessages on BuildContext {
  void showMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  void showFailure(Failure failure) => showMessage(failure.message);

  /// Awaits a command that returns a [Failure] (or null) and shows it.
  Future<void> reportFailure(Future<Failure?> command) async {
    final failure = await command;
    if (failure != null && mounted) showFailure(failure);
  }
}
