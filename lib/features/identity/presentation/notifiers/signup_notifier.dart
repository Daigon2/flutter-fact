import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/username_check_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Was auf dem Formular außer einem Fehler noch zu zeigen ist.
///
/// Bewusst kein `bool`: der Zustand wächst, sobald die Registrierung mehr als
/// einen Hinweis kennt, und ein `bool` hieß dann `isSomething` und würde
/// umgedeutet.
enum SignupStatus {
  /// Nichts zu zeigen. Auch der Zustand nach einem Fehlschlag, denn dann steht
  /// der Fehler im Fehlerkanal.
  untouched,

  /// Das Konto ist angelegt, aber niemand ist angemeldet: das Supabase-Projekt
  /// verlangt eine E-Mail-Bestätigung.
  ///
  /// **Kein Fehler.** Siehe die Begründung in [SignupNotifier.submit].
  emailConfirmationPending,
}

/// Der Registriervorgang, `screen-auth.jsx:610-644` (`handleSignup`).
///
/// `isAutoDispose` und ohne Navigation, aus denselben Gründen wie
/// `loginProvider`: keine alte Fehlermeldung beim Wiederkommen, und wohin es
/// nach dem Erfolg geht, entscheidet `SignupPage` (Regel 12).
final signupProvider = AsyncNotifierProvider<SignupNotifier, SignupStatus>(
  SignupNotifier.new,
  isAutoDispose: true,
);

/// Die Registrierung ist ohne E-Mail-Adresse oder ohne Passwort versucht worden.
///
/// Eigener Typ und nicht `LoginInputIncomplete`, obwohl beide auf denselben
/// Schlüssel zeigen (`onboarding.errRequired`): ein Typ mit "Login" im Namen im
/// Fehlerkanal der Registrierung wäre beim Lesen eines Stapels irreführend, und
/// die beiden Prüfungen können auseinanderlaufen, sobald eine der beiden
/// Bildschirme eine Regel ändert.
final class SignupInputIncomplete implements Exception {
  /// Erzeugt den Fehlschlag.
  const SignupInputIncomplete();

  @override
  String toString() => 'SignupInputIncomplete()';
}

/// Das Kästchen für Nutzungsbedingungen und Datenschutz ist nicht gesetzt.
///
/// **Diese Zustimmung wird nirgends übertragen.** `Api.signUp` schickt
/// E-Mail-Adresse, Passwort und `options.data`, sonst nichts; es gibt keinen
/// Zeitstempel, keine Version der Bedingungen und keinen Nachweis in der
/// Datenbank. Die Prüfung ist damit reine Oberfläche und wie in der Quelle
/// nachgebaut, aber sie belegt nichts. Wer einen Nachweis braucht, braucht eine
/// Backend-Änderung, und die ist eine Entscheidung der Stufe 3.
final class SignupTermsNotAccepted implements Exception {
  /// Erzeugt den Fehlschlag.
  const SignupTermsNotAccepted();

  @override
  String toString() => 'SignupTermsNotAccepted()';
}

/// Der Username fehlt oder ist in einem Zustand, mit dem nicht abgeschickt
/// werden darf.
///
/// Siehe `blocksSignup`: `idle` blockiert nicht, auch nicht in der Quelle.
final class SignupUsernameUnusable implements Exception {
  /// Erzeugt den Fehlschlag.
  const SignupUsernameUnusable();

  @override
  String toString() => 'SignupUsernameUnusable()';
}

/// Besitzer des Registriervorgangs.
class SignupNotifier extends AsyncNotifier<SignupStatus> {
  @override
  SignupStatus build() {
    // Synchron und damit sofort `AsyncData`: kein Aufblitzen des gesperrten
    // Knopfes beim Öffnen. Dieselbe Begründung wie bei `LoginNotifier`.
    return SignupStatus.untouched;
  }

