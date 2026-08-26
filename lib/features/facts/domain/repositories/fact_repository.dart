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
