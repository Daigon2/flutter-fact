import 'package:fact_app/features/facts/data/datasources/remote/fact_remote_data_source.dart';
import 'package:fact_app/features/facts/domain/failures/fact_failure.dart';
import 'package:fact_app/services/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Liest die `facts`-Tabelle über Supabase.
///
/// ADR-001: Supabase-spezifischer Code ist in der Datenschicht erlaubt und nur
/// dort. Diese Datei ist die einzige im Feature `facts`, die den Vendor-Client
/// überhaupt sieht.
///
/// ## Hier werden Infrastrukturfehler übersetzt
///
/// `cross-cutting-concerns.md`: „Infrastructure exceptions are translated at
/// the data/service boundary." Das passiert an der engsten Stelle, direkt am
/// Vendor-Aufruf, damit eine `PostgrestException` nirgends sonst auftaucht.
/// Weder das Repository noch die Domäne kennen den Typ.
class SupabaseFactRemoteDataSource implements FactRemoteDataSource {
  /// [client] kommt aus `supabaseClientProvider`.
  SupabaseFactRemoteDataSource(this._client);

  /// Name der Tabelle.
  static const String table = 'facts';

  /// PostgREST-Codes, die eine verweigerte Berechtigung bedeuten.
  ///
  /// `42501` ist der SQLSTATE `insufficient_privilege`, den eine abgelehnte
  /// RLS-Policy auslöst. `PGRST301` ist ein abgelaufenes oder fehlendes
  /// JWT. `PGRST302` ist eine fehlgeschlagene Anmeldung an der API.
  static const Set<String> accessDeniedCodes = <String>{
    '42501',
    'PGRST301',
    'PGRST302',
  };

  final SupabaseClient _client;

  @override
  Future<Object?> fetchPublishedFactPage({
    required int offset,
    required int pageSize,
  }) {
    return _translateFailures(
      () => _client
          .from(table)
          .select()
          .eq('is_approved', true)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1),
    );
  }

  @override
  Future<Object?> fetchFactById(int id) {
    return _translateFailures(
      () => _client.from(table).select().eq('id', id).limit(1),
    );
  }

  /// Führt [request] aus und übersetzt jeden Fehlschlag in eine `FactFailure`.
  ///
  /// Die Zuordnung ist absichtlich grob und dafür ehrlich:
  ///
  /// * `PostgrestException` mit einem Code aus [accessDeniedCodes] und jede
  ///   `AuthException` werden `FactAccessDenied`.
  /// * Jede andere `PostgrestException` wird `FactRequestRejected`: falsche
  ///   Spalte, verschobenes Schema, kaputter Filter. Wiederholen hilft nicht.
  /// * Alles übrige wird `FactBackendUnreachable`, mit Stacktrace.
  ///
  /// Warum der letzte Fall so breit ist: „offline" von „Server kaputt" zu
  /// trennen bräuchte ein Konnektivitätssignal, und ein Paket dafür ist eine
  /// Entscheidung der Stufe 3. Zu raten wäre schlechter, weil die Präsentation
  /// aus der Unterscheidung eine Handlungsempfehlung ableitet.
  ///
  /// Was **nicht** mitgenommen wird: die Fehlermeldung des Backends. Sie kann
  /// Spaltennamen und Bruchstücke der Anfrage enthalten, und `security.md`
  /// verlangt, dass Backend-Details den Nutzer nicht erreichen. Der Code
  /// genügt zur Diagnose.
  static Future<Object?> _translateFailures(
    Future<Object?> Function() request,
  ) async {
    try {
      return await request();
    } on PostgrestException catch (error, stackTrace) {
      final code = error.code;
      if (code != null && accessDeniedCodes.contains(code)) {
        throw FactAccessDenied(code: code, stackTrace: stackTrace);
      }
      throw FactRequestRejected(code: code, stackTrace: stackTrace);
    } on AuthException catch (error, stackTrace) {
      throw FactAccessDenied(code: error.statusCode, stackTrace: stackTrace);
    } catch (error, stackTrace) {
      throw FactBackendUnreachable(
        code: error.runtimeType.toString(),
        stackTrace: stackTrace,
      );
    }
  }
}

/// Die Datenquelle für Fakten.
///
/// Regel 7: Widgets und Notifier bauen sich das nicht selbst zusammen, sie
/// beziehen es über einen Provider (ADR-005). Der Provider steht neben der
/// Implementierung, die er bereitstellt.
final factRemoteDataSourceProvider = Provider<FactRemoteDataSource>(
  (ref) => SupabaseFactRemoteDataSource(ref.watch(supabaseClientProvider)),
);
