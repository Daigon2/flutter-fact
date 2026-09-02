/// Vertrag für die Liste der Fakten, die dieser Nutzer eingesammelt hat.
///
/// ## Warum dieser Speicher der sechste ist und warum er gefehlt hat
///
/// Seit Schritt 20 kann man auf der Karte sammeln, und seither passierte
/// dabei **nichts, das den nächsten Start überlebt**. `MapPage` meldete das
/// Ereignis an die Diagnosesenke und das war alles, nachzulesen an
/// `MapPage.unbookedCollectEvent`. Zwei Dinge hingen daran:
///
///  1. **Das automatische Sammeln der Quelle war nicht baubar.**
///     `scanAutoOpenRef` (`screen-map.jsx:1471-1489`) sucht den nächsten Fakt,
///     der **noch nicht gesammelt** ist. Ohne diese Liste gibt es das Wort
///     „noch nicht" nicht, und der Scan würde denselben Fakt bei jeder Ortung
///     erneut einsammeln.
///  2. Alles, was später auf der Sammlung aufbaut, hätte dieselbe Lücke
///     gefunden: der Reiseführer aus Schritt 45, die Trophäen aus Schritt 49
///     und die Erfahrungspunkte, die die Quelle aus `collected.length`
///     rechnet (`storage.jsx:226`).
///
/// ## Was hier ausdrücklich **nicht** passiert: Münzen
///
/// Sammeln und Belohnen sind in der Quelle eine Zeile auseinander
/// (`Storage.collectFact(id)` und `Storage.addCoins(50)`, `app.jsx:709-712`)
/// und im Neubau zwei verschiedene Dinge. `docs/engineering/security.md` und
/// die Antwort zu E-19 legen fest: **der Client bestimmt nie einen
/// gutgeschriebenen Betrag.** Dieser Speicher hält deshalb nur, *was*
/// gesammelt wurde, nie *wofür wie viel gutgeschrieben* wurde. Die Buchung
/// gehört an den Server, samt der Regel von Janek vom 02.09.2026: je Nutzer
/// und Fakt zwei Anlässe (einmal beim Sammeln, einmal beim Finden in einer
/// Jagd), jeder genau einmal für immer.
///
/// ## Und er ist nicht die Wahrheit, sondern deren Zwischenspeicher
///
/// Die Antwort zu E-49 lautet „der Server ist die einzige Wahrheit". Für die
/// Sammlung heißt das: die Tabelle `collected_facts` entscheidet, dieser
/// Speicher überbrückt. Er ist damit dasselbe wie `localStorage` in der
/// Quelle, die parallel `Api.collectFact(userId, id)` ruft
/// (`app.jsx:714`). **Der Abgleich ist noch nicht gebaut**, und er ist auch
/// nicht OD-002: das ist die lokale Datenbank für die Offline-Sammlung, und
/// `ADR-007` grenzt sie ausdrücklich gegen kleine Präferenzwerte ab. Hier
/// liegt eine Liste von Zahlen.
///
/// ## Lesen ist synchron, wie bei den fünf Speichern davor
///
/// Aus demselben Grund: die erste Entscheidung fällt beim ersten Bild. Die
/// Kartenüberlagerung muss beim Aufbau wissen, welche Ballons schon
/// gesammelt sind, und ein `Future` zwänge sie in einen Ladezustand, den es
/// dort nicht gibt. Wer persistiert, lädt in `bootstrap()` vor und
/// überschreibt den Provider mit einer gefüllten Umsetzung.
library;

import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';

/// Die eingesammelten Fakten dieses Nutzers.
///
/// Die Reihenfolge ist die des Einsammelns und trägt Bedeutung: die Quelle
/// liest den **letzten** Eintrag, um nach dem Sammeln das Tour-Rätsel des
/// gerade gefundenen Fakts nachzuschieben (`collectedFacts[length - 1]`,
/// `screen-map.jsx:1514`). Ein `Set` wäre also die falsche Form, obwohl sich
/// die Frage „schon gesammelt?" damit schneller beantworten ließe.
abstract interface class CollectedFactsStore {
  /// Alle gesammelten Fakten in der Reihenfolge des Einsammelns.
  ///
  /// Doppelte Einträge kommen nicht vor, siehe [collectFact]. Eine Umsetzung
  /// gibt eine Liste zurück, die der Aufrufer nicht verändern kann.
  List<FactId> readCollectedFacts();

  /// Nimmt [factId] auf, falls es noch nicht in der Liste steht.
  ///
  /// Idempotent, und das ist die Form der Quelle: `if (!arr.includes(id))`
  /// (`storage.jsx:49-52`). Ein zweiter Aufruf für denselben Fakt verschiebt
  /// ihn **nicht** ans Ende der Liste; wer zweimal sammelt, hat ihn beim
  /// ersten Mal gesammelt.
  ///
  /// Wirft nicht. Scheitert der Gerätespeicher, bleibt die gespeicherte Liste
  /// stehen und die Umsetzung meldet es an ihre Diagnosesenke. Ein verlorener
  /// Schreibvorgang kostet, dass derselbe Fakt beim nächsten Start noch einmal
  /// eingesammelt werden kann; er nimmt keinen Spielzug zurück.
  Future<void> collectFact(FactId factId);
}

/// Flüchtige Umsetzung für Tests und als Standard, solange `bootstrap()` den
/// Provider nicht überschrieben hat.
///
/// **Sie ist der stille Ausfall, vor dem `test/app/bootstrap_test.dart` das
/// Projekt schützt**, und deshalb steht sie hier mit derselben Warnung wie die
/// vier Geschwister: eine App auf diesem Standard sieht heil aus, sammelt, und
/// hat nach dem Neustart nichts gesammelt.
class InMemoryCollectedFactsStore implements CollectedFactsStore {
  /// [collected] setzt eine bereits gefüllte Sammlung, etwa in einem Test.
  ///
  /// Die Liste wird kopiert, damit ein Test, der sein Literal nachträglich
  /// ändert, nicht den Speicher mitverändert.
  InMemoryCollectedFactsStore([List<FactId> collected = const <FactId>[]])
    : _collected = List<FactId>.of(collected);

  final List<FactId> _collected;

  @override
  List<FactId> readCollectedFacts() => List<FactId>.unmodifiable(_collected);

  @override
  Future<void> collectFact(FactId factId) async {
    if (_collected.contains(factId)) {
      return;
    }
    _collected.add(factId);
  }
}
