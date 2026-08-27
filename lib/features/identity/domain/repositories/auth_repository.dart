import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';

/// Zugang zur Anmeldung.
///
/// Regel 13 aus `docs/architecture/dependency-rules.md`: keine DTOs, keine
/// JSON-Karten, kein `AsyncValue`. Alles, was durch diesen Vertrag geht, ist ein
/// Domänentyp. Dass die Datei unter `domain/repositories/` liegt, ist deshalb
/// nicht Geschmack: `tool/check_architecture.dart` prüft Regel 13 an genau
/// diesem Pfadsegment. Flach in `domain/` abgelegt wäre der Vertrag für die
/// Prüfung unsichtbar.
///
/// ## Warum [currentSession] synchron ist
///
/// Dieselbe Begründung wie bei `FirstLaunchStore.hasLaunched`: die Weiche in
/// `lib/app/routing/route_guards.dart` muss beim **ersten** Redirect antworten
/// können. Ein `Future` hier würde jede Route in einen Ladezustand zwingen,
/// obwohl der Wert beim ersten Frame längst feststeht. Supabase hält die
/// Sitzung nach dem Start im Speicher, das Lesen kostet nichts.
///
/// ## Fehlerbild
///
/// [signInWithPassword] wirft eine [AuthFailure] und liefert **nie** eine
/// abgemeldete Sitzung als Ersatz. "Zugangsdaten falsch" ist dabei ein
/// erwarteter Ausgang, siehe die Begründung in `auth_failure.dart`.
///
/// [sessionChanges] wirft nicht. Ein Fehler auf dem Strom, etwa eine
/// fehlgeschlagene Token-Erneuerung ohne Netz, wird als Fehlerereignis
/// zugestellt; der letzte bekannte Stand bleibt gültig, bis das Backend etwas
/// anderes sagt.
///
/// ## Was hier absichtlich fehlt
///
/// **Abmelden.** Gehört zu Schritt 20 und kommt mit dem Profil. Eine Methode
/// hier zu deklarieren, die niemand aufruft, wäre ein Vertrag ohne
/// Implementierungsdruck.
///
/// **Passwort zurücksetzen.** Siehe die Begründung in
/// `presentation/pages/login_page.dart`: das Ziel des Rücksetz-Links wäre eine
/// neue öffentliche Vertragsfläche (Deep Link), und der PKCE-Ablauf von
/// `supabase_flutter` macht einen im Browser geöffneten Link unbrauchbar.
abstract interface class AuthRepository {
  /// Der aktuelle Anmeldezustand, sofort und ohne Netz.
  AuthSession currentSession();

  /// Jede Änderung des Anmeldezustands.
  ///
  /// Liefert auch den Startzustand, sobald das Backend ihn kennt. Ausgaben mit
  /// unveränderter Kennung sind erlaubt und normal (Token-Erneuerung); wer sie
  /// nicht mag, verlässt sich auf `AuthSession ==`.
  Stream<AuthSession> sessionChanges();

  /// Meldet mit E-Mail-Adresse und Passwort an.
  ///
  /// Liefert die entstandene Sitzung. Wirft [AuthFailure], wenn die Anmeldung
  /// nicht zustande kommt.
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  });

  /// Erstellt ein Konto, `02_Frontend/app/api.jsx:46-54` (`Api.signUp`).
  ///
  /// ## Eine abgemeldete Sitzung ist hier **kein** Fehlschlag
  ///
  /// Anders als bei [signInWithPassword]. Verlangt das Supabase-Projekt eine
  /// E-Mail-Bestätigung, dann ist das Konto angelegt, aber niemand angemeldet;
  /// GoTrue liefert dafür eine Antwort **ohne** Sitzung, statt zu werfen. Genau
  /// dieser Fall ist der Rückgabewert `AuthSession.signedOut()`, und der
  /// Aufrufer muss ihn behandeln: die Registrierung zeigt dann den Hinweis
  /// `signup.confirmEmailHint`. Ein Fehlschlag kommt als [AuthFailure].
  ///
  /// ## [name] und [hometown] sind **nicht vertrauenswürdig**
  ///
  /// Beide landen in `auth.users.raw_user_meta_data` (`options.data` in der
  /// Quelle). Dieses Feld ist vom Client frei beschreibbar, jeder angemeldete
  /// Nutzer kann es über `updateUser` beliebig ändern. Wer daraus später eine
  /// Anzeige, eine Berechtigung oder eine Stadt-Zuordnung ableitet, baut auf
  /// Nutzereingaben ohne Prüfung. Verlässlich ist nur, was serverseitig
  /// geschrieben wird.
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
    required String name,
    required String hometown,
  });

  /// Ob [username] schon vergeben ist,
  /// `02_Frontend/app/api.jsx:246-249` (`Api.checkUsername`).
  ///
  /// `true` heißt **vergeben**, wie der Rückgabewert der RPC `check_username`.
  ///
  /// ## Warum das hier steht und nicht in einem eigenen Vertrag
  ///
  /// Weil es Teil des Registriervorgangs ist, und den besitzt `identity`
  /// (`lib/features/README.md:12`). Ein zweiter Vertrag für zwei Methoden hätte
  /// eine zweite Verdrahtung in `bootstrap.dart` und einen zweiten Standard
  /// gebraucht, ohne eine Grenze zu ziehen, die es fachlich gibt.
  ///
  /// **Notiz für Phase 7:** das *Ändern* eines bestehenden Usernames gehört
  /// **nicht** hierher, sondern zu `features/profile`, das laut
  /// `lib/features/README.md:21` den Anzeigenamen besitzt. Dort hängt mehr
  /// dran: `Api.setUsername` kennt ein `isChange`-Flag, das
  /// `username_changed_at` setzt, und die PWA leitet daraus eine einmalige
  /// Änderung samt Sperrfrist ab (`username.change`, `username.cooldown`,
  /// `username.locked`). Diese Schlüssel bleiben in Schritt 10 ungenutzt.
  Future<bool> checkUsernameTaken(String username);

  /// Schreibt [username] in das Profil von [userId],
  /// `02_Frontend/app/api.jsx:253-258` (`Api.setUsername`).
  ///
  /// Wirft [AuthFailure], wenn das Schreiben scheitert. Der Aufrufer darf den
  /// Fehler **nicht** verschlucken: die Quelle tut das
  /// (`.catch(() => {})`, `screen-auth.jsx:632`), und der Nutzer führt danach
  /// einen Namen im Kopf, den niemand gespeichert hat.
  Future<void> setUsername({required String userId, required String username});
}

