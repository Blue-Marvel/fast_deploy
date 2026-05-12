import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/credentials.dart';
import '../services/deploy_controller.dart';

/// Per-project credentials editor.
class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  late final _controllers = <String, TextEditingController>{
    for (final f in const [
      'teamId',
      'appleId',
      'appStoreConnectKeyJsonPath',
      'matchGitUrl',
      'matchGitBranch',
      'matchPassword',
      'matchDeployKeyPath',
      'playServiceAccountJsonPath',
      'shorebirdAppId',
    ])
      f: TextEditingController(),
  };

  bool _loading = true;
  bool _dirty = false;
  bool _editing = false;
  bool _saving = false;
  Credentials? _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final c = context.read<DeployController>().loadCredentials(
      widget.projectId,
    );
    _set('teamId', c.teamId);
    _set('appleId', c.appleId);
    _set('appStoreConnectKeyJsonPath', c.appStoreConnectKeyJsonPath);
    _set('matchGitUrl', c.matchGitUrl);
    _set('matchGitBranch', c.matchGitBranch);
    _set('matchPassword', c.matchPassword);
    _set('matchDeployKeyPath', c.matchDeployKeyPath);
    _set('playServiceAccountJsonPath', c.playServiceAccountJsonPath);
    _set('shorebirdAppId', c.shorebirdAppId);
    if (mounted) {
      setState(() {
        _loading = false;
        _saved = c;
        _editing = !_hasAnyValue(c);
      });
    }
  }

  bool _hasAnyValue(Credentials c) {
    return [
      c.teamId,
      c.appleId,
      c.appStoreConnectKeyJsonPath,
      c.matchGitUrl,
      c.matchPassword,
      c.matchDeployKeyPath,
      c.playServiceAccountJsonPath,
      c.shorebirdAppId,
    ].any((value) => value != null && value.isNotEmpty);
  }

  void _set(String key, String? value) {
    _controllers[key]!.text = value ?? '';
  }

  String _get(String key) => _controllers[key]!.text.trim();

  Future<void> _save() async {
    final c = Credentials(
      teamId: _get('teamId'),
      appleId: _get('appleId'),
      appStoreConnectKeyJsonPath: _get('appStoreConnectKeyJsonPath'),
      matchGitUrl: _get('matchGitUrl'),
      matchGitBranch: _get('matchGitBranch').isEmpty
          ? 'main'
          : _get('matchGitBranch'),
      matchPassword: _get('matchPassword'),
      matchDeployKeyPath: _get('matchDeployKeyPath'),
      playServiceAccountJsonPath: _get('playServiceAccountJsonPath'),
      shorebirdAppId: _get('shorebirdAppId'),
    );
    final controller = context.read<DeployController>();
    setState(() => _saving = true);
    try {
      await controller.saveCredentials(widget.projectId, c);
      final reloaded = controller.loadCredentials(widget.projectId);
      if (!mounted) return;
      setState(() {
        _saved = reloaded;
        _dirty = false;
        _saving = false;
        _editing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Credentials saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  void _enterEditMode() {
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    final c = _saved;
    if (c != null) {
      _set('teamId', c.teamId);
      _set('appleId', c.appleId);
      _set('appStoreConnectKeyJsonPath', c.appStoreConnectKeyJsonPath);
      _set('matchGitUrl', c.matchGitUrl);
      _set('matchGitBranch', c.matchGitBranch);
      _set('matchPassword', c.matchPassword);
      _set('matchDeployKeyPath', c.matchDeployKeyPath);
      _set('playServiceAccountJsonPath', c.playServiceAccountJsonPath);
      _set('shorebirdAppId', c.shorebirdAppId);
    }
    setState(() {
      _dirty = false;
      _editing = false;
    });
  }

  Future<void> _importEnv() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select .env file',
      type: FileType.any,
    );
    final path = result?.files.single.path;
    if (path == null) return;

    try {
      final file = File(path);
      final lines = await file.readAsLines();
      final env = <String, String>{};
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final eq = line.indexOf('=');
        if (eq > 0) {
          var key = line.substring(0, eq).trim();
          var value = line.substring(eq + 1).trim();
          // Remove quotes if present
          if ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'"))) {
            value = value.substring(1, value.length - 1);
          }
          env[key] = value;
        }
      }

      final mapping = {
        'TEAM_ID': 'teamId',
        'APPLE_ID': 'appleId',
        'ASC_API_KEY_JSON_PATH': 'appStoreConnectKeyJsonPath',
        'MATCH_GIT_URL': 'matchGitUrl',
        'MATCH_GIT_BRANCH': 'matchGitBranch',
        'MATCH_PASSWORD': 'matchPassword',
        'MATCH_DEPLOY_KEY_PATH': 'matchDeployKeyPath',
        'PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH': 'playServiceAccountJsonPath',
        'SHOREBIRD_APP_ID': 'shorebirdAppId',
      };

      var changed = false;
      for (final entry in mapping.entries) {
        if (env.containsKey(entry.key)) {
          _controllers[entry.value]!.text = env[entry.key]!;
          changed = true;
        }
      }

      if (changed && mounted) {
        setState(() => _dirty = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credentials imported from .env')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to parse .env: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(body: _buildForm());
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Group(
          title: 'iOS',
          description:
              'Apple identifiers for code signing and TestFlight uploads.',
          children: [
            _field(
              'teamId',
              'TEAM_ID',
              hint: '10-char Apple developer team id',
            ),
            _field(
              'appleId',
              'Apple ID (optional)',
              hint: 'used as a contact email by fastlane',
            ),
            _filePicker(
              'appStoreConnectKeyJsonPath',
              'App Store Connect API key (.json)',
              hint:
                  'JSON with key_id, issuer_id, key. Used for TestFlight upload.',
            ),
          ],
        ),
        _Group(
          title: 'fastlane match',
          description:
              'Where your shared signing certs/profiles live. Only fill these in '
              'if you use match.',
          children: [
            _field(
              'matchGitUrl',
              'MATCH_GIT_URL',
              hint: 'git@github.com:owner/cert-repo.git',
            ),
            _field(
              'matchGitBranch',
              'MATCH_GIT_BRANCH',
              hint: 'main (default)',
            ),
            _field(
              'matchPassword',
              'MATCH_PASSWORD',
              obscure: true,
              hint: 'decryption password for the match repo',
            ),
            _filePicker(
              'matchDeployKeyPath',
              'Match deploy key (private SSH key)',
              hint:
                  'optional — only if your normal SSH key can\'t access the repo',
            ),
          ],
        ),
        _Group(
          title: 'Android',
          description:
              'Service account JSON used by `fastlane supply` to push your AAB '
              'to Play Console.',
          children: [
            _filePicker(
              'playServiceAccountJsonPath',
              'Play Store service account JSON',
              hint: 'created in Google Cloud → IAM → Service accounts',
            ),
          ],
        ),
        _Group(
          title: 'Shorebird',
          description:
              'Shorebird app id from `shorebird.yaml` in your project. Mostly '
              'informational — the actual auth comes from `shorebird login` on '
              'this machine.',
          children: [
            _field(
              'shorebirdAppId',
              'Shorebird App ID',
              hint: 'from shorebird.yaml',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 12,
            children: [
              if (_editing) ...[
                OutlinedButton.icon(
                  onPressed: _saving ? null : _importEnv,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Import .env'),
                ),
                if (_saved != null && _hasAnyValue(_saved!))
                  TextButton(
                    onPressed: _saving ? null : _cancelEdit,
                    child: const Text('Cancel'),
                  ),
                FilledButton.icon(
                  onPressed: (_dirty && !_saving) ? _save : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving...' : 'Save'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: _enterEditMode,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _controllers[key],
        readOnly: !_editing,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          suffixIcon: _editing ? null : const Icon(Icons.lock_outline),
        ),
        onChanged: _editing ? (_) => setState(() => _dirty = true) : null,
      ),
    );
  }

  Widget _filePicker(String key, String label, {String? hint}) {
    final controller = _controllers[key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: !_editing,
              decoration: InputDecoration(
                labelText: label,
                helperText: hint,
                suffixIcon: _editing ? null : const Icon(Icons.lock_outline),
              ),
              onChanged: _editing ? (_) => setState(() => _dirty = true) : null,
            ),
          ),
          if (_editing) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Browse'),
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  dialogTitle: label,
                );
                final file = result?.files.single.path;
                if (file != null) {
                  controller.text = file;
                  if (mounted) setState(() => _dirty = true);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
