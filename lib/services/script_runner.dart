import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/log_entry.dart';

/// Extracts the app's bundled shell scripts to a working directory on disk
/// and runs them with the right env. Stdout/stderr are streamed back as
/// [LogEntry]s.
///
/// Why on-disk: `bash` can't read Flutter assets directly — it needs a real
/// file. Why every launch: it's cheap, and if we ship a script update with a
/// new app build the user gets it without us tracking versions.
class ScriptRunner {
  ScriptRunner({
    this.scriptAssetNames = const [
      '_common.sh',
      'release-android.sh',
      'release-ios.sh',
      'patch-android.sh',
      'patch-ios.sh',
      'build-android.sh',
      'build-ios.sh',
      'setup-ios-signing.sh',
      'create-ios-signing.sh',
      'diagnose-ios-signing.sh',
      'preflight.sh',
    ],
  });

  final List<String> scriptAssetNames;

  Directory? _scriptsDir;
  Future<Directory>? _readyFuture;
  int _runCounter = 0;

  /// Idempotent. First call extracts assets; later calls return the cached
  /// directory. Any caller that runs a script awaits this implicitly.
  Future<Directory> ensureReady() {
    return _readyFuture ??= _extract();
  }

  Future<Directory> _extract() async {
    final support = await getApplicationSupportDirectory();
    final scriptsDir = Directory(p.join(support.path, 'scripts'));
    if (!await scriptsDir.exists()) {
      await scriptsDir.create(recursive: true);
    }
    for (final name in scriptAssetNames) {
      final data = await rootBundle.loadString('assets/scripts/$name');
      final file = File(p.join(scriptsDir.path, name));
      await file.writeAsString(data);
      // chmod +x — bash needs execute even when invoked via `bash <path>`
      // because some scripts source siblings (`source _common.sh`). Easier
      // to just make every .sh executable.
      await Process.run('chmod', ['+x', file.path]);
    }
    _scriptsDir = scriptsDir;
    return scriptsDir;
  }

  /// Path to a specific bundled script after extraction.
  Future<String> scriptPath(String name) async {
    final dir = await ensureReady();
    return p.join(dir.path, name);
  }

  /// Run a bundled script.
  ///
  /// [scriptName]: filename inside `assets/scripts/`, e.g. `release-ios.sh`.
  /// [projectRoot]: target Flutter project; passed as `PROJECT_ROOT` env and
  /// also as the spawned process's cwd.
  /// [env]: extra env (typically [Credentials.toEnv()] + per-job overrides).
  /// [args]: positional args to the script (e.g. `--no-upload`).
  /// [label]: human-readable name shown in the logs UI.
  Future<RunHandle> run({
    required String scriptName,
    required String projectRoot,
    required Map<String, String> env,
    List<String> args = const [],
    String? label,
  }) async {
    final scriptFile = await scriptPath(scriptName);

    final controller = StreamController<LogEntry>();
    final exitCompleter = Completer<int>();
    final runId = '${DateTime.now().millisecondsSinceEpoch}-${_runCounter++}';

    // Build env: inherit current process env, then layer ours on top, then
    // explicit fields for things the scripts always read.
    final mergedEnv = <String, String>{
      ...Platform.environment,
      ..._extraPath(),
      ...env,
      'PROJECT_ROOT': projectRoot,
      // Fastlane/Ruby need these for UTF-8 and proper gem loading
      'LANG': 'en_US.UTF-8',
      'LC_ALL': 'en_US.UTF-8',
      // Force unbuffered output so we get logs in real time, not in chunks.
      'PYTHONUNBUFFERED': '1',
      'STDBUF': 'L',
    };

    // If the GUI app inherited a GEM_HOME or GEM_PATH from a different Ruby version,
    // it will break fastlane. Better to let fastlane/homebrew find their own.
    mergedEnv.remove('GEM_HOME');
    mergedEnv.remove('GEM_PATH');

    controller.add(
      LogEntry(
        level: LogLevel.info,
        message: '\$ $scriptName ${args.join(' ')}',
      ),
    );
    controller.add(
      LogEntry(level: LogLevel.info, message: 'cwd: $projectRoot'),
    );

    Process? process;
    try {
      process = await Process.start(
        '/bin/bash',
        [scriptFile, ...args],
        workingDirectory: projectRoot,
        environment: mergedEnv,
        // Don't inherit stdio — we capture and forward.
        runInShell: false,
      );
    } catch (e) {
      controller.add(
        LogEntry(level: LogLevel.error, message: 'Failed to spawn: $e'),
      );
      exitCompleter.complete(127);
      unawaited(controller.close());
      return RunHandle(
        id: runId,
        label: label ?? scriptName,
        entries: controller.stream,
        exitCode: exitCompleter.future,
        startedAt: DateTime.now(),
        cancel: () {},
      );
    }

    final stdoutSub = process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
          controller.add(LogEntry(level: LogLevel.stdout, message: line));
        });

    final stderrSub = process.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
          controller.add(LogEntry(level: LogLevel.stderr, message: line));
        });

    process.exitCode.then((code) async {
      await stdoutSub.cancel();
      await stderrSub.cancel();
      controller.add(
        LogEntry(
          level: code == 0 ? LogLevel.success : LogLevel.error,
          message: code == 0
              ? '✓ $scriptName completed'
              : '✗ $scriptName exited with code $code',
        ),
      );
      exitCompleter.complete(code);
      unawaited(controller.close());
    });

    return RunHandle(
      id: runId,
      label: label ?? scriptName,
      entries: controller.stream,
      exitCode: exitCompleter.future,
      startedAt: DateTime.now(),
      cancel: () => process?.kill(ProcessSignal.sigterm),
    );
  }

  /// Add common Homebrew + asdf + rbenv install paths to PATH so the spawned
  /// shell can find `shorebird`, `fastlane`, etc. even when launched from a
  /// GUI app (which inherits a stripped-down PATH from launchd).
  Map<String, String> _extraPath() {
    final extras = <String>[
      '/opt/homebrew/bin',
      '/opt/homebrew/sbin',
      '/usr/local/bin',
      '/usr/local/sbin',
      '${Platform.environment['HOME']}/.shorebird/bin',
      '${Platform.environment['HOME']}/.fastlane/bin',
      '${Platform.environment['HOME']}/.rbenv/shims',
      '${Platform.environment['HOME']}/.asdf/shims',
      '${Platform.environment['HOME']}/.pub-cache/bin',
    ];
    final existing = Platform.environment['PATH'] ?? '';
    final merged = ([...extras, ...existing.split(':')]).toSet().join(':');
    return {'PATH': merged};
  }

  /// Convenience: run preflight.sh and parse its KEY=value output into a map.
  Future<Map<String, String>> preflight(String projectRoot) async {
    final handle = await run(
      scriptName: 'preflight.sh',
      projectRoot: projectRoot,
      env: const {},
      label: 'Preflight check',
    );
    final result = <String, String>{};
    await for (final entry in handle.entries) {
      if (entry.level == LogLevel.stdout) {
        final eq = entry.message.indexOf('=');
        if (eq > 0) {
          result[entry.message.substring(0, eq)] = entry.message.substring(
            eq + 1,
          );
        }
      }
    }
    await handle.exitCode;
    return result;
  }

  Directory? get scriptsDir => _scriptsDir;
}
