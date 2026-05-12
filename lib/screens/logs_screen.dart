import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/log_entry.dart';
import '../services/deploy_controller.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({
    super.key,
    this.projectId,
    this.title = 'Logs',
    this.showAppBar = true,
  });

  final String? projectId;
  final String title;
  final bool showAppBar;

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  RunRecord? _selected;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeployController>();
    final history = controller.history
        .where(
          (run) =>
              widget.projectId == null || run.project.id == widget.projectId,
        )
        .toList(growable: false);
    final selected = history.contains(_selected)
        ? _selected
        : (history.isEmpty ? null : history.first);

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: Text(widget.title)) : null,
      body: history.isEmpty
          ? Center(
              child: Text(
                widget.projectId == null
                    ? 'No runs yet — kick off a deploy from a project.'
                    : 'No runs yet for this project.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : Row(
              children: [
                SizedBox(
                  width: 320,
                  child: _RunList(
                    runs: history,
                    selectedId: selected?.handle.id,
                    onSelect: (r) => setState(() => _selected = r),
                  ),
                ),
                const VerticalDivider(width: 1),
                if (selected != null)
                  Expanded(child: _LogViewer(record: selected))
                else
                  const Expanded(child: Center(child: Text('Select a run'))),
              ],
            ),
    );
  }
}

class _RunList extends StatelessWidget {
  const _RunList({
    required this.runs,
    required this.selectedId,
    required this.onSelect,
  });

  final List<RunRecord> runs;
  final String? selectedId;
  final ValueChanged<RunRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM d, HH:mm:ss');
    return ListView.builder(
      itemCount: runs.length,
      itemBuilder: (_, i) {
        final r = runs[i];
        final selected = r.handle.id == selectedId;
        final color = r.isRunning
            ? theme.colorScheme.primary
            : (r.succeeded
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.error);
        final icon = r.isRunning
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                r.succeeded ? Icons.check_circle : Icons.error,
                color: color,
                size: 18,
              );
        return ListTile(
          selected: selected,
          leading: icon,
          title: Text(
            r.handle.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${r.project.name} • ${fmt.format(r.handle.startedAt)}',
            style: theme.textTheme.bodySmall,
          ),
          onTap: () => onSelect(r),
        );
      },
    );
  }
}

class _LogViewer extends StatefulWidget {
  const _LogViewer({required this.record});
  final RunRecord record;

  @override
  State<_LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<_LogViewer> {
  final _scroll = ScrollController();
  StreamSubscription<LogEntry>? _sub;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _LogViewer old) {
    super.didUpdateWidget(old);
    if (old.record.handle.id != widget.record.handle.id) {
      _sub?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    if (widget.record.isRunning) {
      _sub = widget.record.liveEntries.listen((_) {
        if (mounted) {
          setState(() {});
          _maybeScroll();
        }
      });
    }
  }

  void _maybeScroll() {
    if (!_autoScroll || !_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.handle.label, style: theme.textTheme.titleMedium),
                    Text(
                      '${r.project.name}  •  ${r.entries.length} lines'
                      '${r.exitCode != null ? "  •  exit ${r.exitCode}" : ""}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
                icon: Icon(
                  _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
                ),
              ),
              IconButton(
                tooltip: 'Copy all',
                onPressed: () {
                  final all = r.entries.map((e) => e.message).join('\n');
                  Clipboard.setData(ClipboardData(text: all));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Logs copied')));
                },
                icon: const Icon(Icons.copy_all),
              ),
              if (r.isRunning)
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: r.handle.cancel,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: theme.colorScheme.surfaceContainerLowest,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: r.entries.length,
              itemBuilder: (_, i) => _LogLine(entry: r.entries[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry});
  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (entry.level) {
      LogLevel.error => theme.colorScheme.error,
      LogLevel.stderr => theme.colorScheme.error.withValues(alpha: 0.85),
      LogLevel.warn => Colors.orange,
      LogLevel.success => Colors.green.shade600,
      LogLevel.info => theme.colorScheme.primary,
      LogLevel.stdout => theme.colorScheme.onSurface,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText(
        entry.message,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          color: color,
          height: 1.35,
        ),
      ),
    );
  }
}
