import 'dart:convert';

const Object _unset = Object();

class Project {
  Project({
    required this.id,
    required this.name,
    required this.path,
    this.appIdentifier,
    this.packageName,
    this.flutterVersion = '3.41.9',
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  final String id;
  final String name;
  final String path;
  final String? appIdentifier;
  final String? packageName;
  final String flutterVersion;
  final DateTime addedAt;

  Project copyWith({
    String? name,
    String? path,
    Object? appIdentifier = _unset,
    Object? packageName = _unset,
    String? flutterVersion,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      path: path ?? this.path,
      appIdentifier: appIdentifier == _unset
          ? this.appIdentifier
          : appIdentifier as String?,
      packageName: packageName == _unset
          ? this.packageName
          : packageName as String?,
      flutterVersion: flutterVersion ?? this.flutterVersion,
      addedAt: addedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'appIdentifier': appIdentifier,
    'packageName': packageName,
    'flutterVersion': flutterVersion,
    'addedAt': addedAt.toIso8601String(),
  };

  factory Project.fromJson(Map<String, Object?> json) => Project(
    id: json['id'] as String,
    name: json['name'] as String,
    path: json['path'] as String,
    appIdentifier: json['appIdentifier'] as String?,
    packageName: json['packageName'] as String?,
    flutterVersion: (json['flutterVersion'] as String?) ?? '3.41.9',
    addedAt: DateTime.parse(json['addedAt'] as String),
  );

  static String encodeList(List<Project> projects) =>
      jsonEncode(projects.map((p) => p.toJson()).toList());

  static List<Project> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return [
        for (final item in list)
          if (item is Map<String, Object?>) Project.fromJson(item),
      ];
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }
}
