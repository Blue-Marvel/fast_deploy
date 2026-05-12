import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../services/deploy_controller.dart';
import 'project_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeployController>();
    final projects = controller.projects;
    final activeCount = controller.activeRuns.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          FilledButton.icon(
            onPressed: () => _addProject(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Flutter project'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: projects.isEmpty
          ? _EmptyState(onAdd: () => _addProject(context))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DashboardHeader(
                    projectCount: projects.length,
                    activeCount: activeCount,
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView.separated(
                      itemBuilder: (_, i) {
                        final project = projects[i];
                        final runs = controller.history.where(
                          (run) => run.project.id == project.id,
                        );
                        final activeRuns = runs
                            .where((run) => run.isRunning)
                            .length;
                        return _ProjectCard(
                          project: project,
                          runCount: runs.length,
                          activeRunCount: activeRuns,
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemCount: projects.length,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _addProject(BuildContext context) async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Flutter project root (the folder with pubspec.yaml)',
    );
    if (selected == null) return;
    if (!context.mounted) return;

    final pubspec = File(p.join(selected, 'pubspec.yaml'));
    if (!await pubspec.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No pubspec.yaml at $selected')));
      return;
    }
    if (!context.mounted) return;

    final name = p.basename(selected);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await context.read<DeployController>().addProject(
      Project(id: id, name: name, path: selected),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.projectCount,
    required this.activeCount,
  });

  final int projectCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.rocket_launch,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flutter deploy projects',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$projectCount project(s) tracked • $activeCount active job(s)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.runCount,
    required this.activeRunCount,
  });

  final Project project;
  final int runCount;
  final int activeRunCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(projectId: project.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.folder_open,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      project.path,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (project.appIdentifier != null &&
                            project.appIdentifier!.isNotEmpty)
                          _Chip(
                            icon: Icons.ios_share,
                            label: project.appIdentifier!,
                          ),
                        _Chip(
                          icon: Icons.flutter_dash,
                          label: 'Flutter ${project.flutterVersion}',
                        ),
                        _Chip(
                          icon: activeRunCount > 0 ? Icons.sync : Icons.history,
                          label: activeRunCount > 0
                              ? '$activeRunCount running'
                              : '$runCount run(s)',
                          emphasized: activeRunCount > 0,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(projectId: project.id),
                  ),
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open'),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Remove project?'),
                      content: Text(
                        'This removes "${project.name}" from the app and '
                        'deletes its stored credentials. The project files '
                        'on disk are untouched.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<DeployController>().removeProject(
                      project.id,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = emphasized
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = emphasized
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rocket_launch_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('No projects yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: 420,
            child: Text(
              'Add a Flutter project folder to start shipping releases and '
              'Shorebird patches without GitHub Actions.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Flutter project'),
          ),
        ],
      ),
    );
  }
}
