import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';

/// Persists the user's list of Flutter projects in SharedPreferences.
class ProjectRepository {
  ProjectRepository(this._prefs);

  static const _key = 'projects.v1';
  final SharedPreferences _prefs;

  List<Project> load() {
    return Project.decodeList(_prefs.getString(_key));
  }

  Future<void> save(List<Project> projects) async {
    await _prefs.setString(_key, Project.encodeList(projects));
  }

  static Future<ProjectRepository> open() async {
    return ProjectRepository(await SharedPreferences.getInstance());
  }
}
