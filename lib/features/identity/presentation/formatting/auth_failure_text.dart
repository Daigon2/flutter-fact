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
import 'package:fact_app/features/identity/presentation/notifiers/signup_notifier.dart';

/// Schlüssel für falsche Zugangsdaten, PWA `screen-auth.jsx:476`.
const String authInvalidLoginKey = 'onboarding.errInvalidLogin';

/// Schlüssel für eine unbestätigte E-Mail-Adresse, PWA `screen-auth.jsx:477`.
const String authEmailNotConfirmedKey = 'login.errEmailNotConfirmed';

/// Schlüssel für alles übrige, PWA `screen-auth.jsx:478`.
const String authGenericKey = 'onboarding.errGeneric';

/// Schlüssel für eine unvollständige Eingabe, PWA `screen-auth.jsx:461` und
/// `:611`. Anmeldung und Registrierung benutzen denselben.
const String authRequiredKey = 'onboarding.errRequired';

/// Schlüssel für die fehlende Zustimmung, PWA `screen-auth.jsx:612`.
const String authTermsNotAcceptedKey = 'signup.errAcceptTerms';

/// Schlüssel für einen fehlenden oder unbrauchbaren Username, PWA
/// `screen-auth.jsx:615`.
///
/// Der Text ist "Pflichtfeld" und deckt damit auch die Fälle "schon vergeben"
/// und "ungültig" ab. Das ist die Quelle: sie zeigt für alle drei denselben
/// Satz, weil das Feld selbst über Rahmenfarbe und Abzeichen schon sagt, was los
/// ist. `username.taken` und `username.invalid` bleiben deshalb der Anzeige am
/// Feld vorbehalten.
const String authUsernameRequiredKey = 'username.required';

/// Schlüssel für eine schon registrierte Adresse, PWA `screen-auth.jsx:640`.
const String authAlreadyRegisteredKey = 'onboarding.errAlreadyRegistered';

/// Schlüssel für ein abgelehntes Passwort, PWA `screen-auth.jsx:641`.
const String authPasswordRejectedKey = 'onboarding.errPassword';

/// Der Sammeltext der **Registrierung**, PWA `screen-auth.jsx:642`.
///
/// Ein anderer als [authGenericKey]: die Quelle hat für die beiden Bildschirme
/// zwei verschiedene Sätze ("Fehler beim Anmelden." gegen "Registrierung
/// fehlgeschlagen."). Deshalb ist der Sammeltext ein Parameter von
/// [authFailureTextKey] und keine Konstante in der Funktion.
const String signupGenericKey = 'signup.errGeneric';

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
///
/// [genericKey] ist der Sammeltext für alles, was keinen eigenen Satz hat.
/// Standard ist [authGenericKey], also der Text der Anmeldung; die
/// Registrierung übergibt [signupGenericKey]. **Ein Parameter und keine zweite
/// Funktion:** eine zweite Abbildung müsste bei jedem neuen Fehlerfall
/// mitgepflegt werden, und die vergessene wäre die, die man erst im
/// Fehlerfall bemerkt.
String authFailureTextKey(Object error, {String genericKey = authGenericKey}) {
  return switch (error) {
    // Eingabeprüfungen der beiden Bildschirme. Sie reisen im Fehlerkanal mit,
    // siehe die Begründung in `LoginNotifier` und `SignupNotifier`.
    LoginInputIncomplete() || SignupInputIncomplete() => authRequiredKey,
    SignupTermsNotAccepted() => authTermsNotAcceptedKey,
    SignupUsernameUnusable() => authUsernameRequiredKey,
    // Antworten des Backends.
    AuthInvalidCredentials() => authInvalidLoginKey,
    AuthEmailNotConfirmed() => authEmailNotConfirmedKey,
    AuthEmailAlreadyRegistered() => authAlreadyRegisteredKey,
    AuthPasswordRejected() => authPasswordRejectedKey,
    // `AuthRequestRejected`, `AuthBackendUnavailable` und alles Unerwartete.
    // Die PWA unterscheidet hier ebenfalls nicht.
    _ => genericKey,
  };
}
