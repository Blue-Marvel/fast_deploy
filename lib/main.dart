import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_shell.dart';
import 'services/credentials_store.dart';
import 'services/deploy_controller.dart';
import 'services/deploy_orchestrator.dart';
import 'services/project_repository.dart';
import 'services/script_runner.dart';
import 'services/workflow_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final projects = ProjectRepository(prefs);
  final credentials = CredentialsStore(prefs);
  final runner = ScriptRunner();
  // Extract bundled scripts to disk eagerly so the first deploy doesn't pay
  // for it. Best-effort — failures here surface again on first run.
  unawaited(runner.ensureReady());

  final orchestrator = DeployOrchestrator(runner);
  final controller = DeployController(
    projects: projects,
    credentials: credentials,
    runner: runner,
    orchestrator: orchestrator,
  );
  final themeController = ThemeController(prefs);

  runApp(
    FastDeployApp(
      controller: controller,
      themeController: themeController,
      workflows: WorkflowService(),
    ),
  );
}

void unawaited(Future<void> _) {}

class FastDeployApp extends StatelessWidget {
  const FastDeployApp({
    super.key,
    required this.controller,
    required this.themeController,
    required this.workflows,
  });

  final DeployController controller;
  final ThemeController themeController;
  final WorkflowService workflows;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider.value(value: themeController),
        Provider.value(value: workflows),
      ],
      child: AnimatedBuilder(
        animation: themeController,
        builder: (_, _) => MaterialApp(
          title: 'Fast Deploy',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.mode,
          debugShowCheckedModeBanner: false,
          home: const HomeShell(),
        ),
      ),
    );
  }
}
