import 'package:shared_preferences/shared_preferences.dart';

import '../models/credentials.dart';

/// Per-project credential storage in app preferences.
class CredentialsStore {
  CredentialsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _fields = <String>[
    'teamId',
    'appleId',
    'appStoreConnectKeyJsonPath',
    'matchGitUrl',
    'matchGitBranch',
    'matchPassword',
    'matchDeployKeyPath',
    'playServiceAccountJsonPath',
    'shorebirdAppId',
  ];

  String _key(String projectId, String field) =>
      'credentials.$projectId.$field';

  Credentials load(String projectId) {
    final values = <String, String?>{};
    for (final f in _fields) {
      values[f] = _prefs.getString(_key(projectId, f));
    }
    return Credentials(
      teamId: values['teamId'],
      appleId: values['appleId'],
      appStoreConnectKeyJsonPath: values['appStoreConnectKeyJsonPath'],
      matchGitUrl: values['matchGitUrl'],
      matchGitBranch: values['matchGitBranch'] ?? 'main',
      matchPassword: values['matchPassword'],
      matchDeployKeyPath: values['matchDeployKeyPath'],
      playServiceAccountJsonPath: values['playServiceAccountJsonPath'],
      shorebirdAppId: values['shorebirdAppId'],
    );
  }

  Future<void> save(String projectId, Credentials creds) async {
    Future<void> write(String field, String? value) async {
      if (value == null || value.isEmpty) {
        await _prefs.remove(_key(projectId, field));
      } else {
        await _prefs.setString(_key(projectId, field), value);
      }
    }

    await write('teamId', creds.teamId);
    await write('appleId', creds.appleId);
    await write('appStoreConnectKeyJsonPath', creds.appStoreConnectKeyJsonPath);
    await write('matchGitUrl', creds.matchGitUrl);
    await write('matchGitBranch', creds.matchGitBranch);
    await write('matchPassword', creds.matchPassword);
    await write('matchDeployKeyPath', creds.matchDeployKeyPath);
    await write('playServiceAccountJsonPath', creds.playServiceAccountJsonPath);
    await write('shorebirdAppId', creds.shorebirdAppId);
  }

  Future<void> deleteAll(String projectId) async {
    for (final f in _fields) {
      await _prefs.remove(_key(projectId, f));
    }
  }
}
