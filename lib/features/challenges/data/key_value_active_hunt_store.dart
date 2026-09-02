import 'dart:convert';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/features/challenges/domain/active_hunt_store.dart';
import 'package:fact_app/features/challenges/domain/entities/active_hunt.dart';

/// [ActiveHuntStore] auf dem Gerätespeicher.
///
/// Der Ort ist von ADR-007 vorgegeben („the persistent implementation lives in
/// `challenges/data`"), und dies ist der Speicher, bei dem das flüchtige
/// Verhalten nicht bloß unbequem, sondern **falsch** war: eine laufende Jagd
/// überlebt ab jetzt, dass das Betriebssystem die App während des Spaziergangs
/// abräumt. Genau das ist die Produktvorgabe, an der ADR-007 hängt, und die
/// Quelle hat sie schon einmal bezahlt („FIX (Daniel-Feedback): App-Crash mitten
/// in Challenge soll Spielstand nicht verlieren", `app.jsx:86-88`).
///
/// Schlüsselname wie in der Quelle (`fact_active_challenge`,
/// `storage.jsx:190-192`), als Nachvollziehbarkeit und nicht als gemeinsame
/// Nutzung.
///
/// ## Drei Handgriffe, und keine zweite Gültigkeitsprüfung
///
/// Der Vertrag schreibt die Bauform vor: „Schlüssel lesen, `jsonDecode`, dieses
/// [ActiveHunt.tryFromPayload]. Sie enthält **keine** eigene Prüfung, sonst gäbe
/// es zwei Orte, an denen ‚gültig' definiert ist." Genau so steht es unten.
///
/// Das `try` um `jsonDecode` ist kein Verstoß dagegen, sondern der vom Vertrag
/// benannte Fall: „wenn sie trotzdem eines will, dann für den Gerätespeicher und
/// nicht für die Nutzlast". Eine Zeichenkette, die kein JSON ist, ist ein
/// Defekt des Speichers und keine ungültige Jagd.
///
/// ## Was diese Umsetzung nicht prüft
///
/// Ob der Fakt hinter der Station noch existiert. ADR-007 nennt das
/// ausdrücklich, und es braucht den aktuellen Faktenbestand, den weder eine
/// Domäne noch dieser Speicher sieht. Diese zweite Stufe gehört zur
/// Wiederherstellung in Schritt 36. **Wer sie vergisst, bekommt keine Ausnahme,
/// sondern eine Jagd zu einem Ort, den es nicht mehr gibt.**
final class KeyValueActiveHuntStore implements ActiveHuntStore {
  /// [store] ist der geladene Gerätespeicher aus `bootstrap()`, [sink] nimmt
  /// eine verworfene Nutzlast auf.
  const KeyValueActiveHuntStore(
    this._store, {
    this._sink = const SilentDiagnosticSink(),
  });

  /// Schlüssel im Gerätespeicher, wie in der Quelle.
  static const String storageKey = 'fact_active_challenge';

  /// Name des Ereignisses, mit dem eine verworfene Nutzlast gemeldet wird.
  ///
  /// Steht als Konstante da, damit ein Test ihn nicht ein zweites Mal tippt.
  static const String discardedEventName = 'challenges.hunt_payload_discarded';

  final KeyValueStore _store;
  final DiagnosticSink _sink;

  /// Die gespeicherte Jagd, oder `null`.
  ///
  /// Der Vertrag verlangt, dass `null` beide Fälle deckt, „keine gespeichert"
  /// und „gespeicherte war unlesbar", und dass wer sie unterscheiden will das
  /// über die Diagnosesenke tut. Genau das passiert hier: der Rückgabewert
  /// unterscheidet nicht, die Senke schon.
  ///
  /// Gemeldet wird nur der **zweite** Fall. Ein leerer Schlüssel ist der
  /// Normalzustand jedes Nutzers, der gerade keine Jagd läuft; ihn zu melden
  /// hieße, die Senke bei jedem Start mit einer Nichtmeldung zu füllen.
  @override
  ActiveHunt? readActiveHunt() {
    final String? raw = _store.readString(storageKey);
    if (raw == null) {
      return null;
    }
    final ActiveHunt? hunt = ActiveHunt.tryFromPayload(_tryDecode(raw));
    if (hunt == null) {
      _sink.report(DiagnosticEvent(discardedEventName));
    }
    return hunt;
  }

  /// Speichert [hunt] als JSON.
  ///
  /// Ohne `try`, und das ist geprüft und nicht gehofft: `jsonEncode` auf
  /// [ActiveHunt.toPayload] kann nicht scheitern, weil der Konstruktor von
  /// [ActiveHunt] privat ist und keine nicht-endliche Lage durchlässt. Der
  /// Vertrag von [KeyValueStore.writeString] verschluckt den Rest.
  @override
  Future<void> writeActiveHunt(ActiveHunt hunt) =>
      _store.writeString(storageKey, jsonEncode(hunt.toPayload()));

  @override
  Future<void> clearActiveHunt() => _store.remove(storageKey);

  /// Der entschlüsselte Rohwert, oder `null`, wenn [raw] kein JSON ist.
  ///
  /// Der Rückgabewert `null` läuft in [ActiveHunt.tryFromPayload] und wird dort
  /// verworfen, wie jede andere unpassende Nutzlast. Deshalb gibt es hier keine
  /// eigene Meldung: die eine oben deckt beide Wege ab.
  Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
