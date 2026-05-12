import 'dart:async';

import '../models/credentials.dart';
import '../models/deploy_config.dart';
import '../models/log_entry.dart';
import '../models/project.dart';
import 'script_runner.dart';

/// Translates a high-level [DeployConfig] into script invocations.
///
/// Multi-platform jobs are returned as separate handles so Android and iOS can
/// run concurrently and be tracked independently in the UI.
class DeployOrchestrator {
  DeployOrchestrator(this._runner);

  final ScriptRunner _runner;

  /// Starts one independent run per planned platform step.
  Future<List<RunHandle>> runAll({
    required Project project,
    required Credentials credentials,
    required DeployConfig config,
  }) async {
    final steps = _planSteps(project, config);
    if (steps.isEmpty) {
      return [_errorHandle(config)];
    }

    return Future.wait(
      steps.map((step) {
        return _runStep(project: project, credentials: credentials, step: step);
      }),
    );
  }

  /// Compatibility helper for callers that want a single merged stream.
  Future<RunHandle> run({
    required Project project,
    required Credentials credentials,
    required DeployConfig config,
  }) async {
    final handles = await runAll(
      project: project,
      credentials: credentials,
      config: config,
    );
    if (handles.length == 1) return handles.single;

    final controller = StreamController<LogEntry>();
    final exitCodes = <Future<int>>[];
    var openStreams = handles.length;
    for (final handle in handles) {
      handle.entries.listen(
        controller.add,
        onError: (Object error, StackTrace stackTrace) {
          controller.add(
            LogEntry(
              level: LogLevel.error,
              message: 'Log stream failed: $error',
            ),
          );
        },
        onDone: () {
          openStreams -= 1;
          if (openStreams == 0) unawaited(controller.close());
        },
      );
      exitCodes.add(handle.exitCode);
    }
    final exitCode = Future.wait(exitCodes).then((codes) {
      int? firstFailure;
      for (final code in codes) {
        if (code != 0) {
          firstFailure = code;
          break;
        }
      }
      return firstFailure ?? 0;
    });
    return RunHandle(
      id: 'deploy-${DateTime.now().millisecondsSinceEpoch}',
      label: _runLabel(config),
      entries: controller.stream,
      exitCode: exitCode,
      startedAt: DateTime.now(),
      cancel: () {
        for (final handle in handles) {
          handle.cancel();
        }
      },
    );
  }

  Future<RunHandle> _runStep({
    required Project project,
    required Credentials credentials,
    required _Step step,
  }) async {
    final controller = StreamController<LogEntry>();
    final exitCompleter = Completer<int>();
    controller.add(
      LogEntry(
        level: LogLevel.info,
        message: '── ${step.label} ─────────────────────────────────',
      ),
    );
    final handle = await _runner.run(
      scriptName: step.script,
      projectRoot: project.path,
      env: {..._projectEnv(project), ...credentials.toEnv(), ...step.extraEnv},
      args: step.args,
      label: step.label,
    );
    handle.entries.listen(
      controller.add,
      onError: (Object error, StackTrace stackTrace) {
        controller.add(
          LogEntry(level: LogLevel.error, message: 'Log stream failed: $error'),
        );
      },
      onDone: () {
        unawaited(controller.close());
      },
    );
    handle.exitCode.then((code) {
      exitCompleter.complete(code);
    });
    return RunHandle(
      id: handle.id,
      label: step.label,
      entries: controller.stream,
      exitCode: exitCompleter.future,
      startedAt: handle.startedAt,
      cancel: handle.cancel,
    );
  }

  RunHandle _errorHandle(DeployConfig config) {
    final controller = StreamController<LogEntry>();
    final exitCode = Completer<int>();
    controller.add(
      LogEntry(
        level: LogLevel.error,
        message:
            'No steps planned for ${config.platform.name}/${config.action.name}',
      ),
    );
    exitCode.complete(2);
    unawaited(controller.close());
    return RunHandle(
      id: 'deploy-error-${DateTime.now().millisecondsSinceEpoch}',
      label: _runLabel(config),
      entries: controller.stream,
      exitCode: exitCode.future,
      startedAt: DateTime.now(),
      cancel: () {},
    );
  }

  Map<String, String> _projectEnv(Project project) {
    final env = <String, String>{'FLUTTER_VERSION': project.flutterVersion};
    if (project.appIdentifier != null && project.appIdentifier!.isNotEmpty) {
      env['APP_IDENTIFIER'] = project.appIdentifier!;
    }
    if (project.packageName != null && project.packageName!.isNotEmpty) {
      env['PACKAGE_NAME'] = project.packageName!;
    }
    return env;
  }

