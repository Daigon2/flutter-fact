import 'dart:async';

import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:fact_app/features/identity/domain/repositories/auth_repository.dart';

/// Steuerbarer Ersatz für [AuthRepository].
///
/// Ein Fake und kein Mock: `docs/engineering/testing.md` §5 verlangt für
/// Repositories und zustandstragende Mitspieler einen Fake. Er zählt Aufrufe,
/// weil die Zahl an einer Stelle Verhalten ist (ein gesperrter Knopf darf
/// `signIn` nicht zweimal starten), aber er prüft keine Aufrufreihenfolgen.
///
/// Liegt beim besitzenden Feature, wie es `testing.md` §Fixtures verlangt.
class FakeAuthRepository implements AuthRepository {
  /// [initial] ist der Zustand, den [currentSession] vor der ersten Ausgabe
  /// liefert.
  FakeAuthRepository({AuthSession initial = const AuthSession.signedOut()})
    : _current = initial;

  final StreamController<AuthSession> _sessions =
      StreamController<AuthSession>.broadcast();

  AuthSession _current;

  /// Was [signInWithPassword] wirft, oder `null` für Erfolg.
  AuthFailure? failure;

  /// Kennung, die eine erfolgreiche Anmeldung liefert.
  String userId = 'user-1';

  /// Solange gesetzt und nicht erfüllt, hängt [signInWithPassword]. Damit ist
  /// der Ladezustand prüfbar, ohne mit Zeit zu arbeiten
  /// (`testing.md`: "Do not use arbitrary delays").
  Completer<void>? gate;

  /// Wie oft [signInWithPassword] gerufen wurde.
  int signInCount = 0;

  /// Was [signUpWithPassword] wirft, oder `null` für Erfolg.
  AuthFailure? signUpFailure;

  /// Ob die Registrierung eine Sitzung liefert.
  ///
  /// `false` ist der Bestätigungsfall: das Konto ist angelegt, niemand ist
  /// angemeldet. Der Vertrag liefert dafür eine abgemeldete Sitzung, statt zu
  /// werfen.
  bool signUpCreatesSession = true;

  /// Wie [gate], nur für [signUpWithPassword].
  Completer<void>? signUpGate;

  /// Wie oft [signUpWithPassword] gerufen wurde.
  int signUpCount = 0;

  /// Womit [signUpWithPassword] zuletzt gerufen wurde.
  String? lastSignUpEmail;

  /// Siehe [lastSignUpEmail].
  String? lastSignUpPassword;

  /// Siehe [lastSignUpEmail]. Prüft, dass der Username als Name mitgeht.
  String? lastSignUpName;

  /// Siehe [lastSignUpEmail]. Prüft, dass die gewählte Stadt mitgeht.
  String? lastSignUpHometown;

  /// Die Antwort von [checkUsernameTaken]. `true` heißt vergeben.
  bool usernameTaken = false;

  /// Was [checkUsernameTaken] wirft, oder `null` für eine Antwort.
  AuthFailure? checkUsernameFailure;

  /// Wie [gate], nur für [checkUsernameTaken].
  Completer<void>? checkUsernameGate;

  /// Jeder geprüfte Wert, in der Reihenfolge der Aufrufe.
  ///
  /// Eine Liste und kein Zähler: bei der Prüfung mit Verzögerung ist die
  /// **Zahl** der Aufrufe Verhalten (vor Ablauf keiner, danach genau einer), und
  /// bei einem Wettlauf zusätzlich, **welcher** Wert geprüft wurde.
  final List<String> checkedUsernames = <String>[];

  /// Was [setUsername] wirft, oder `null` für Erfolg.
  AuthFailure? setUsernameFailure;

  /// Wie oft [setUsername] gerufen wurde.
  int setUsernameCount = 0;

  /// Womit [setUsername] zuletzt gerufen wurde.
  String? lastSetUsernameUserId;

  /// Siehe [lastSetUsernameUserId].
  String? lastSetUsernameValue;

  /// Womit zuletzt gerufen wurde. Prüft, dass die Adresse getrimmt und das
  /// Passwort **nicht** getrimmt ankommt.
  String? lastEmail;

  /// Siehe [lastEmail].
  String? lastPassword;

  /// Ob noch jemand am Sitzungsstrom hängt. Zeigt, ob `ref.onDispose` das
  /// Abonnement wirklich abgeräumt hat.
  bool get hasSessionListeners => _sessions.hasListener;

  /// Schickt [session] über den Strom, wie Supabase es bei
  /// `onAuthStateChange` tut.
  void emit(AuthSession session) {
    _current = session;
    _sessions.add(session);
  }

  /// Schickt einen Fehler über den Strom, wie der Vendor es bei einer
  /// fehlgeschlagenen Token-Erneuerung tut.
  void emitError(Object error) => _sessions.addError(error);

  /// Schließt den Strom. Für [close_sinks] und damit kein Test einen offenen
  /// Controller hinterlässt.
  Future<void> close() => _sessions.close();

  @override
  AuthSession currentSession() => _current;

  @override
  Stream<AuthSession> sessionChanges() => _sessions.stream;

  /// Wie oft [checkUsernameTaken] gerufen wurde.
  int get checkUsernameCount => checkedUsernames.length;

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCount++;
    lastEmail = email;
    lastPassword = password;
    final open = gate;
    if (open != null) {
      await open.future;
    }
    final problem = failure;
    if (problem != null) {
      throw problem;
    }
    final session = AuthSession.signedIn(userId: userId);
    emit(session);
    return session;
  }

  @override
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
    required String name,
    required String hometown,
  }) async {
    signUpCount++;
    lastSignUpEmail = email;
    lastSignUpPassword = password;
    lastSignUpName = name;
    lastSignUpHometown = hometown;
    final open = signUpGate;
    if (open != null) {
      await open.future;
    }
    final problem = signUpFailure;
    if (problem != null) {
      throw problem;
    }
    if (!signUpCreatesSession) {
      // Kein `emit`: es ist niemand angemeldet, der Sitzungsstrom hat nichts zu
      // melden.
      return const AuthSession.signedOut();
    }
    final session = AuthSession.signedIn(userId: userId);
    emit(session);
    return session;
  }

  @override
  Future<bool> checkUsernameTaken(String username) async {
    checkedUsernames.add(username);
    final open = checkUsernameGate;
    if (open != null) {
      await open.future;
    }
    final problem = checkUsernameFailure;
    if (problem != null) {
      throw problem;
    }
    return usernameTaken;
  }

  @override
  Future<void> setUsername({
    required String userId,
    required String username,
  }) async {
    setUsernameCount++;
    lastSetUsernameUserId = userId;
    lastSetUsernameValue = username;
    final problem = setUsernameFailure;
    if (problem != null) {
      throw problem;
    }
  }
}
