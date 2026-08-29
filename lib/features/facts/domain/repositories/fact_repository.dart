import 'package:fact_app/features/facts/domain/entities/fact_batch.dart';
import 'package:fact_app/features/facts/domain/failures/fact_failure.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_query.dart';

/// Zugang zu Fakten.
///
/// Regel 13 aus `docs/architecture/dependency-rules.md`: hier kommen keine
/// DTOs, keine JSON-Karten und kein `AsyncValue` vor. Alles, was durch diesen
/// Vertrag geht, ist ein Domänentyp.
///
/// ## Fehlerbild
///
/// Zwei getrennte Wege, und die Trennung ist der Kern dieses Schritts:
///
/// * **Datenmängel** werfen nicht. Ein unbrauchbares Feld degradiert einen
///   Fakt, ein unbrauchbarer Datensatz fällt aus der Liste, und beides steht
///   in `FactBatch.report`. Die Liste bleibt.
/// * **Infrastrukturfehlschläge** werfen eine `FactFailure`. Es gibt keine
///   halbe Antwort und keinen statischen Ersatzdatensatz. Die Präsentation
///   zeigt einen Fehler an, statt eine leere Karte.
///
/// Warum geworfen und nicht als `Result` geliefert: siehe `FactBatch`.
///
/// ## Sortierung und Seitenbildung
///
/// [fetchFacts] liefert alle passenden Fakten, aufsteigend nach `id`. Es gibt
/// bewusst kein Seitenargument: die PWA lädt die Fakten einer Stadt ebenfalls
/// vollständig, weil Karte und Umgebungssuche sie alle brauchen
/// (`02_Frontend/app/api.jsx:119`). Dass die Datenschicht intern in Häppchen
/// liest, weil PostgREST bei 1000 Zeilen abschneidet, ist ihr Problem und darf
/// sich ändern, ohne diesen Vertrag anzufassen.
abstract interface class FactRepository {
  /// Alle Fakten, die zu [query] passen.
  ///
  /// Wirft [FactFailure], wenn es keine Antwort gab.
  Future<FactBatch> fetchFacts({FactQuery query = FactQuery.all});

  /// Einen einzelnen Fakt nachladen.
  ///
  /// Das Ergebnis ist derselbe `FactBatch`, damit auch hier ein Datenmangel
  /// sichtbar wird. `FactBatch.singleOrNull` ist der bequeme Zugriff, und ein
  /// leeres Ergebnis heißt: nicht gefunden oder nicht sichtbar. Beides ist
  /// kein Fehlschlag, weil die RLS-Policy unveröffentlichte Fakten
  /// erwartungsgemäß verbirgt.
  Future<FactBatch> fetchFactById(FactId id);

  /// Wie [fetchFacts], aber als Strom, der bei Änderungen erneut liefert.
  ///
  /// Die Signatur steht heute, damit Supabase-Realtime später kein Bruch ist:
  /// jede Ausgabe ist ein vollständiger Stand mit eigenem Bericht, genau wie
  /// `SupabaseQueryBuilder.stream` es liefert. Wer eine Ausgabe verpasst, ist
  /// nach der nächsten wieder aktuell.
  ///
  /// **Noch nicht umgesetzt.** Ob Realtime überhaupt kommt, ist die offene
  /// Entscheidung E-09 aus `REBUILD_STATUS.md`, Stufe 3, fällig in Phase 5.
  /// Bis dahin wirft die Supabase-Umsetzung [UnsupportedError]. Ein stiller
  /// Einmal-Strom wäre schlimmer: er sähe live aus und wäre es nicht.
  Stream<FactBatch> watchFacts({FactQuery query = FactQuery.all});
}

/// Der untätige Standard: **es gibt keine Fakten, und jeder Versuch scheitert
/// sichtbar.**
///
/// ## Wozu er da ist
///
/// `features/facts/application/fact_providers.dart` gibt höheren Schichten
/// einen Provider, der auf diesem Vertrag typisiert ist. Der braucht einen
/// Standard, und `lib/app/bootstrap.dart` setzt die Supabase-Fassung per
/// Override ein. Dieselbe Bauform wie `unavailableAuthRepository`, aus
/// derselben Not: `flutter test` hat keinen Plattformkanal, und ein echter
/// Supabase-Client scheiterte dort mit einer `MissingPluginException`.
///
/// ## Warum werfend und nicht leer
///
/// Hier weicht die Bauform von der Anmeldung ab, und zwar bewusst. Eine leere
/// Faktenliste ist eine **plausible Antwort**: eine Stadt ohne Fakten sieht
/// genauso aus. Fehlt der Override, zeigte die App also eine leere Karte, und
/// niemand könnte sie von einer richtigen unterscheiden. Ein Fehlschlag ist
/// dagegen unverwechselbar, und `FactRepository` sagt ausdrücklich: „Die
/// Präsentation zeigt einen Fehler an, statt eine leere Karte."
///
/// [FactBackendUnreachable] und nicht [FactAccessDenied]: es gab gar keine
/// Antwort, weil gar niemand gefragt wurde. Der Code benennt die Ursache, damit
/// eine Diagnose nicht nach einem Netzproblem sucht, das es nicht gibt.
///
/// ## Warum eine Konstante und keine Klasse zum Instanziieren
///
/// Damit Presentation und Application ihn benutzen können. Regel 7 wird
/// textuell geprüft und meldet dort **jeden** Konstruktoraufruf einer Klasse,
/// deren Name auf `Repository`, `DataSource` oder `Client` endet
/// (`tool/check_architecture.dart`). Der kleingeschriebene Name dieser
/// Konstante trifft das Muster nicht.
const FactRepository unavailableFactRepository = _UnavailableFactRepository();

/// Siehe [unavailableFactRepository]. Privat, damit niemand eine zweite Instanz
/// baut und damit den Vergleich `same(unavailableFactRepository)` unterläuft.
final class _UnavailableFactRepository implements FactRepository {
  const _UnavailableFactRepository();

  /// Der Diagnosecode, an dem der fehlende Override zu erkennen ist.
  static const String _code = 'fact_repository_not_configured';

  @override
  Future<FactBatch> fetchFacts({FactQuery query = FactQuery.all}) async {
    throw const FactBackendUnreachable(code: _code);
  }

  @override
  Future<FactBatch> fetchFactById(FactId id) async {
    throw const FactBackendUnreachable(code: _code);
  }

  @override
  Stream<FactBatch> watchFacts({FactQuery query = FactQuery.all}) {
    throw const FactBackendUnreachable(code: _code);
  }
}