  List<_Step> _planSteps(Project project, DeployConfig c) {
    switch (c.action) {
      case DeployAction.release:
        return _releaseSteps(c);
      case DeployAction.patch:
        return _patchSteps(c);
      case DeployAction.buildNoShorebird:
        return _buildNoShorebirdSteps(c);
      case DeployAction.releaseNoShorebird:
        return _releaseNoShorebirdSteps(c);
      case DeployAction.buildAndOpenXcode:
        if (c.platform != DeployPlatform.ios) return const [];
        return [
          _Step(
            label: 'Build iOS IPA & open Xcode',
            script: 'build-ios.sh',
            args: const ['--open-xcode'],
          ),
        ];
    }
  }

  List<_Step> _releaseSteps(DeployConfig c) {
    final out = <_Step>[];
    if (c.platform == DeployPlatform.android ||
        c.platform == DeployPlatform.both) {
      out.add(
        _Step(
          label: 'Android release',
          script: 'release-android.sh',
          args: c.skipUpload ? const ['--no-upload'] : const [],
          extraEnv: {'PLAY_TRACK': c.playTrack.value},
        ),
      );
    }
    if (c.platform == DeployPlatform.ios || c.platform == DeployPlatform.both) {
      out.add(
        _Step(
          label: 'iOS release',
          script: 'release-ios.sh',
          args: c.skipUpload ? const ['--no-upload'] : const [],
        ),
      );
    }
    return out;
  }

  List<_Step> _patchSteps(DeployConfig c) {
    final out = <_Step>[];
    final extra = <String, String>{
      if (c.releaseVersion != null && c.releaseVersion!.isNotEmpty)
        'RELEASE_VERSION': c.releaseVersion!,
    };
    if (c.platform == DeployPlatform.android ||
        c.platform == DeployPlatform.both) {
      out.add(
        _Step(
          label: 'Android patch',
          script: 'patch-android.sh',
          extraEnv: extra,
        ),
      );
    }
    if (c.platform == DeployPlatform.ios || c.platform == DeployPlatform.both) {
      out.add(
        _Step(label: 'iOS patch', script: 'patch-ios.sh', extraEnv: extra),
      );
    }
    return out;
  }

  List<_Step> _buildNoShorebirdSteps(DeployConfig c) {
    final out = <_Step>[];
    if (c.platform == DeployPlatform.android ||
        c.platform == DeployPlatform.both) {
      out.add(
        _Step(
          label: 'Android build (No Shorebird)',
          script: 'build-android.sh',
        ),
      );
    }
    if (c.platform == DeployPlatform.ios || c.platform == DeployPlatform.both) {
      out.add(_Step(label: 'iOS build (No Shorebird)', script: 'build-ios.sh'));
    }
    return out;
  }

  List<_Step> _releaseNoShorebirdSteps(DeployConfig c) {
    final uploadArgs = c.skipUpload ? const <String>[] : const ['--upload'];
    final out = <_Step>[];
    if (c.platform == DeployPlatform.android ||
        c.platform == DeployPlatform.both) {
      out.add(
        _Step(
          label: 'Android release (No Shorebird)',
          script: 'build-android.sh',
          args: uploadArgs,
          extraEnv: {'PLAY_TRACK': c.playTrack.value},
        ),
      );
    }
    if (c.platform == DeployPlatform.ios || c.platform == DeployPlatform.both) {
      out.add(
        _Step(
          label: 'iOS release (No Shorebird)',
          script: 'build-ios.sh',
          args: uploadArgs,
        ),
      );
    }
    return out;
  }

  String _runLabel(DeployConfig c) {
    final action = switch (c.action) {
      DeployAction.release => 'Release',
      DeployAction.patch => 'Patch',
      DeployAction.buildNoShorebird => 'Build (No Shorebird)',
      DeployAction.releaseNoShorebird => 'Release (No Shorebird)',
      DeployAction.buildAndOpenXcode => 'Build & open Xcode',
    };
    return '$action — ${c.platform.name}';
  }
}

class _Step {
  _Step({
    required this.label,
    required this.script,
    this.args = const [],
    this.extraEnv = const {},
  });

  final String label;
  final String script;
  final List<String> args;
  final Map<String, String> extraEnv;
}
