import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:adguard_home_manager/models/github_release.dart';

/// The version AdGuard Home reports: `v<major>.<minor>.<patch>`, optionally
/// followed by a pre-release such as `-b.33` and by build metadata such as
/// `+99f79fc`.
class AghVersion {
  final int major;
  final int minor;
  final int patch;

  /// The pre-release channel, `a` or `b`, and null on a plain release.
  final String? channel;

  /// The number of the pre-release, 0 on a plain release.
  final int build;

  const AghVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.channel,
    this.build = 0,
  });

  static final RegExp _pattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([ab])\.(\d+))?(?:\+[0-9A-Za-z][0-9A-Za-z.]*)?$',
  );

  /// Returns null when the text is not a version AdGuard Home could report.
  /// The build metadata plays no part in the ordering, but it is part of the
  /// text a server built from source answers with, so it is accepted here.
  static AghVersion? tryParse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;

    return AghVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      channel: match.group(4),
      build: match.group(5) == null ? 0 : int.parse(match.group(5)!),
    );
  }

  bool get isPreRelease => channel != null;

  /// Negative when this version comes before [other].  A release outranks any
  /// pre-release of its own number, `b` outranks `a`, a higher build outranks
  /// a lower one.
  int compareTo(AghVersion other) {
    if (major != other.major) return major - other.major;
    if (minor != other.minor) return minor - other.minor;
    if (patch != other.patch) return patch - other.patch;

    if (channel == null && other.channel == null) return 0;
    if (channel == null) return 1;
    if (other.channel == null) return -1;
    if (channel != other.channel) return channel!.compareTo(other.channel!);

    return build - other.build;
  }
}

/// Whether the server answering [currentVersion] is new enough to be managed.
///
/// A pre-release server is held to [referenceVersionBeta] and a release server
/// to [referenceVersion], because the two lines move apart.  False means either
/// that the server is behind or that its version could not be read at all.
bool serverVersionIsAhead({
  required String currentVersion,
  required String referenceVersion,
  String? referenceVersionBeta,
}) {
  final current = AghVersion.tryParse(currentVersion);
  if (current == null) {
    Sentry.captureMessage("Unreadable server version", params: [
      {
        "fn": "serverVersionIsAhead",
        "currentVersion": currentVersion,
      }.toString()
    ]);

    return false;
  }

  final reference = AghVersion.tryParse(
    current.isPreRelease ? (referenceVersionBeta ?? "") : referenceVersion,
  );
  if (reference == null) return false;

  return current.compareTo(reference) >= 0;
}

/// Whether the app should refuse to manage a server because of its version.
///
/// This is not the same question as [serverVersionIsAhead].  A server that
/// answers without a readable version — one built from source, or an install
/// whose build metadata was stripped — is unknown, not old, and refusing it
/// would throw away the connection: every gate that shows the unsupported
/// modal also deselects the server, so the user loses a server that answers
/// every request fine.  The requests themselves decide.
bool serverVersionIsTooOld({
  required String currentVersion,
  required String referenceVersion,
  String? referenceVersionBeta,
}) {
  if (AghVersion.tryParse(currentVersion) == null) return false;

  return !serverVersionIsAhead(
    currentVersion: currentVersion,
    referenceVersion: referenceVersion,
    referenceVersionBeta: referenceVersionBeta,
  );
}

/// Whether the server answering [version] deserves a warning although it
/// clears the gate.
///
/// Alphas move the API under the app with nothing released to test against.
/// The beta line is different: [MinimumServerVersion.beta] is the floor the app
/// is built and checked against, so a beta at or above it is the setup this app
/// is meant to drive and stays quiet.
bool serverVersionNeedsWarning(String version) =>
    AghVersion.tryParse(version)?.channel == 'a';

bool gitHubUpdateExists({
  required String currentBuildNumber,
  required GitHubRelease gitHubRelease,
  required bool isBeta
}) {
  final versionNumberRegex = RegExp(r'\(\d+\)');
  final releaseNumberExtractedMatches = versionNumberRegex.allMatches(gitHubRelease.tagName);

  if (releaseNumberExtractedMatches.isNotEmpty) {
    final releaseNumberExtracted = releaseNumberExtractedMatches.first.group(0);

    if (releaseNumberExtracted != null) {
      final releaseNumber = releaseNumberExtracted.replaceAll(RegExp(r'\(|\)'), '');
      try {
        final newReleaseParsed = int.parse(releaseNumber);
        final currentReleaseParsed = int.parse(currentBuildNumber);
        if (newReleaseParsed > currentReleaseParsed) {
          return true;
        }
        else {
          return false;
        }
      } catch (e) {
        Sentry.captureMessage("Invalid release number. Current release: $currentBuildNumber. New release: $releaseNumber");
        return false;
      }
    }
    else {
      Sentry.captureMessage("Invalid release number. Tagname: ${gitHubRelease.tagName}");
      return false;
    }
  }
  else {
    Sentry.captureMessage("No matches. ${gitHubRelease.tagName}");
    return false;
  }
}
