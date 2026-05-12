import 'dart:async';

import 'package:fast_deploy/models/credentials.dart';
import 'package:fast_deploy/models/deploy_config.dart';
import 'package:fast_deploy/models/log_entry.dart';
import 'package:fast_deploy/models/project.dart';
import 'package:fast_deploy/services/deploy_orchestrator.dart';
import 'package:fast_deploy/services/script_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'replays step and script logs that are emitted before listening',
    () async {
      final runner = _FakeScriptRunner();
      final orchestrator = DeployOrchestrator(runner);

      final handle = await orchestrator.run(
        project: _project(),
        credentials: Credentials(playServiceAccountJsonPath: '/tmp/play.json'),
        config: DeployConfig(
          platform: DeployPlatform.android,
          action: DeployAction.release,
        ),
      );

      final entries = await handle.entries.toList();
      final messages = entries.map((entry) => entry.message).toList();

      expect(await handle.exitCode, 0);
      expect(messages, contains(startsWith('── Android release')));
      expect(messages, contains('fake release-android.sh'));
      expect(runner.calls.single.scriptName, 'release-android.sh');
      expect(runner.calls.single.extraEnv['PLAY_TRACK'], 'internal');
    },
  );

  test('rejects build and open Xcode for non-iOS platforms', () async {
    final runner = _FakeScriptRunner();
    final orchestrator = DeployOrchestrator(runner);

    final handle = await orchestrator.run(
      project: _project(),
      credentials: Credentials(),
      config: DeployConfig(
        platform: DeployPlatform.both,
        action: DeployAction.buildAndOpenXcode,
      ),
    );

    final entries = await handle.entries.toList();

    expect(await handle.exitCode, 2);
    expect(runner.calls, isEmpty);
    expect(entries.single.message, contains('No steps planned'));
  });

  test('starts both platform jobs as separate handles', () async {
    final runner = _FakeScriptRunner();
    final orchestrator = DeployOrchestrator(runner);

    final handles = await orchestrator.runAll(
      project: _project(),
      credentials: Credentials(),
      config: DeployConfig(
        platform: DeployPlatform.both,
        action: DeployAction.buildNoShorebird,
      ),
    );

    expect(handles.map((handle) => handle.label), [
      'Android build (No Shorebird)',
      'iOS build (No Shorebird)',
    ]);
    expect(runner.calls.map((call) => call.scriptName), [
      'build-android.sh',
      'build-ios.sh',
    ]);
  });

  test(
    'keeps the log stream open when exit code completes before logs',
    () async {
      final runner = _LateLogScriptRunner();
      final orchestrator = DeployOrchestrator(runner);

      final handle = await orchestrator.run(
        project: _project(),
        credentials: Credentials(),
        config: DeployConfig(
          platform: DeployPlatform.android,
          action: DeployAction.buildNoShorebird,
        ),
      );

      expect(await handle.exitCode, 0);

      final messages = await handle.entries
          .map((entry) => entry.message)
          .toList();

      expect(messages, contains('late log after exit'));
    },
  );
}

Project _project() {
  return Project(
    id: '1',
    name: 'Example',
    path: '/tmp/example',
    appIdentifier: 'com.example.app',
    packageName: 'com.example.app',
  );
}

class _FakeScriptRunner extends ScriptRunner {
  _FakeScriptRunner() : super(scriptAssetNames: const []);

  final calls = <_RunCall>[];

  @override
  Future<RunHandle> run({
    required String scriptName,
    required String projectRoot,
    required Map<String, String> env,
    List<String> args = const [],
    String? label,
  }) async {
    calls.add(_RunCall(scriptName: scriptName, extraEnv: env));
    final controller = StreamController<LogEntry>();
    controller.add(
      LogEntry(level: LogLevel.stdout, message: 'fake $scriptName'),
    );
    unawaited(controller.close());
    return RunHandle(
      id: scriptName,
      label: label ?? scriptName,
      entries: controller.stream,
      exitCode: Future.value(0),
      startedAt: DateTime(2026),
      cancel: () {},
    );
  }
}

class _RunCall {
  _RunCall({required this.scriptName, required this.extraEnv});

  final String scriptName;
  final Map<String, String> extraEnv;
}

class _LateLogScriptRunner extends ScriptRunner {
  _LateLogScriptRunner() : super(scriptAssetNames: const []);

  @override
  Future<RunHandle> run({
    required String scriptName,
    required String projectRoot,
    required Map<String, String> env,
    List<String> args = const [],
    String? label,
  }) async {
    final controller = StreamController<LogEntry>();
    Future<void>(() async {
      await Future<void>.delayed(Duration.zero);
      controller.add(
        LogEntry(level: LogLevel.stdout, message: 'late log after exit'),
      );
      await controller.close();
    });
    return RunHandle(
      id: scriptName,
      label: label ?? scriptName,
      entries: controller.stream,
      exitCode: Future.value(0),
      startedAt: DateTime(2026),
      cancel: () {},
    );
  }
}
