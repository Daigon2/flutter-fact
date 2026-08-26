/// Der Lesezugang zur `facts`-Tabelle, so schmal wie möglich.
///
/// `docs/engineering/api-and-domain-design.md`: „remote data source speaks
/// Supabase/API language". Diese Schnittstelle spricht also von Seiten und
/// Zeilen und nicht von Fakten.
///
/// ## Warum der Rückgabetyp `Object?` ist
///
/// Nicht aus Faulheit, sondern weil es die Wahrheit ist. Was am Ende einer
/// HTTP-Verbindung ankommt, ist nicht typisiert, und jede Zusage in dieser
/// Signatur wäre eine, die nur der Mapper prüfen kann. Ein `List<Map<String,
/// dynamic>>` hier würde die Prüfung „ist das überhaupt eine Liste" an eine
/// Stelle verschieben, an der sie mit einem Cast-Fehler endet, statt mit einem
/// Befund. Genau das war die Falle im alten Port.
///
/// Der Aufrufer ist deshalb gezwungen, den Mapper zu benutzen. Er kann mit
/// einem `Object?` nichts anderes anfangen.
abstract interface class FactRemoteDataSource {
  /// Eine Seite veröffentlichter Fakten, aufsteigend nach `id`.
  ///
  /// Wirft eine `FactFailure`, wenn das Backend nicht geantwortet hat. Eine
  /// leere oder unerwartet geformte Antwort ist **kein** Fehlschlag und kommt
  /// unverändert zurück.
  Future<Object?> fetchPublishedFactPage({
    required int offset,
    required int pageSize,
  });

  /// Ein einzelner Fakt, ohne Filter auf den Veröffentlichungszustand.
  ///
  /// Ohne Filter, weil die RLS-Policy „read facts" das schon entscheidet: sie
  /// gibt freigegebene Fakten allen und unfreigegebene nur dem Ersteller. Ein
  /// zusätzlicher Client-Filter würde einem Autor seinen eigenen, noch nicht
  /// freigegebenen Fakt verbergen. Autorisierung bleibt beim Server
  /// (`security.md` §1).
  Future<Object?> fetchFactById(int id);
}
