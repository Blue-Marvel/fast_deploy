import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/credentials.dart';
import '../models/deploy_config.dart';
import '../models/log_entry.dart';
import '../models/project.dart';
import 'credentials_store.dart';
import 'deploy_orchestrator.dart';
import 'project_repository.dart';
import 'script_runner.dart';

/// App-wide state holder. Listens for project mutations and broadcasts the
/// active run so the Logs screen can subscribe live.
class DeployController extends ChangeNotifier {
  DeployController({
    required ProjectRepository projects,
    required CredentialsStore credentials,
    required ScriptRunner runner,
    required DeployOrchestrator orchestrator,
  }) : _projects = projects,
       _credentials = credentials,
       _runner = runner,
       _orchestrator = orchestrator {
    _items = _projects.load();
  }

  final ProjectRepository _projects;
  final CredentialsStore _credentials;
  final ScriptRunner _runner;
  final DeployOrchestrator _orchestrator;

  late List<Project> _items;
  List<Project> get projects => List.unmodifiable(_items);

  /// All runs in the current session (newest first). Cleared on app restart.
  final List<RunRecord> _history = [];
  List<RunRecord> get history => List.unmodifiable(_history);

  RunRecord? _active;
  RunRecord? get activeRun => _active;
  List<RunRecord> get activeRuns =>
      List.unmodifiable(_history.where((run) => run.isRunning));

  ScriptRunner get runner => _runner;

  // ── Projects ──────────────────────────────────────────────────────────

  Future<void> addProject(Project p) async {
    _items = [..._items, p];
    await _projects.save(_items);
    notifyListeners();
  }

  Future<void> updateProject(Project p) async {
    _items = _items.map((e) => e.id == p.id ? p : e).toList();
    await _projects.save(_items);
    notifyListeners();
  }

  Future<void> removeProject(String id) async {
    _items = _items.where((p) => p.id != id).toList();
    await _projects.save(_items);
    await _credentials.deleteAll(id);
    notifyListeners();
  }

  Credentials loadCredentials(String projectId) => _credentials.load(projectId);

  Future<void> saveCredentials(String projectId, Credentials c) =>
      _credentials.save(projectId, c);

  // ── Deploys ───────────────────────────────────────────────────────────

  /// Kick off a deploy. Returns one [RunRecord] per platform step.
  ///
  /// When the config targets both platforms, Android and iOS are started as
  /// independent concurrent jobs so the UI can track them separately.
  Future<List<RunRecord>> startDeploy({
    required Project project,
    required DeployConfig config,
  }) async {
    final creds = _credentials.load(project.id);
    final handles = await _orchestrator.runAll(
      project: project,
      credentials: creds,
      config: config,
    );
    final records = [
      for (final handle in handles)
        RunRecord(handle: handle, project: project, config: config),
    ];
    for (final record in records) {
      _watchRecord(record);
    }
    _history.insertAll(0, records);
    _active = records.isEmpty ? null : records.first;
    notifyListeners();

    return records;
  }

  void _watchRecord(RunRecord record) {
    final handle = record.handle;
    var entriesDone = false;
    var exitDone = false;
    var exitCode = 1;

    void finishIfComplete() {
      if (!entriesDone || !exitDone || !record.isRunning) return;
      record._finish(exitCode);
      _active = null;
      for (final run in _history) {
        if (run.isRunning) {
          _active = run;
          break;
        }
      }
      notifyListeners();
    }

    handle.entries.listen(
      record._appendEntry,
      onError: (Object error, StackTrace stackTrace) {
        record._appendEntry(
          LogEntry(level: LogLevel.error, message: 'Log stream failed: $error'),
        );
      },
      onDone: () {
        entriesDone = true;
        finishIfComplete();
      },
    );
    handle.exitCode.then((code) {
      exitCode = code;
      exitDone = true;
      finishIfComplete();
    });
  }
}

/// Snapshot of one run, including a buffer of every log line it produced.
class RunRecord {
  RunRecord({
    required this.handle,
    required this.project,
    required this.config,
  });

  final RunHandle handle;
  final Project project;
  final DeployConfig config;

  final List<LogEntry> entries = [];
  int? exitCode;
  DateTime? finishedAt;

  bool get isRunning => exitCode == null;
  bool get succeeded => exitCode == 0;

  final StreamController<LogEntry> _local =
      StreamController<LogEntry>.broadcast();

  /// Stream a UI can subscribe to and receive future entries. Past entries
  /// are NOT replayed here — read [entries] for that and concatenate.
  Stream<LogEntry> get liveEntries => _local.stream;

  void _appendEntry(LogEntry e) {
    entries.add(e);
    if (!_local.isClosed) _local.add(e);
  }

  void _finish(int code) {
    exitCode = code;
    finishedAt = DateTime.now();
    if (!_local.isClosed) _local.close();
  }
}
