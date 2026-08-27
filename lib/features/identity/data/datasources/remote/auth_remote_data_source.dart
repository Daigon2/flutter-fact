import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';

/// Die Anmeldeschnittstelle des Backends, aus Sicht der Datenschicht.
///
/// Regel 14 aus `docs/architecture/dependency-rules.md`: keine
/// Präsentationsmodelle. Hier gehen ausschließlich Domänentypen durch, und
/// **kein** Vendor-Typ: eine `Session`, ein `AuthResponse` oder eine
/// `AuthException` von Supabase erscheint in diesem Vertrag nicht.
///
/// ## Warum dieser Vertrag anders aussieht als `FactRemoteDataSource`
///
/// Der Fakten-Vertrag liefert `Object?`, also die Rohantwort, weil dort die
/// eigentliche Arbeit im Abbilden von Zeilen liegt und diese Arbeit prüfbar
/// getrennt gehört. Bei der Anmeldung gibt es keine Zeilen: die Antwort ist
/// eine Sitzung, und die einzige Abbildung ist "nimm die Nutzerkennung, lass
/// das Token liegen". Diese eine Zeile in eine eigene Mapper-Datei zu legen
/// würde die Grenze nicht schärfer machen, sondern nur die Zahl der Dateien
/// erhöhen.
abstract interface class AuthRemoteDataSource {
  /// Der aktuelle Anmeldezustand, aus dem Speicher des Clients.
  AuthSession currentSession();

  /// Jede Änderung des Anmeldezustands, inklusive Fehlerereignissen.
  Stream<AuthSession> sessionChanges();

  /// Meldet an. Wirft [AuthFailure].
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  });

  /// Legt ein Konto an. Wirft [AuthFailure].
  ///
  /// Eine abgemeldete Sitzung ist der Bestätigungsfall und **kein** Fehlschlag,
  /// siehe `AuthRepository.signUpWithPassword`.
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
    required String name,
    required String hometown,
  });

  /// `true` heißt vergeben. Wirft [AuthFailure].
  Future<bool> checkUsernameTaken(String username);

  /// Schreibt den Username in das Profil. Wirft [AuthFailure].
  Future<void> setUsername({required String userId, required String username});
}
