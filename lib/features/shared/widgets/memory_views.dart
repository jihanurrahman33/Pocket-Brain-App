import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/memory.dart';
import 'memory_source_icon.dart';

/// Navigates to a memory's detail screen.
void openMemory(BuildContext context, String id) => context.push(AppRoutes.memory(id));

/// A compact memory row used across lists.
class MemoryTile extends StatelessWidget {
  const MemoryTile({super.key, required this.memory, this.snippet});

  final Memory memory;

  /// Replaces the preview line, e.g. with a search excerpt.
  final String? snippet;

  static const _avatarRadius = 18.0;
  static const _iconSize = 18.0;
  static const _favoriteSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openMemory(context, memory.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + AppSpacing.xxs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: _avatarRadius,
                backgroundColor: scheme.secondaryContainer,
                child: Icon(
                  memory.source.icon,
                  size: _iconSize,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            memory.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (memory.isFavorite)
                          Icon(Icons.star_rounded, size: _favoriteSize, color: scheme.primary),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      snippet ?? memory.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${memory.category} · ${Formatters.friendlyDate(memory.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A grid card variant of [MemoryTile].
class MemoryCard extends StatelessWidget {
  const MemoryCard({super.key, required this.memory});

  final Memory memory;

  static const _iconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openMemory(context, memory.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + AppSpacing.xxs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(memory.source.icon, size: _iconSize, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      memory.category,
                      style: theme.textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (memory.isFavorite)
                    Icon(Icons.star_rounded, size: _iconSize, color: scheme.primary),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                memory.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Text(
                  memory.preview,
                  overflow: TextOverflow.fade,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Text(
                Formatters.friendlyDate(memory.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A vertical list of [MemoryTile]s with consistent spacing.
class MemoryTileList extends StatelessWidget {
  const MemoryTileList({super.key, required this.memories});

  final List<Memory> memories;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final m in memories)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: MemoryTile(memory: m),
        ),
    ],
  );
}
