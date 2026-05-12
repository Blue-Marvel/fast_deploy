/// All credential values for a single project. Passed to bundled scripts as
/// env vars.
const Object _unset = Object();

class Credentials {
  Credentials({
    this.teamId,
    this.appleId,
    this.appStoreConnectKeyJsonPath,
    this.matchGitUrl,
    this.matchGitBranch = 'main',
    this.matchPassword,
    this.matchDeployKeyPath,
    this.playServiceAccountJsonPath,
    this.shorebirdAppId,
  });

  // iOS
  final String? teamId;
  final String? appleId;
  final String? appStoreConnectKeyJsonPath;
  final String? matchGitUrl;
  final String matchGitBranch;
  final String? matchPassword;
  final String? matchDeployKeyPath;

  // Android
  final String? playServiceAccountJsonPath;

  // Shorebird
  final String? shorebirdAppId;

  Credentials copyWith({
    Object? teamId = _unset,
    Object? appleId = _unset,
    Object? appStoreConnectKeyJsonPath = _unset,
    Object? matchGitUrl = _unset,
    String? matchGitBranch,
    Object? matchPassword = _unset,
    Object? matchDeployKeyPath = _unset,
    Object? playServiceAccountJsonPath = _unset,
    Object? shorebirdAppId = _unset,
  }) {
    return Credentials(
      teamId: teamId == _unset ? this.teamId : teamId as String?,
      appleId: appleId == _unset ? this.appleId : appleId as String?,
      appStoreConnectKeyJsonPath: appStoreConnectKeyJsonPath == _unset
          ? this.appStoreConnectKeyJsonPath
          : appStoreConnectKeyJsonPath as String?,
      matchGitUrl: matchGitUrl == _unset
          ? this.matchGitUrl
          : matchGitUrl as String?,
      matchGitBranch: matchGitBranch ?? this.matchGitBranch,
      matchPassword: matchPassword == _unset
          ? this.matchPassword
          : matchPassword as String?,
      matchDeployKeyPath: matchDeployKeyPath == _unset
          ? this.matchDeployKeyPath
          : matchDeployKeyPath as String?,
      playServiceAccountJsonPath: playServiceAccountJsonPath == _unset
          ? this.playServiceAccountJsonPath
          : playServiceAccountJsonPath as String?,
      shorebirdAppId: shorebirdAppId == _unset
          ? this.shorebirdAppId
          : shorebirdAppId as String?,
    );
  }

  /// The env vars the bundled scripts read. Null/empty values are dropped so
  /// `${VAR:-}` defaults in the scripts kick in.
  Map<String, String> toEnv() {
    final env = <String, String>{};
    void put(String k, String? v) {
      if (v != null && v.isNotEmpty) env[k] = v;
    }

    put('TEAM_ID', teamId);
    put('APPLE_ID', appleId);
    put('ASC_API_KEY_JSON_PATH', appStoreConnectKeyJsonPath);
    put('MATCH_GIT_URL', matchGitUrl);
    put('MATCH_GIT_BRANCH', matchGitBranch);
    put('MATCH_PASSWORD', matchPassword);
    put('MATCH_DEPLOY_KEY_PATH', matchDeployKeyPath);
    put('PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH', playServiceAccountJsonPath);
    put('SHOREBIRD_APP_ID', shorebirdAppId);
    return env;
  }
}
