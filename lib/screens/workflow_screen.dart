import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../services/workflow_service.dart';

/// Pick a bundled workflow YAML to install into a project's
/// .github/workflows/ directory, or upload a custom YAML.
class WorkflowScreen extends StatefulWidget {
  const WorkflowScreen({super.key, required this.project});
  final Project project;

  @override
  State<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends State<WorkflowScreen> {
  List<String> _installed = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final svc = context.read<WorkflowService>();
    final installed = await svc.listInstalled(widget.project.path);
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<WorkflowService>();

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _Header(
                  installedCount: _installed.length,
                  workflowsDir:
                      p.join(widget.project.path, '.github', 'workflows'),
                  onUpload: _uploadCustom,
                ),
                const SizedBox(height: 24),
                Text('Bundled workflows',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Drop one of these into your project to ship the same '
                  'pipeline from CI as you would from this app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 16),
                for (final wf in WorkflowService.bundled)
                  _BundledTile(
                    wf: wf,
                    installed: _installed.contains(wf.filename),
                    onInstall: () => _install(svc, wf),
                  ),
              ],
            ),
    );
  }

  Future<void> _install(WorkflowService svc, BundledWorkflow wf) async {
    final yaml = await svc.readBundled(wf.filename);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Install ${wf.label}?'),
        content: SizedBox(
          width: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(wf.description),
              const SizedBox(height: 12),
              Text(
                  'Will write to .github/workflows/${wf.filename}. '
                  'Existing file with the same name will be overwritten.',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Install')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final out = await svc.install(
      projectRoot: widget.project.path,
      filename: wf.filename,
      yaml: yaml,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Wrote $out')),
    );
    await _refresh();
  }

  Future<void> _uploadCustom() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select a workflow YAML',
      type: FileType.custom,
      allowedExtensions: ['yml', 'yaml'],
    );
    final file = picked?.files.single.path;
    if (file == null || !mounted) return;
    final body = await File(file).readAsString();
    final filename = p.basename(file);
    if (!mounted) return;
    final out = await context.read<WorkflowService>().install(
          projectRoot: widget.project.path,
          filename: filename,
          yaml: body,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Wrote $out')),
    );
    await _refresh();
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.installedCount,
    required this.workflowsDir,
    required this.onUpload,
  });

  final int installedCount;
  final String workflowsDir;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.code, color: theme.colorScheme.primary, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GitHub Actions', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '$installedCount file(s) currently in $workflowsDir',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload custom YAML'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BundledTile extends StatelessWidget {
  const _BundledTile({
    required this.wf,
    required this.installed,
    required this.onInstall,
  });

  final BundledWorkflow wf;
  final bool installed;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(wf.label, style: theme.textTheme.titleSmall),
                      const SizedBox(width: 8),
                      if (installed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Installed',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                              )),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(wf.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      )),
                  const SizedBox(height: 4),
                  Text('.github/workflows/${wf.filename}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                      )),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: onInstall,
              child: Text(installed ? 'Reinstall' : 'Install'),
            ),
          ],
        ),
      ),
    );
  }
}
