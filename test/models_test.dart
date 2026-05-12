import 'package:fast_deploy/models/credentials.dart';
import 'package:fast_deploy/models/project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Project', () {
    test('decodeList returns an empty list for corrupt saved data', () {
      expect(Project.decodeList('{not-json'), isEmpty);
      expect(Project.decodeList('{"unexpected":"shape"}'), isEmpty);
    });

    test('copyWith can clear optional identifiers', () {
      final project = Project(
        id: '1',
        name: 'App',
        path: '/tmp/app',
        appIdentifier: 'com.example.app',
        packageName: 'com.example.app',
      );

      final cleared = project.copyWith(appIdentifier: null, packageName: null);

      expect(cleared.appIdentifier, isNull);
      expect(cleared.packageName, isNull);
      expect(cleared.name, 'App');
    });
  });

  group('Credentials', () {
    test('copyWith can clear optional secrets', () {
      final credentials = Credentials(
        teamId: 'TEAM123456',
        matchPassword: 'secret',
        shorebirdAppId: 'shorebird-id',
      );

      final cleared = credentials.copyWith(
        matchPassword: null,
        shorebirdAppId: null,
      );

      expect(cleared.teamId, 'TEAM123456');
      expect(cleared.matchPassword, isNull);
      expect(cleared.shorebirdAppId, isNull);
    });

    test('toEnv drops empty values and keeps defaults', () {
      final env = Credentials(
        teamId: '',
        matchGitBranch: 'main',
        playServiceAccountJsonPath: '/tmp/play.json',
      ).toEnv();

      expect(env, isNot(contains('TEAM_ID')));
      expect(env['MATCH_GIT_BRANCH'], 'main');
      expect(env['PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH'], '/tmp/play.json');
    });
  });
}
