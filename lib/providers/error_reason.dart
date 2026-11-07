import 'package:adguard_home_manager/services/api_client.dart';

/// The reason the last request of a provider failed, carried up to the screen.
///
/// AdGuard Home answers a refusal with a one-line reason in the body, and the
/// API layer now hands it through on `ApiResponse.message`. Every provider
/// method this app has ever written returns either a bare `Future<bool>` or an
/// `ApiResponse` nobody reads, so that sentence used to die at the provider
/// boundary and the screen could only ever say "could not be loaded". A
/// provider that mixes this in keeps the sentence instead.
///
/// The text is the server's own English and is shown verbatim where the app
/// already shows server text — it beats a generic sentence whenever the server
/// has explained itself, and the localised title above it still says what kind
/// of failure this was.
mixin ErrorReason {
  String? _errorMessage;

  /// Why the last request failed, or null when the last one worked or nothing
  /// has been asked yet.
  String? get errorMessage => _errorMessage;

  /// Remembers the reason carried by [result], and forgets it when the call
  /// succeeded, so a screen never shows a stale complaint over good data.
  ///
  /// A null [result] is the case of a provider that gave up before asking the
  /// server; [fallback] is what it should say then.
  void captureErrorReason(
    ApiResponse? result, {
    String? fallback,
  }) {
    if (result == null || result.successful != true) {
      _errorMessage = result?.message ?? fallback;
    }
    else {
      _errorMessage = null;
    }
  }

  /// Sets the reason directly, for a failure this class produced itself —
  /// an exception it caught or a precondition it refused.
  void setErrorMessage(String? message) {
    _errorMessage = message;
  }

  /// Records [message] and answers `false`, for the many provider methods
  /// whose whole contract is "false, plus a reason the screen can show".
  bool setFailureReason(String message) {
    _errorMessage = message;
    return false;
  }
}
