/// Which platform(s) a deploy job targets.
enum DeployPlatform { android, ios, both }

/// What the user wants the job to actually do.
enum DeployAction {
  /// Build a fresh release (Shorebird release + optional store upload).
  release,

  /// Ship a Shorebird patch against the latest release.
  patch,

  /// Plain Flutter build — AAB on Android, IPA on iOS, no Shorebird, no upload.
  buildNoShorebird,

  /// Plain Flutter build + push to the store (Play / TestFlight). No Shorebird.
  releaseNoShorebird,

  /// iOS only: build IPA without uploading and open Xcode for archive review.
  buildAndOpenXcode,
}

/// Play Store track to upload to.
enum PlayTrack { internal, alpha, beta, production }

extension PlayTrackX on PlayTrack {
  String get value {
    switch (this) {
      case PlayTrack.internal:
        return 'internal';
      case PlayTrack.alpha:
        return 'alpha';
      case PlayTrack.beta:
        return 'beta';
      case PlayTrack.production:
        return 'production';
    }
  }
}

class DeployConfig {
  DeployConfig({
    required this.platform,
    required this.action,
    this.playTrack = PlayTrack.internal,
    this.skipUpload = false,
    this.releaseVersion,
  });

  final DeployPlatform platform;
  final DeployAction action;
  final PlayTrack playTrack;
  final bool skipUpload;

  /// For patch jobs only. Null means "latest".
  final String? releaseVersion;

  DeployConfig copyWith({
    DeployPlatform? platform,
    DeployAction? action,
    PlayTrack? playTrack,
    bool? skipUpload,
    String? releaseVersion,
  }) {
    return DeployConfig(
      platform: platform ?? this.platform,
      action: action ?? this.action,
      playTrack: playTrack ?? this.playTrack,
      skipUpload: skipUpload ?? this.skipUpload,
      releaseVersion: releaseVersion ?? this.releaseVersion,
    );
  }
}
