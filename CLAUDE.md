See [AGENTS.md](AGENTS.md) for project instructions, architecture rules and
conventions.

## Proactive Flutter hot reload

<!-- From the official Flutter agent rules:
     https://github.com/flutter/agent-plugins/blob/main/rules/flutter-hot-reload.md
     Requires the dart-flutter Claude Code plugin (see docs/development.md). -->

Whenever you edit or modify any `.dart` file under `lib/` in this project:

1. **When to skip**
   - **Files outside `lib/`**: only trigger hot reload or hot restart for edits
     under `lib/`. Do not trigger when modifying files in other directories
     (e.g. `test/**`, `integration_test/**`, `benchmark/**`, `test_driver/**`
     or `example/**`).
   - **Comments and documentation**: do not trigger hot reload or hot restart
     when changes only affect comments, docstrings or whitespace.
2. **Discover and connect**: discover running app instances with the `dtd`
   MCP tool (or `list_running_apps` / `vm_service`) from the Dart MCP server.
3. **Trigger hot reload / hot restart**
   - Run the `hot_reload` MCP tool right after changing UI widgets (including
     `build` methods of stateful widgets) or simple methods.
   - Run the `hot_restart` MCP tool if fundamental logic, state initialisation
     (e.g. `initState`), global/static state, `main()` or dependency injection
     (`lib/app/di/injection.dart`) was modified.
