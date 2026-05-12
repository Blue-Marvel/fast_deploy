import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deploy_config.dart';
import '../models/project.dart';
import '../services/deploy_controller.dart';
import 'credentials_screen.dart';
import 'logs_screen.dart';
import 'workflow_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  DeployPlatform _platform = DeployPlatform.android;
  DeployAction _action = DeployAction.release;
  PlayTrack _track = PlayTrack.internal;
  String? _selectedFlavor;
  String? _selectedTarget;
  bool _skipUpload = false;
  bool _launching = false;
  late final TabController _tabController;
  final _releaseVersionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPreflight());
  }

  Future<void> _runPreflight() async {
    final controller = context.read<DeployController>();
    final project = _findProject(controller);
    if (project == null) return;

    final results = await controller.runner.preflight(project.path);
    final flavors =
        results['flavors']?.split(',').where((s) => s.isNotEmpty).toList() ??
        const [];
    final targets =
        results['targets']?.split(',').where((s) => s.isNotEmpty).toList() ??
        const [];

    if (flavors.isNotEmpty || targets.isNotEmpty) {
      final updated = project.copyWith(flavors: flavors, targets: targets);
      await controller.updateProject(updated);
      setState(() {
        if (flavors.isNotEmpty) _selectedFlavor = flavors.first;
        if (targets.isNotEmpty) _selectedTarget = targets.first;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _releaseVersionController.dispose();
    super.dispose();
  }

  Project? _findProject(DeployController c) {
    for (final p in c.projects) {
      if (p.id == widget.projectId) return p;
    }
    return null;
  }

  void _setPlatform(DeployPlatform platform) {
    setState(() {
      _platform = platform;
      if (platform != DeployPlatform.ios &&
          _action == DeployAction.buildAndOpenXcode) {
        _action = DeployAction.buildNoShorebird;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeployController>();
    final project = _findProject(controller);
    if (project == null) {
      return const Scaffold(body: Center(child: Text('Project not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.tune), text: 'Deploy'),
            Tab(icon: Icon(Icons.vpn_key_outlined), text: 'Keys'),
            Tab(icon: Icon(Icons.terminal_outlined), text: 'Logs'),
            Tab(icon: Icon(Icons.code), text: 'Workflows'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DeployTab(
            project: project,
            platform: _platform,
            action: _action,
            track: _track,
            flavor: _selectedFlavor,
            target: _selectedTarget,
            skipUpload: _skipUpload,
            launching: _launching,
            releaseVersionController: _releaseVersionController,
            onPlatform: _setPlatform,
            onAction: (v) => setState(() => _action = v),
            onTrack: (v) => setState(() => _track = v),
            onFlavor: (v) => setState(() => _selectedFlavor = v),
            onTarget: (v) => setState(() => _selectedTarget = v),
            onSkipUpload: (v) => setState(() => _skipUpload = v),
            onLaunch: () => _launch(project),
          ),
          CredentialsScreen(projectId: project.id),
          LogsScreen(
            projectId: project.id,
            title: '${project.name} logs',
            showAppBar: false,
          ),
          WorkflowScreen(project: project),
        ],
      ),
    );
  }

  Future<void> _launch(Project project) async {
    if (_launching) return;
    final config = DeployConfig(
      platform: _platform,
      action: _action,
      playTrack: _track,
      flavor: _selectedFlavor,
      target: _selectedTarget,
      skipUpload: _skipUpload,
      releaseVersion: _releaseVersionController.text.trim().isEmpty
          ? null
          : _releaseVersionController.text.trim(),
    );
    setState(() => _launching = true);
    try {
      final records = await context.read<DeployController>().startDeploy(
        project: project,
        config: config,
      );
      if (!mounted) return;
      setState(() => _launching = false);
      _tabController.animateTo(2);
      final jobText = records.length == 1 ? 'job has' : 'jobs have';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Build started: ${records.length} $jobText started.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _launching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start build: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _DeployTab extends StatelessWidget {
  const _DeployTab({
    required this.project,
    required this.platform,
    required this.action,
    required this.track,
    required this.flavor,
    required this.target,
    required this.skipUpload,
    required this.launching,
    required this.releaseVersionController,
    required this.onPlatform,
    required this.onAction,
    required this.onTrack,
    required this.onFlavor,
    required this.onTarget,
    required this.onSkipUpload,
    required this.onLaunch,
  });

  final Project project;
  final DeployPlatform platform;
  final DeployAction action;
  final PlayTrack track;
  final String? flavor;
  final String? target;
  final bool skipUpload;
  final bool launching;
  final TextEditingController releaseVersionController;
  final ValueChanged<DeployPlatform> onPlatform;
  final ValueChanged<DeployAction> onAction;
  final ValueChanged<PlayTrack> onTrack;
  final ValueChanged<String?> onFlavor;
  final ValueChanged<String?> onTarget;
  final ValueChanged<bool> onSkipUpload;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Section(
          title: 'Platform',
          child: SegmentedButton<DeployPlatform>(
            segments: const [
              ButtonSegment(
                value: DeployPlatform.android,
                icon: Icon(Icons.android),
                label: Text('Android'),
              ),
              ButtonSegment(
                value: DeployPlatform.ios,
                icon: Icon(Icons.phone_iphone),
                label: Text('iOS'),
              ),
              ButtonSegment(
                value: DeployPlatform.both,
                icon: Icon(Icons.devices),
                label: Text('Both'),
              ),
            ],
            selected: {platform},
            onSelectionChanged: (s) => onPlatform(s.first),
          ),
        ),
        if (project.flavors.isNotEmpty)
          _Section(
            title: 'Flavor',
            subtitle: 'Choose which build flavor to use.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in project.flavors)
                  ChoiceChip(
                    label: Text(f),
                    selected: flavor == f,
                    onSelected: (selected) => onFlavor(selected ? f : null),
                  ),
              ],
            ),
          ),
        if (project.targets.isNotEmpty)
          _Section(
            title: 'Entry Point (Target)',
            subtitle: 'Select the main entry file (e.g. lib/main_dev.dart).',
            child: DropdownButtonFormField<String>(
              value: target,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final t in project.targets)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: onTarget,
            ),
          ),
        _Section(
          title: 'Action',
          subtitle:
              'Release builds via Shorebird and ships to the store. Patch is '
              'a Dart-only OTA update for an existing release. Build (No Shorebird) '
              'is a plain flutter build with no upload. Release (No Shorebird) is '
              'a plain flutter build that uploads to TestFlight / Play Console.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in DeployAction.values)
                if (a != DeployAction.buildAndOpenXcode ||
                    platform == DeployPlatform.ios)
                  ChoiceChip(
                    label: Text(_actionLabel(a)),
                    selected: action == a,
                    onSelected: (_) => onAction(a),
                  ),
            ],
          ),
        ),
        if ((action == DeployAction.release ||
                action == DeployAction.releaseNoShorebird) &&
            (platform == DeployPlatform.android ||
                platform == DeployPlatform.both))
          _Section(
            title: 'Play Console track',
            child: SegmentedButton<PlayTrack>(
              segments: const [
                ButtonSegment(
                  value: PlayTrack.internal,
                  label: Text('Internal'),
                ),
                ButtonSegment(value: PlayTrack.alpha, label: Text('Alpha')),
                ButtonSegment(value: PlayTrack.beta, label: Text('Beta')),
                ButtonSegment(
                  value: PlayTrack.production,
                  label: Text('Production'),
                ),
              ],
              selected: {track},
              onSelectionChanged: (s) => onTrack(s.first),
            ),
          ),
        if (action == DeployAction.release ||
            action == DeployAction.releaseNoShorebird)
          _Section(
            title: 'Skip upload',
            subtitle:
                'Build the AAB / IPA but don\'t push to the store. Useful for '
                'testing locally before a real ship.',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Build only, leave artifacts on disk'),
              value: skipUpload,
              onChanged: onSkipUpload,
            ),
          ),
        if (action == DeployAction.patch)
          _Section(
            title: 'Release to patch (optional)',
            subtitle:
                'Defaults to "latest". Set explicitly to patch an older release '
                '(e.g. 2.0.11+12).',
            child: TextField(
              controller: releaseVersionController,
              decoration: const InputDecoration(hintText: 'latest'),
            ),
          ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: launching ? null : onLaunch,
            icon: launching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(launching ? 'Starting...' : _launchLabel()),
          ),
        ),
      ],
    );
  }

  String _launchLabel() {
    return switch (action) {
      DeployAction.release => 'Run release',
      DeployAction.patch => 'Ship patch',
      DeployAction.buildNoShorebird => 'Build artifacts',
      DeployAction.releaseNoShorebird =>
        skipUpload ? 'Build artifacts' : 'Run release',
      DeployAction.buildAndOpenXcode => 'Build & open Xcode',
    };
  }

  String _actionLabel(DeployAction a) {
    return switch (a) {
      DeployAction.release => 'Release (Shorebird + store)',
      DeployAction.patch => 'Shorebird patch',
      DeployAction.buildNoShorebird => 'Build (No Shorebird)',
      DeployAction.releaseNoShorebird => 'Release (No Shorebird, store)',
      DeployAction.buildAndOpenXcode => 'Build IPA + open Xcode',
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
