import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:fact_app/features/identity/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod-Komposition der Sitzung (ADR-005: Riverpod ist der einzige
/// DI-Mechanismus). Handgeschriebene Provider, weil `riverpod_generator` mit
/// diesem Abhängigkeitsstand nicht neben `go_router_builder` auflösbar ist
/// (ADR-003).
///
/// ## Warum das hier liegt und nicht neben der Implementierung
///
/// `tool/check_architecture.dart` verbietet `presentation` jeden Import aus
/// `data`, auch aus dem eigenen Feature. Der Zugang muss also über einen
/// Provider laufen, der auf dem **Domänenvertrag** typisiert ist und die
/// Supabase-Implementierung nicht kennt. Genau das steht hier;
/// `docs/architecture/project-structure.md` deckt es ab: "Feature UI providers
/// live in `presentation`".
///
/// Die Supabase-Implementierung wird nie importiert, sondern in
/// `lib/app/bootstrap.dart` per Override eingesetzt.

/// Der Zugang zur Anmeldung.
///
/// Der Standard ist [unavailableAuthRepository]: **niemand angemeldet, jeder
/// Anmeldeversuch scheitert.** Dass er untätig statt werfend ist, ist dort
/// begründet.
///
/// Kleingeschrieben referenziert, und das ist keine Kosmetik: Regel 7 wird
/// textuell geprüft und meldet in `presentation` jeden Konstruktoraufruf einer
/// Klasse, deren Name auf `Repository`, `DataSource` oder `Client` endet. Ein
/// `const UnavailableAuthRepository()` an dieser Stelle wäre ein Verstoß, mit
/// einer Probe nachgewiesen.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => unavailableAuthRepository,
);

/// Wer gerade angemeldet ist.
///
/// Liest die Weiche in `lib/app/routing/route_guards.dart` über
/// `lib/app/routing/app_router.dart`. Der Zustand ist ein einzelner
/// unveränderlicher Wert, kein `ChangeNotifier` (ADR-003).
final authSessionProvider = NotifierProvider<AuthSessionNotifier, AuthSession>(
  AuthSessionNotifier.new,
);

/// Besitzer des Anmeldezustands.
///
/// ## [build] ist synchron, und das muss so sein
///
/// Dieselbe Begründung wie bei `FirstLaunchNotifier`: die Weiche im Router muss
/// beim **ersten** Redirect antworten. Ein `AsyncNotifier` hier würde jede
/// Route in einen Ladezustand zwingen, und zwar dauerhaft, weil die Weiche
/// keinen Ladezustand kennt: sie müsste raten, und jede Wahl wäre für den
/// halben Zustandsraum falsch.
///
/// Deshalb zwei Wege in einem: der Startwert kommt synchron aus
/// [AuthRepository.currentSession], die Änderungen aus
/// [AuthRepository.sessionChanges].
///
/// ## Hierher gehört das Verwerfen kontobezogener Provider beim Abmelden
///
/// `.claude/rules/supabase.md`: "Prevent account-scoped cache leakage after
/// logout or account changes." Sobald ein Provider kontobezogene Daten hält
/// (Sammlung, Fortschritt, Profil), muss er beim Wechsel von einer Kennung auf
/// eine andere **und** beim Abmelden verworfen werden, sonst sieht der nächste
/// Nutzer die Daten des vorigen. Die Stelle dafür ist [_apply]: dort ist die
/// alte und die neue Kennung bekannt.
///
/// **Für Schritt 9 ist noch nichts kontobezogen**, deshalb steht hier kein
/// `ref.invalidate`. Ein Aufruf, der nichts verwirft, wäre kein halber Schutz,
/// sondern ein falsches Gefühl von Schutz. Wer den ersten kontobezogenen
/// Provider baut, erweitert [_apply] und schreibt einen Test dafür, der zwei
/// Kennungen durchspielt.
class AuthSessionNotifier extends Notifier<AuthSession> {
  /// Name des Diagnose-Ereignisses für einen Fehler auf dem Sitzungsstrom.
  static const String streamErrorEvent = 'identity.auth_session.stream_error';

  @override
  AuthSession build() {
    final repository = ref.watch(authRepositoryProvider);
    // `listen` vor dem Lesen des Startwerts: Streams in Dart liefern nie
    // synchron, es kann also zwischen beidem keine Ausgabe verlorengehen.
    final subscription = repository.sessionChanges().listen(
      _apply,
      onError: _reportStreamError,
    );
    ref.onDispose(subscription.cancel);
    return repository.currentSession();
  }

  void _apply(AuthSession session) {
    // ## Was diese Prüfung wirklich abfängt, gemessen
    //
    // Sie allein überlebt eine Mutation: solange `ref.onDispose` das Abonnement
    // abräumt, wird nach dem Entsorgen kein Ereignis mehr zugestellt, und dieser
    // Zweig läuft nie. Der Schutz greift **in Kombination**: nimmt man das
    // `cancel` weg, erreicht eine bereits eingereihte Ausgabe diesen Rumpf, und
    // ohne die Prüfung wirft das folgende `state =` mit "Cannot use the Ref of
    // NotifierProvider<AuthSessionNotifier, AuthSession> after it has been
    // disposed". Beides ist mit Mutationen belegt.
    //
    // Sie bleibt deshalb stehen: der Strom kommt von außen, seine
    // Zustellgarantien sind nicht unsere, und der Preis ist eine Zeile.
    if (!ref.mounted) {
      return;
    }
    state = session;
  }

  /// Ein Fehler auf dem Strom nimmt die Sitzung **nicht** zurück.
  ///
  /// Der Strom von Supabase meldet unter anderem eine fehlgeschlagene
  /// Token-Erneuerung ohne Netz. Daraus "abgemeldet" zu machen würde einen
  /// Nutzer bei jedem Funkloch aus der App werfen. Der letzte bekannte Stand
  /// bleibt gültig, bis das Backend etwas anderes sagt; wirklich abgemeldet
  /// wird über ein `signedOut`-Ereignis, also über [_apply].
  ///
  /// Gemeldet wird nur der **Typname**. Die Meldung des Vendors kann Interna
  /// tragen, und `cross-cutting-concerns.md` verbietet ganze Backend-Antworten
  /// im Log.
  void _reportStreamError(Object error, StackTrace stackTrace) {
    if (!ref.mounted) {
      return;
    }
    ref
        .read(diagnosticSinkProvider)
        .report(
          DiagnosticEvent(streamErrorEvent, <String, String>{
            'type': error.runtimeType.toString(),
          }),
        );
  }
}
