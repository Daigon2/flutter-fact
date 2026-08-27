import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Anmeldevorgang, `screen-auth.jsx:459-479` (`handleLogin`).
///
/// ## Was dieser Notifier nicht tut
///
/// **Navigieren.** Regel 12 aus `docs/architecture/dependency-rules.md`.
/// [signIn] liefert nur, ob es geklappt hat; wohin es danach geht, entscheidet
/// `LoginPage`.
///
/// **Die Erstlauf-Merkung setzen.** Die gehört zu `firstLaunchProvider`, und
/// der Aufrufer weiß, in welcher Reihenfolge er beides braucht.
///
/// ## Warum der Zustand `AsyncValue<void>` ist
///
/// Der Bildschirm braucht aus diesem Vorgang genau zwei Dinge: läuft er gerade
/// (Knopf gesperrt, Beschriftung `onboarding.loading`), und ist er gescheitert
/// (Fehlerbox). Das ist `AsyncLoading` und `AsyncError`, also genau das, was ein
/// `AsyncNotifier` liefert. Ein eigener sealed Zustandstyp hätte hier nichts
/// hinzugefügt, das nicht schon einen Namen hat.
///
/// Kein Erfolgszustand: der Erfolg ist ein **Ereignis**, keine Eigenschaft des
/// Bildschirms. Er führt sofort weg, und ein Zustand, den man nur im
/// Vorbeigehen sieht, verleitet dazu, in `build` zu navigieren.
///
/// ## Der Notifier wird beim Verlassen des Bildschirms verworfen
///
/// `isAutoDispose: true`, absichtlich. Zwei Wirkungen, beide gewollt:
///
/// 1. Wer die Anmeldung verlässt und später wiederkommt, sieht keine alte
///    Fehlermeldung.
/// 2. Ein Wegnavigieren **während** eines laufenden `signIn` entsorgt den
///    Notifier, während das `Future` noch läuft. Genau dafür stehen die
///    `ref.mounted`-Prüfungen unten: ohne sie wirft das `state =` danach, und
///    zwar in einer abgekoppelten Zone, in der es niemand sieht außer dem
///    Test-Framework. Der Fall hat einen eigenen Test.
final loginProvider = AsyncNotifierProvider<LoginNotifier, void>(
  LoginNotifier.new,
  isAutoDispose: true,
);

/// Die Anmeldung ist ohne vollständige Eingabe versucht worden.
///
/// Steht in `presentation`, weil es keine Domänenregel ist: die PWA prüft in
/// `screen-auth.jsx:460` nur, dass beide Felder nicht leer sind. **Keine
/// Formatprüfung der E-Mail-Adresse und keine Mindestlänge des Passworts**, und
/// das wird hier nicht "verbessert": eine strengere Prüfung im Client würde
/// Konten aussperren, die der Server akzeptiert.
///
/// Reist im Fehlerkanal von [LoginNotifier] mit, damit es nur **eine** Quelle
/// für den Text in der Fehlerbox gibt. Zwei Quellen (eine im Bildschirm, eine im
/// Notifier) bräuchten eine Vorrangregel, und die wäre die nächste Fehlerstelle.
final class LoginInputIncomplete implements Exception {
  /// Erzeugt den Fehlschlag.
  const LoginInputIncomplete();

  @override
  String toString() => 'LoginInputIncomplete()';
}

/// Besitzer des Anmeldevorgangs.
class LoginNotifier extends AsyncNotifier<void> {
  @override
  void build() {
    // Kein Ladezustand beim Öffnen: der Bildschirm wartet auf eine Eingabe.
    // Synchrone Rückgabe heißt in Riverpod 3 sofort `AsyncData`
    // (`element.dart:219`), also kein einmaliges Aufblitzen des gesperrten
    // Knopfes.
  }

  /// Meldet an und liefert, ob es geklappt hat.
  ///
  /// Die Eingabeprüfung entspricht der Quelle: beide Felder dürfen nach
  /// `trim()` nicht leer sein, sonst [LoginInputIncomplete]. Gesendet wird die
  /// **getrimmte** Adresse und das **ungetrimmte** Passwort, genau wie
  /// `screen-auth.jsx:465`: Leerzeichen in einem Passwort sind erlaubt und
  /// bedeutungstragend.
  ///
  /// Ein laufender Vorgang wird nicht zweimal gestartet. In der Quelle
  /// verhindert das der gesperrte Knopf; hier steht es zusätzlich hier, weil ein
  /// Knopf nicht der Ort für eine Invariante ist.
  Future<bool> signIn({required String email, required String password}) async {
    if (state.isLoading) {
      return false;
    }
    final address = email.trim();
    if (address.isEmpty || password.trim().isEmpty) {
      state = AsyncError<void>(
        const LoginInputIncomplete(),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncLoading<void>();
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithPassword(email: address, password: password);
    } catch (error, stackTrace) {
      // Breit gefangen, aber nichts verschluckt: der Vertrag wirft eine
      // `AuthFailure`, und alles darüber hinaus ist ein unerwarteter Fehler, der
      // als sichtbarer Fehlerzustand besser aufgehoben ist als in einer Zone.
      // `auth_failure_text.dart` bildet ihn auf `onboarding.errGeneric` ab.
      if (ref.mounted) {
        state = AsyncError<void>(error, stackTrace);
      }
      return false;
    }
    if (!ref.mounted) {
      // Der Bildschirm ist weg. Die Anmeldung selbst ist trotzdem passiert; der
      // Sitzungsstrom trägt sie in `authSessionProvider`.
      return false;
    }
    state = const AsyncData<void>(null);
    return true;
  }
}
