import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

/// Manages the bundled GitHub Actions workflow YAMLs and writes them into
/// a target project's `.github/workflows/` directory.
class WorkflowService {
  static const bundled = <BundledWorkflow>[
    BundledWorkflow(
      key: 'shorebird-android-release',
      filename: 'shorebird-android-release.yml',
      label: 'Shorebird Android Release',
      description:
          'Build & ship an Android Shorebird release, then upload the AAB '
          'to the chosen Play Console track.',
    ),
    BundledWorkflow(
      key: 'shorebird-android-patch',
      filename: 'shorebird-android-patch.yml',
      label: 'Shorebird Android Patch',
      description: 'OTA Dart patch for the latest Android release.',
    ),
    BundledWorkflow(
      key: 'shorebird-ios-release',
      filename: 'shorebird-ios-release.yml',
      label: 'Shorebird iOS Release',
      description:
          'Build & ship an iOS Shorebird release, fetch signing via match, '
          'upload IPA to TestFlight.',
    ),
    BundledWorkflow(
      key: 'shorebird-ios-patch',
      filename: 'shorebird-ios-patch.yml',
      label: 'Shorebird iOS Patch',
      description: 'OTA Dart patch for the latest iOS release.',
    ),
  ];

  /// Read a bundled workflow's YAML body.
  Future<String> readBundled(String filename) {
    return rootBundle.loadString('assets/workflows/$filename');
  }

  /// Install [yaml] under `<project>/.github/workflows/<filename>`.
  /// Returns the absolute path of the written file.
  Future<String> install({
    required String projectRoot,
    required String filename,
    required String yaml,
  }) async {
    final dir = Directory(p.join(projectRoot, '.github', 'workflows'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final outPath = p.join(dir.path, filename);
    await File(outPath).writeAsString(yaml);
    return outPath;
  }

  /// Lists what's already installed in the target project.
  Future<List<String>> listInstalled(String projectRoot) async {
    final dir = Directory(p.join(projectRoot, '.github', 'workflows'));
    if (!await dir.exists()) return const [];
    final entries = await dir.list().toList();
    return entries
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where((name) => name.endsWith('.yml') || name.endsWith('.yaml'))
        .toList()
      ..sort();
  }
}

class BundledWorkflow {
  const BundledWorkflow({
    required this.key,
    required this.filename,
    required this.label,
    required this.description,
  });

  final String key;
  final String filename;
  final String label;
  final String description;
}