  /// Registriert und liefert, ob danach jemand angemeldet ist.
  ///
  /// `true` heißt: Konto angelegt **und** Sitzung vorhanden **und** Username
  /// geschrieben. Nur dann darf der Aufrufer die Erstlauf-Merkung setzen und
  /// weiternavigieren. Alle anderen Ausgänge liefern `false` und legen ihren
  /// Grund in den Zustand.
  ///
  /// ## Die Reihenfolge der drei Prüfungen ist Verhalten
  ///
  /// Genau wie `screen-auth.jsx:611-617`: erst die leeren Felder, dann die
  /// Zustimmung, dann der Username. Wer weder zugestimmt hat **noch** einen
  /// brauchbaren Username hat, sieht die Zustimmungsmeldung, nicht die
  /// Username-Meldung. Das ist per Test festgenagelt, weil eine vertauschte
  /// Reihenfolge sonst niemandem auffällt: beide Meldungen erscheinen an
  /// derselben Stelle und beide verhindern das Abschicken.
  ///
  /// **Keine Formatprüfung der E-Mail-Adresse und keine Mindestlänge des
  /// Passworts.** Die Quelle hat keine, und die Länge kommt als Serverfehler
  /// zurück ([AuthPasswordRejected] und `onboarding.errPassword`). Eine
  /// strengere Prüfung im Client würde Konten aussperren, die der Server
  /// annimmt.
  ///
  /// ## Der Bestätigungsfall ist kein Fehler
  ///
  /// Die Quelle legt `signup.confirmEmailHint` in dieselbe Zustandsvariable wie
  /// jede Fehlermeldung (`setError`) und zeigt "Fast geschafft! Bitte E-Mail
  /// bestätigen" damit in der **roten** Fehlerbox. Der Satz beschreibt einen
  /// Erfolg. Hier wird daraus [SignupStatus.emailConfirmationPending], das die
  /// Seite in einer positiven Box zeigt. Auf dem Formular bleibt es wie in der
  /// Quelle: es gibt nichts, wohin man einen unbestätigten Nutzer schicken
  /// könnte.
  ///
  /// ## Ein fehlgeschlagenes [AuthRepository.setUsername] wird nicht geschluckt
  ///
  /// Die Quelle hängt `.catch(() => {})` daran (`screen-auth.jsx:632`). Der
  /// Fall ist echt: zwischen der Prüfung und dem Schreiben liegen mindestens
  /// 500 ms, in denen jemand anders denselben Namen belegen kann, und der
  /// Eindeutigkeitsindex auf `profiles.username` lehnt das Schreiben dann ab.
  /// In der Quelle sieht der Nutzer davon nichts und führt einen Namen, den
  /// niemand gespeichert hat. Hier landet der Fehlschlag im Zustand, die
  /// Merkung wird nicht gesetzt und es wird nicht navigiert.
  ///
  /// **Was dabei zu wissen ist:** das Konto existiert an dieser Stelle bereits
  /// und die Sitzung auch. Ein zweiter Versuch mit demselben Formular scheitert
  /// deshalb an "diese E-Mail ist bereits registriert". Der Nutzer ist
  /// angemeldet, und die zentrale Weiche in `route_guards.dart` schickt ihn beim
  /// nächsten Refresh auf die Karte, wenn die Registrierung über den
  /// Startbildschirm geöffnet wurde. Der sichtbare Fehler ist damit nicht
  /// garantiert dauerhaft. Das restlos zu lösen hieße, einen Zustand "Konto
  /// angelegt, Username offen" zu erfinden, samt Oberfläche und einem eigenen
  /// i18n-Schlüssel. Beides gehört zu `features/profile` (Phase 7) und nicht in
  /// diesen Schritt.
  Future<bool> submit({
    required String email,
    required String password,
    required String username,
    required UsernameStatus usernameStatus,
    required bool termsAccepted,
    required String hometown,
  }) async {
    if (state.isLoading) {
      // Wie bei der Anmeldung: der gesperrte Knopf verhindert das schon, aber
      // ein Knopf ist nicht der Ort für eine Invariante.
      return false;
    }
    final address = email.trim();
    // Das Passwort wird **nicht** getrimmt, nur auf "nur Leerzeichen" geprüft:
    // Leerzeichen in einem Passwort sind erlaubt und bedeutungstragend.
    if (address.isEmpty || password.trim().isEmpty) {
      _fail(const SignupInputIncomplete());
      return false;
    }
    if (!termsAccepted) {
      _fail(const SignupTermsNotAccepted());
      return false;
    }
    if (username.isEmpty || blocksSignup(usernameStatus)) {
      _fail(const SignupUsernameUnusable());
      return false;
    }

    state = const AsyncLoading<SignupStatus>();
    final repository = ref.read(authRepositoryProvider);
    try {
      final session = await repository.signUpWithPassword(
        email: address,
        password: password,
        // Die Quelle schickt `username || t('auth.defaultName')`. Der zweite
        // Zweig ist dort toter Code: die Prüfung oben verlangt schon einen
        // Username. Deshalb steht hier kein Rückfalltext, und deshalb liest
        // dieser Notifier keine Übersetzungen.
        name: username,
        hometown: hometown,
      );
      if (!session.isSignedIn) {
        if (ref.mounted) {
          state = const AsyncData<SignupStatus>(
            SignupStatus.emailConfirmationPending,
          );
        }
        return false;
      }
      await repository.setUsername(userId: session.userId!, username: username);
    } catch (error, stackTrace) {
      // Breit gefangen, aber nichts verschluckt: der Vertrag wirft eine
      // `AuthFailure`, alles darüber hinaus ist unerwartet und als sichtbarer
      // Fehlerzustand besser aufgehoben als in einer Zone.
      if (ref.mounted) {
        state = AsyncError<SignupStatus>(error, stackTrace);
      }
      return false;
    }
    if (!ref.mounted) {
      // Der Bildschirm ist weg. Das Konto gibt es trotzdem; der Sitzungsstrom
      // trägt die Anmeldung in `authSessionProvider`.
      return false;
    }
    state = const AsyncData<SignupStatus>(SignupStatus.untouched);
    return true;
  }

  /// Legt einen Eingabefehler in den Fehlerkanal.
  ///
  /// Über den Fehlerkanal und nicht über ein zweites Feld, damit es genau
  /// **eine** Quelle für den Text in der Fehlerbox gibt. Zwei Quellen bräuchten
  /// eine Vorrangregel, und die wäre die nächste Fehlerstelle.
  void _fail(Object error) {
    state = AsyncError<SignupStatus>(error, StackTrace.current);
  }
}
