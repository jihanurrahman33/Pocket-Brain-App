# Responsive design

Layouts adapt to **Material 3 window size classes** computed from the
available width (`lib/core/responsive/window_size.dart`):

| Class | Width | Typical device |
|---|---|---|
| compact | < 600 | phones (portrait) |
| medium | 600–839 | large phones, small tablets |
| expanded | 840–1199 | tablets, small desktop windows |
| large | ≥ 1200 | desktop |

```dart
if (context.windowSize.hasTwoPanes) { ... }
final padding = context.responsive(compact: 16.0, medium: 24.0, large: 32.0);
```

## Navigation (`app/router/app_shell.dart`)

| Class | Navigation |
|---|---|
| compact | Bottom `NavigationBar` |
| medium, expanded | `NavigationRail` with labels |
| large | Extended `NavigationRail` with app name |

## Building blocks (`core/responsive/responsive_layouts.dart`)

| Widget | Behaviour |
|---|---|
| `ResponsiveCenter` | Caps width (default 760 px for readable text) and centres |
| `ResponsiveListView` | Scrolling page body with window-aware padding |
| `AdaptiveTwoPane` | `primary` + `secondary` side by side on expanded/large; stacked on smaller windows. `footer` ends the primary pane, or the page when stacked (e.g. Save buttons) |
| `showAdaptiveFormDialog` | Full-screen page on compact, centred dialog elsewhere |

## Per-screen layouts

| Screen | Compact | Expanded / large |
|---|---|---|
| Home | One column | Main (ask, recent) + side (digest, tasks, collections, recall) |
| Brain | Collections strip + filter chips | Side navigation pane with filters, categories, collections |
| Capture review | Stacked | Suggestions + side (tasks, related, original) |
| Ask | Chat; history in a drawer | Large: permanent history pane |
| Search | Filter chips row | Filters side panel |
| Memory detail | Stacked | Content + side (collection, tasks, related) |
| Tasks | Stacked | Open tasks + completed column |
| Digest, Settings | Stacked | Two panes |

Grids use `SliverGridDelegateWithMaxCrossAxisExtent`, so column count grows
with width automatically.

## Rules

- Use `AppSpacing` tokens; never hard-code paddings.
- Text in rows must be `Expanded`/`Flexible` with `overflow` set.
- Prefer `Wrap` for chip and button rows so they reflow on narrow screens.
- Don't nest `Expanded` inside `Wrap` or unbounded rows.

## Verification

`test/responsive/responsive_layout_test.dart` renders every route at 320,
390, 800, 1024 and 1440 px wide and fails on any overflow or layout
exception. Add new routes there.
