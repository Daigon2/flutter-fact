import 'package:fact_app/features/identity/data/datasources/remote/auth_remote_data_source.dart';
import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:fact_app/features/identity/domain/repositories/auth_repository.dart';

/// Die Anmeldung, umgesetzt über die Supabase-Datenquelle.
///
/// ## Warum diese Klasse so dünn ist, und warum sie trotzdem existiert
///
/// Sie leitet heute jeden Aufruf durch. Das ist kein Versehen und keine
/// vorsorgliche Schicht "für später": sie ist die Stelle, an der der
/// **Domänenvertrag** erfüllt wird, und diese Stelle darf nicht dieselbe sein
/// wie die, die den Vendor kennt. Sonst gibt es keinen Ort mehr, an dem sich
/// eine zweite Quelle anschließen lässt, ohne die Vendor-Datei anzufassen.
///
/// Konkret erwartet: die Sitzung eines abgemeldeten Starts aus einem lokalen
/// Cache lesen, damit die Weiche im Router beim ersten Frame nicht "abgemeldet"
/// sagt, während Supabase seine gespeicherte Sitzung noch lädt. Das gehört
/// hierher, nicht in die Datenquelle.
///
/// `docs/architecture/project-structure.md`: "Repository implementations live in
/// `data/repositories`."
class SupabaseAuthRepository implements AuthRepository {
  /// [remote] ist die Supabase-Datenquelle.
  SupabaseAuthRepository(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  AuthSession currentSession() => _remote.currentSession();

  @override
  Stream<AuthSession> sessionChanges() => _remote.sessionChanges();

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _remote.signInWithPassword(email: email, password: password);
  }

  @override
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
    required String name,
    required String hometown,
  }) {
    return _remote.signUpWithPassword(
      email: email,
      password: password,
      name: name,
      hometown: hometown,
    );
  }

  @override
  Future<bool> checkUsernameTaken(String username) =>
      _remote.checkUsernameTaken(username);

  @override
  Future<void> setUsername({required String userId, required String username}) {
    return _remote.setUsername(userId: userId, username: username);
  }
}
