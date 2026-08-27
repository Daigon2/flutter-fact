/// Von einem Fehlschlag zum i18n-Schlüssel.
///
/// Die dritte und letzte Station der Fehlerübersetzung. Die anderen zwei:
///
/// 1. `data/datasources/remote/supabase_auth_remote_data_source.dart` bildet die
///    Vendor-Ausnahme auf eine [AuthFailure] ab;
/// 2. `domain/failures/auth_failure.dart` trägt das Ergebnis, ohne Text und ohne
///    Vendor-Objekt;
/// 3. hier wird daraus ein Schlüssel.
///
/// Jede Station hat genau eine Aufgabe. `data-flow.md` §5: "domain failures
/// contain no localized text."
///
/// Die Schlüssel selbst existieren bereits alle in
/// `lib/app/localization/generated/`, es entsteht kein neuer.
library;

import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:fact_app/features/identity/presentation/notifiers/login_notifier.dart';

/// Schlüssel für falsche Zugangsdaten, PWA `screen-auth.jsx:476`.
const String authInvalidLoginKey = 'onboarding.errInvalidLogin';

/// Schlüssel für eine unbestätigte E-Mail-Adresse, PWA `screen-auth.jsx:477`.
const String authEmailNotConfirmedKey = 'login.errEmailNotConfirmed';

/// Schlüssel für alles übrige, PWA `screen-auth.jsx:478`.
const String authGenericKey = 'onboarding.errGeneric';

/// Schlüssel für eine unvollständige Eingabe, PWA `screen-auth.jsx:461`.
const String authRequiredKey = 'onboarding.errRequired';

/// Der i18n-Schlüssel, der [error] dem Nutzer erklärt.
///
/// Nimmt bewusst `Object` und nicht [AuthFailure]: im Fehlerkanal von
/// `LoginNotifier` liegt auch [LoginInputIncomplete], und ein unerwarteter
/// Fehler soll nicht in einer Typprüfung stecken bleiben, sondern eine Meldung
/// bekommen.
///
/// ## Bewusste Abweichung von der PWA, die in den Bericht gehört
///
/// Für den Restfall zeigt die PWA die **rohe englische Meldung des Backends**:
/// `screen-auth.jsx:478` lautet `setError(msg || t('onboarding.errGeneric'))`,
/// und `msg` ist gesetzt, sobald Supabase überhaupt etwas geschickt hat. Der
/// deutsche Text erscheint dort also praktisch nie.
///
/// Hier erscheint stattdessen immer [authGenericKey]. Grund:
/// `cross-cutting-concerns.md` verlangt "Sensitive backend details are never
/// shown to users", und eine Auth-Fehlermeldung ist genau der Ort, an dem
/// Backend-Interna auftauchen. Für die Diagnose bleibt der technische
/// `AuthFailure.code` samt der Senke in `lib/core/diagnostics/`.
String authFailureTextKey(Object error) {
  return switch (error) {
    LoginInputIncomplete() => authRequiredKey,
    AuthInvalidCredentials() => authInvalidLoginKey,
    AuthEmailNotConfirmed() => authEmailNotConfirmedKey,
    // `AuthRequestRejected`, `AuthBackendUnavailable` und alles Unerwartete.
    // Die PWA unterscheidet hier ebenfalls nicht.
    _ => authGenericKey,
  };
}
