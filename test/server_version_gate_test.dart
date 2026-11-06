import 'package:flutter_test/flutter_test.dart';

import 'package:adguard_home_manager/config/minimum_server_version.dart';
import 'package:adguard_home_manager/functions/compare_versions.dart';

bool supported(String serverVersion) => serverVersionIsAhead(
  currentVersion: serverVersion,
  referenceVersion: MinimumServerVersion.stable,
  referenceVersionBeta: MinimumServerVersion.beta,
);

void main() {
  group('AghVersion.tryParse', () {
    test('reads a release', () {
      final v = AghVersion.tryParse('v0.107.28')!;
      expect(v.major, 0);
      expect(v.minor, 107);
      expect(v.patch, 28);
      expect(v.channel, isNull);
      expect(v.isPreRelease, isFalse);
    });

    test('reads a beta and its build metadata', () {
      final v = AghVersion.tryParse('v1.0.0-b.1+71c5733')!;
      expect(v.major, 1);
      expect(v.channel, 'b');
      expect(v.build, 1);
      expect(v.isPreRelease, isTrue);
    });

    test('reads an alpha', () {
      expect(AghVersion.tryParse('v0.108.0-a.10')!.channel, 'a');
    });

    test('reads the build metadata of a release', () {
      final v = AghVersion.tryParse('v1.0.1+99f79fc')!;
      expect(v.patch, 1);
      expect(v.isPreRelease, isFalse);
    });

    test('refuses what AdGuard Home would never answer', () {
      for (final text in ['', '   ', 'unknown', 'v1.0', 'v1.0.0-', 'v1.0.0-b.']) {
        expect(AghVersion.tryParse(text), isNull, reason: text);
      }
    });
  });

  group('serverVersionIsAhead', () {
    test('accepts a beta built from source', () {
      // This is the answer of the forked backend, and the version that used to
      // throw inside int.parse("1+71c5733").
      expect(supported('v1.0.0-b.1+71c5733'), isTrue);
      expect(supported('v0.108.0-b.33+deadbeef'), isTrue);
    });

    test('accepts the minimum itself and anything newer', () {
      expect(supported(MinimumServerVersion.stable), isTrue);
      expect(supported('v0.107.40'), isTrue);
      expect(supported('v0.108.0'), isTrue);
      expect(supported('v1.0.1'), isTrue);
      expect(supported(MinimumServerVersion.beta), isTrue);
      expect(supported('v0.108.0-b.34'), isTrue);
    });

    test('refuses a server that really is behind', () {
      expect(supported('v0.107.27'), isFalse);
      expect(supported('v0.100.0'), isFalse);
      expect(supported('v0.108.0-b.32'), isFalse);
      expect(supported('v0.107.57-b.9'), isFalse);
    });

    test('does not read a channel out of a commit hash', () {
      // The old code asked whether the text contains 'a' or 'b' anywhere, so a
      // release whose hash happened to carry those letters was misjudged.
      expect(supported('v0.107.28+badcafe'), isTrue);
      expect(supported('v0.107.20+badcafe'), isFalse);
    });

    test('refuses a version it cannot read', () {
      expect(supported(''), isFalse);
      expect(supported('unknown'), isFalse);
    });
  });

  group('serverVersionNeedsWarning', () {
    test('stays quiet on the beta backend this app ships with', () {
      expect(serverVersionNeedsWarning('v1.0.0-b.1+c7042ec'), isFalse);
      expect(serverVersionNeedsWarning(MinimumServerVersion.beta), isFalse);
    });

    test('stays quiet on a release whatever its hash says', () {
      expect(serverVersionNeedsWarning('v1.0.1'), isFalse);
      expect(serverVersionNeedsWarning('v1.0.1+badcafe'), isFalse);
    });

    test('warns only on an alpha', () {
      expect(serverVersionNeedsWarning('v0.108.0-a.10'), isTrue);
    });

    test('says nothing about a version it cannot read', () {
      expect(serverVersionNeedsWarning(''), isFalse);
      expect(serverVersionNeedsWarning('abc'), isFalse);
    });
  });
}