/// Der Standard, solange niemand eine echte Anmeldung eingesetzt hat:
/// **niemand ist angemeldet, jeder Anmeldeversuch scheitert.**
///
/// ## Warum untätig und nicht werfend
///
/// Ein Standard, der beim ersten Zugriff wirft (so wie
/// `supabaseClientProvider`), reißt jeden Widget-Test mit, der `/login` bloß
/// rendert, und würde in einem Build ohne `--dart-define` die halbe App
/// lahmlegen. Dieser Standard fällt stattdessen zur sicheren Seite aus: er kann
/// keinen angemeldeten Nutzer erfinden, ist also in der sicherheitsrelevanten
/// Richtung genauso streng wie eine Ausnahme, und ein Anmeldeversuch endet
/// sichtbar in [AuthBackendUnavailable] statt stillschweigend in Nichts.
///
/// Präzedenz: `SilentDiagnosticSink` in `lib/core/diagnostics/`. Dieselbe
/// Bauform, dieselbe Begründung.
///
/// **Das Netz darunter ist ein Test**, der zusichert, dass die Override-Liste
/// in `lib/app/bootstrap.dart` `authRepositoryProvider` enthält. Ohne den wäre
/// ein stiller Standard genau das, wovor
/// `services/supabase/supabase_providers.dart` warnt: aus einem Startfehler
/// würde eine App, in der sich niemand anmelden kann, ohne dass jemand erfährt
/// warum.
///
/// ## Warum eine Konstante und keine Klasse zum Instanziieren
///
/// Damit die Presentation ihn benutzen kann. `tool/check_architecture.dart`
/// meldet in `presentation` und `application` jeden Konstruktoraufruf einer
/// Klasse, deren Name auf `Repository`, `DataSource` oder `Client` endet
/// (Regel 7, Muster in `tool/check_architecture.dart:354`). Ein
/// `Provider<AuthRepository>((ref) => const UnavailableAuthRepository())` wäre
/// damit ein Verstoß, empirisch nachgewiesen mit einer Probe. Der
/// kleingeschriebene Name dieser Konstante trifft das Muster nicht, und es gibt
/// keinen Konstruktoraufruf.
const AuthRepository unavailableAuthRepository = _UnavailableAuthRepository();

/// Siehe [unavailableAuthRepository]. Privat, damit niemand eine zweite Instanz
/// baut und damit den Vergleich `same(unavailableAuthRepository)` in Tests
/// unterläuft.
final class _UnavailableAuthRepository implements AuthRepository {
  const _UnavailableAuthRepository();

  @override
  AuthSession currentSession() => const AuthSession.signedOut();

  /// Ein leerer Strom, der nie etwas liefert und sich sofort schließt.
  ///
  /// Nicht `Stream.never()`: ein Strom, der offen bleibt, hält in Tests
  /// Abonnements am Leben, die nie etwas zu sagen haben.
  @override
  Stream<AuthSession> sessionChanges() => const Stream<AuthSession>.empty();

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    throw _notConfigured;
  }

  @override
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
    required String name,
    required String hometown,
  }) async {
    throw _notConfigured;
  }

  /// Wirft, statt "frei" oder "vergeben" zu behaupten.
  ///
  /// Beide Antworten wären eine Lüge, und die zweite die schlechtere: sie
  /// zeigte am Feld "Bereits vergeben" für einen Namen, den niemand hat. Der
  /// Aufrufer bildet die Ausnahme auf `idle` ab, genau wie bei einer
  /// unerreichbaren Prüfung in der Quelle; sichtbar wird der Fehlschlag dann
  /// beim Registrieren.
  @override
  Future<bool> checkUsernameTaken(String username) async {
    throw _notConfigured;
  }

  @override
  Future<void> setUsername({
    required String userId,
    required String username,
  }) async {
    throw _notConfigured;
  }

  static const AuthBackendUnavailable _notConfigured = AuthBackendUnavailable(
    code: 'auth_repository_not_configured',
  );
}
