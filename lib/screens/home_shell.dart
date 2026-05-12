import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/deploy_controller.dart';
import '../theme/theme_controller.dart';
import 'dashboard_screen.dart';
import 'logs_screen.dart';

/// Top-level frame: side rail + body. The Dashboard is the project list and
/// drives navigation into per-project Detail/Credentials/Workflow tabs. The
/// Logs tab is global (shows the active and historical runs).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = const [DashboardScreen(), LogsScreen()];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 200,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.rocket_launch,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Fast Deploy',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v0.1',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            trailing: const _RailFooter(),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Projects'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.terminal_outlined),
                selectedIcon: Icon(Icons.terminal),
                label: Text('Logs'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}

class _RailFooter extends StatelessWidget {
  const _RailFooter();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final running = context.watch<DeployController>().activeRun;
    final icon = switch (theme.mode) {
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
      ThemeMode.system => Icons.brightness_auto,
    };
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (running != null) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 12),
              ],
              IconButton.filledTonal(
                tooltip: 'Toggle theme',
                onPressed: theme.toggle,
                icon: Icon(icon),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
