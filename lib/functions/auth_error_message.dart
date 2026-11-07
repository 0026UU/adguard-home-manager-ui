import 'package:flutter/widgets.dart';

import 'package:adguard_home_manager/l10n/app_localizations.dart';
import 'package:adguard_home_manager/services/auth.dart';

/// One mapping from a login outcome to the sentence that explains it.
///
/// The connection form and the server tiles used to disagree: the form named
/// the cause, the tiles answered every failure — wrong password, dead host,
/// failed TLS handshake — with the same "Cannot connect to the server", so a
/// user with a typo in the password was sent to check the network.
String authErrorMessage(BuildContext context, AuthStatus status) {
  final l = AppLocalizations.of(context)!;
  if (status == AuthStatus.invalidCredentials) return l.invalidUsernamePassword;
  if (status == AuthStatus.manyAttepts) return l.tooManyAttempts;
  if (status == AuthStatus.socketException ||
      status == AuthStatus.timeoutException) {
    return l.cantReachServer;
  }
  if (status == AuthStatus.serverError) return l.serverError;
  if (status == AuthStatus.handshakeException) return l.sslError;
  return l.unknownError;
}
