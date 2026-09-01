/// Die laufende Solo-Jagd, so wie sie **außerhalb** von `challenges` sichtbar
/// ist. Umsetzung von ADR-007.
///
/// ## Wozu es diesen Typ gibt
///
/// E-43 hat entschieden, dass die Solo-Jagd auf der **Karte** läuft. Der
/// Kartenbildschirm gehört `discovery`, der Zustand der Jagd gehört
/// `challenges`, und ADR-007 zieht die Grenze so: `challenges/domain` definiert
/// Lesemodell und Speichervertrag, `challenges/application` gibt das Lesemodell
/// als Provider heraus, `discovery/presentation` sieht ihm zu. Geschrieben wird
/// ausschließlich im besitzenden Feature.
///
/// ## Der Zuschnitt, Feld für Feld
///
/// Maßgeblich ist `HuntPill` in `02_Frontend/app/screen-map.jsx:1011-1135`, der
/// einzige Verbraucher des Jagdzustands auf der Karte:
///
/// * [ActiveHunt.stationOrdinal] und [ActiveHunt.stationCount] zeichnen
///   „Station 3 / 7" (`:1086`, `currentStopIdx + 1` und `stops.length`). Die
///   beiden sind **nicht** redundant zu `HuntDuration.stopCount`: findet der
///   Generator weniger Stationen als die Dauer vorsieht, laufen sie
///   auseinander, und `HuntPlan.estimatedDurationMinutes` beschreibt genau
///   diesen Fall.
/// * [ActiveHunt.stationTitle] ist die Zeile darunter (`:1089`,
///   `stop.factTitle`). Datenquelle ist `Fact.canonicalTitle`.
/// * [ActiveHunt.stationLatitude] und [ActiveHunt.stationLongitude] sind der
///   Punkt, aus dem die Quelle Entfernung und Peilung rechnet (`:1053-1054`).
///   Datenquelle ist `HuntStop.position`.
/// * [ActiveHunt.unlockedHintIndices] sind die Indizes der an der aktuellen
///   Station freigeschalteten Hinweise. ADR-007, Nachtrag „superseded by the
///   owner's answer": die Quelle bucht den Kauf am Stopp (`:1067` ruft
///   `onHuntHintCost`, `app.jsx:927-935` addiert `hintCostSpent`), aber weder
///   die Anzahl noch die Münzsumme sind die richtige Nutzlast, weil beide aus
///   den Indizes folgen und nicht umgekehrt. Details am Feld selbst.
/// * [ActiveHunt.difficulty] ist die Schwierigkeitsstufe der Jagd (D-18).
///   `screen-map.jsx:1049-1051` staffelt daran die Navigationshilfen,
///   `screen-challenge.jsx:2828` zeigt sie im Pause-Bildschirm. Details am
///   Feld selbst.
/// * [ActiveHunt.duration] steht hier nicht für `discovery`, sondern weil die
///   Ansage die Jagd überleben muss. Die Begründung steht schon in
///   `HuntPlan.duration`: „der Pause-Bildschirm zeigt sie nach einem Neustart
///   der App wieder an, und dann ist der Assistent längst weg."
///
/// ## Was hier bewusst fehlt, und warum
///
/// * **Die Entfernung selbst.** ADR-007 nennt „wie weit sie entfernt ist", und
///   trotzdem ist das kein Feld: sie ist keine Eigenschaft der Jagd, sondern
///   eine Funktion aus Jagd **und** Gerätestandort. Der Standort kommt im
///   Sekundentakt aus `lib/services/location/`, ein Feld dafür würde also bei
///   jedem GPS-Takt einen neuen Wert in einem Modell erzeugen, das gespeichert
///   wird. Der Verbraucher rechnet sie aus Lage und Nutzerposition mit
///   `MapPosition.distanceInMetersTo`, genau wie `hunt_start_options.dart` das
///   für den Startpunkt-Picker tut.
/// * **Die Stationsliste, das gewählte Rätsel je Station, Punkte, Startzeit und
///   der Zustand je Stopp.** Alles Felder, die heute niemand fortschreibt.
///   `hunt_plan.dart` hat dieselbe Grenze für die Erzeugung gezogen: „Ein Feld,
///   das immer `pending` trägt, weil es niemand fortschreibt, sieht aus wie
///   Zustand und ist keiner." Sie kommen mit der Phasenmaschine (Schritt 36),
///   und der Preis dafür ist eine Erhöhung von [ActiveHunt.payloadVersion].
///
/// ## Es gibt genau einen Weg zu einem Wert
///
/// Der Konstruktor ist privat. Wer eine Jagd braucht, geht über
/// [ActiveHunt.tryFrom] oder [ActiveHunt.tryFromPayload] und bekommt ein
/// `null`, wenn seine Werte keine Jagd beschreiben. Das ist enger als bei den
/// Wertobjekten dieses Projekts, und der Grund steht am Konstruktor: dieser Typ
/// ist die **gespeicherte Nutzlast**. Eine ungeprüfte Jagd fällt nicht dort
/// auf, wo sie entsteht, sondern beim nächsten Start der App, und dann ist sie
/// nur noch ein verschwundener Spielstand.
///
/// ## Warum die Lage zwei nackte `double` sind
///
/// Weil ein vierter Koordinatentyp genau die Kopie wäre, die D-9 abgelehnt hat.
/// Die Antwort auf D-9 lautet „lokale Typen bleiben, denn die drei Typen sind
/// keine Kopien": `MapPosition`, `FactCoordinates` und `DevicePosition` tragen
/// unterschiedliches Verhalten. Ein Punkt-Typ mit zwei Feldern und ohne
/// Verhalten trüge nichts davon, und erreichbar wäre hier ohnehin keiner der
/// drei (Gate 6). Der Verbraucher baut sich eine `MapPosition`, wie
/// `HuntStop.position` und `hunt_start_options.dart` es schon tun.
///
/// ## Warum [PuzzleDifficulty] hier stehen darf
///
/// Bis ADR-008 hätte [difficulty] eine vierte Kopie einer Schwierigkeitsstufe
/// gebraucht, denn Gate 6 erlaubt einer Feature-Domäne nur das Dart-SDK und die
/// eigene Domäne. ADR-008, Regel 23 öffnet dafür genau eine Ausnahme: der
/// geteilte Kern unter `lib/kernel/` ist für Typen gedacht, die mehrere
/// Feature-Domänen ungeprüft brauchen, und [PuzzleDifficulty] ist so ein Typ.
/// Das ist D-18, umgesetzt.
library;

import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';

/// Die laufende Jagd als unveränderlicher Wert.
///
/// Ein `null` an der Stelle eines [ActiveHunt] heißt: es läuft keine Jagd.
final class ActiveHunt {
  /// Erzeugt eine laufende Jagd. **Privat**, und darin liegt die Zusicherung
  /// dieses Typs: es gibt kein [ActiveHunt], das [tryFrom] nicht durchlaufen
  /// hat. Der Zugang ist [tryFrom] für geprüfte Werte und [tryFromPayload] für
  /// eine gespeicherte Nutzlast.
  ///
  /// `FactCoordinates` teilt es anders auf und hat neben `tryFrom` einen
  /// offenen Konstruktor. **Der Unterschied ist, was mit dem Wert passiert.**
  /// Eine `FactCoordinates` wird gelesen und weggeworfen, ein [ActiveHunt] wird
  /// **auf die Platte geschrieben**. Ein offener Konstruktor hier hieße: eine
  /// Jagd mit `stationOrdinal: 0`, `stationCount: 0` und
  /// `stationLatitude: 1000` wird angenommen, `ActiveHuntStore.writeActiveHunt`
  /// nimmt sie an, sie läuft eine Sitzung lang einwandfrei, und beim Neustart
  /// gibt [tryFromPayload] dafür `null` zurück. Der Spielstand ist dann
  /// lautlos weg, und der Fehler zeigt sich Stunden nach seiner Ursache.
  /// Genau das verbietet ADR-007 mit „Restoring validates", und eine Regel, die
  /// nur auf der Leseseite gilt, ist keine.
  ///
  /// Ein `assert` im offenen Konstruktor wäre keine Abhilfe: es fehlt im
  /// Release-Build, also genau dort, wo der Schaden entsteht.
  const ActiveHunt._({
    required this.stationOrdinal,
    required this.stationCount,
    required this.stationTitle,
    required this.stationLatitude,
    required this.stationLongitude,
    required this.unlockedHintIndices,
    required this.difficulty,
    required this.duration,
  });

  /// Fassung der gespeicherten Nutzlast.
  ///
  /// ADR-007: „Restoring validates; an unparsable or stale payload is
  /// discarded, not repaired." Diese Zahl ist der Hebel dafür. Wer ein Feld
  /// hinzufügt, entfernt oder umdeutet, erhöht sie, und [tryFromPayload]
  /// verwirft danach jede ältere Nutzlast. Der Preis ist bekannt und gewollt:
  /// eine Jagd, die zum Zeitpunkt des Updates läuft, ist weg. Eine Nutzlast
  /// halb zu lesen und den Rest zu erfinden wäre schlimmer, weil der Nutzer
  /// dann eine Jagd weiterspielt, die es nicht mehr gibt.
  ///
  /// **Von 1 auf 2 in einem Zug, mit zwei Inhalten zugleich, und das ist
  /// Absicht.** Sowohl die Umstellung von `purchasedHintCount` auf
  /// [unlockedHintIndices] als auch die Aufnahme von [difficulty] ändern die
  /// Form der Nutzlast, beide hätten also für sich genommen diese Zahl erhöht.
  /// Seit `shared_preferences` echte Nutzlasten auf echten Geräten liegen,
  /// verwirft jede Erhöhung einen gespeicherten Spielstand; zwei Erhöhungen
  /// hintereinander würden ihn zweimal verwerfen, für zwei Änderungen, die
  /// dieselbe Sitzung ohnehin gemeinsam hätte kosten müssen. Deshalb steht hier
  /// eine Erhöhung für beide Inhalte.
  static const int payloadVersion = 2;

  /// Größter gültiger Breitengrad, wie `FactCoordinates.maxLatitude`.
  static const double _maxLatitude = 90;

  /// Größter gültiger Längengrad, wie `FactCoordinates.maxLongitude`.
  static const double _maxLongitude = 180;

  /// Die Station, die gerade dran ist, **1-basiert**.
  ///
  /// Die Quelle führt einen 0-basierten `currentStopIdx` und addiert bei der
  /// Anzeige 1 (`screen-map.jsx:1086`). Hier steht die angezeigte Zahl, weil
  /// das der einzige Leser ist und ein zweiter Ort für „plus eins" die zweite
  /// Gelegenheit für einen Abstandsfehler wäre.
  final int stationOrdinal;

  /// Wie viele Stationen die Jagd hat, mindestens eine.
  ///
  /// Die Untergrenze hat **keine** eigene Wache in [tryFrom]. Sie folgt aus der
  /// Ordinalregel, und die Begründung steht dort.
  final int stationCount;

  /// Titel des Fakts an der aktuellen Station.
  ///
  /// Darf leer sein. `Fact.canonicalTitle` fällt selbst auf eine leere
  /// Zeichenkette zurück, mit der dort genannten Begründung: „ein leerer Titel
  /// ist eine leere Zeile und kein Absturz".
  final String stationTitle;

  /// Breitengrad der aktuellen Station.
  final double stationLatitude;

  /// Längengrad der aktuellen Station.
  final double stationLongitude;

  /// Indizes der an der aktuellen Station **freigeschalteten** Hinweise,
  /// kanonisch: aufsteigend sortiert, ohne Duplikate, `List.unmodifiable`.
  ///
  /// Ersetzt seit [payloadVersion] 2 die Anzahl `purchasedHintCount`.
  /// Begründung in ADR-007, Nachtrag „superseded by the owner's answer": die
  /// Indizes tragen bei gleicher Größe strikt mehr Information als eine Anzahl
  /// oder eine Münzsumme. Anzahl **und** ausgegebene Münzen folgen aus den
  /// Indizes (Summe über `HINT_COSTS[i]`), umgekehrt nicht: bei
  /// `HINT_COSTS = [0, 20, 30]` bedeuten die Summen 20 und 30 beide „ein
  /// Hinweis". Anzahl und Kosten sind damit abgeleitete Werte ohne eigenen
  /// Speicher.
  ///
  /// **Normalisiert, nicht repariert.** [tryFrom] sortiert aufsteigend,
  /// entfernt Duplikate und liefert eine `List.unmodifiable`. Das sieht nach
  /// einem Verstoß gegen ADR-007s „verwerfen statt reparieren" aus und ist
  /// keiner: die freigeschalteten Hinweise sind eine **Menge**, Reihenfolge
  /// und Mehrfachnennung tragen keine Bedeutung. Normalisieren wählt also nur
  /// eine kanonische Darstellung desselben Werts, es repariert keinen kaputten.
  /// Ohne diese Regel wären `[0, 1]` und `[1, 0]` zwei verschiedene Jagden, und
  /// ein Aufrufer, der die Liste aus der Iterationsreihenfolge eines `Set`
  /// baut, würde zufällig scheitern.
  ///
  /// Die Obergrenze ist absichtlich nicht geprüft, obwohl sie ableitbar wäre:
  /// `Fact.stationHints` trägt genau drei Einträge (`import_facts.py:225`), und
  /// der erste ist in der Quelle kostenlos und von Anfang an offen
  /// (`screen-map.jsx:1013-1014`), womit heute höchstens zwei Indizes
  /// freigeschaltet sein können. Diese Zwei hängt aber an der Preistabelle
  /// `HINT_COSTS` (`:1031`) und damit an Schritt 37. Eine Prüfung darauf würde
  /// nach einer Preisänderung eine **gültige** Nutzlast verwerfen, und das ist
  /// der teurere Fehler.
  ///
  /// Ein negativer Index wird abgewiesen: er kann in der Quelle nicht
  /// entstehen und ist damit ein Zeichen für eine kaputte Nutzlast, nicht für
  /// einen noch unbekannten gültigen Wert.
  final List<int> unlockedHintIndices;

  /// Schwierigkeitsstufe der Jagd, oder `null`, wenn keine bekannt ist.
  ///
  /// Seit ADR-008, Regel 23 darf `challenges/domain` [PuzzleDifficulty] aus dem
  /// geteilten Kern importieren; D-18 war genau diese Frage, und dieses Feld
  /// ist ihre Antwort. `screen-map.jsx:1049-1051` staffelt daran die
  /// Navigationshilfen (leicht: Pfeil und Distanz, mittel: nur Distanz, schwer:
  /// nichts), `screen-challenge.jsx:2828` zeigt sie im Pause-Bildschirm.
  ///
  /// **Nullbar und ohne Ersatzwert.** Ein Rätsel muss keine Stufe haben, siehe
  /// [PuzzleDifficulty]s eigene Begründung „kein Standardwert". Welcher
  /// Ersatzwert bei einer fehlenden Stufe gälte, ist eine Belohnungsfrage
  /// (`puzzles`, `progression`) und keine Frage dieses Lesemodells.
  final PuzzleDifficulty? difficulty;

  /// Die im Assistenten gewählte Dauer.
  final HuntDuration duration;

  /// Prüft die Werte und gibt `null` zurück, wenn sie keine Jagd beschreiben.
  ///
  /// Hier stehen die Regeln, die für **jede** Herkunft gelten: für die
  /// Projektion aus einem `HuntPlan` genauso wie für eine wiederhergestellte
  /// Nutzlast. Es wird nichts geworfen und nichts zurechtgebogen; der Aufrufer
  /// entscheidet, ob ein `null` eine Meldung wert ist. Die einzige Ausnahme ist
  /// [unlockedHintIndices]: dort **normalisiert** diese Methode statt bloß zu
  /// prüfen, aus dem Grund, der am Feld steht.
  ///
  /// **Der einzige Weg zu einem [ActiveHunt]**, siehe den privaten
  /// Konstruktor. Daran hängen zwei Eigenschaften, die ohne diese Enge nicht
  /// gelten würden und auf die sich andere Stellen verlassen:
  ///
  /// * **Jede Lage ist endlich.** Ohne das könnte `stationLatitude` `NaN`,
  ///   `+Infinity` oder `-Infinity` tragen, und dann wirft `jsonEncode` auf
  ///   [toPayload] einen `JsonUnsupportedObjectError`. Der Vertrag von
  ///   `ActiveHuntStore.writeActiveHunt` verspricht, nicht zu werfen; erst
  ///   diese Prüfung macht die beiden Versprechen miteinander vereinbar.
  /// * **Gleichheit ist reflexiv.** In Dart ist `double.nan == double.nan`
  ///   falsch, ein [ActiveHunt] mit `NaN`-Lage wäre also sich selbst nicht
  ///   gleich. In einem `Provider<ActiveHunt?>` sähe damit jede Neuberechnung
  ///   wie eine Änderung aus, und die Karte würde ohne Anlass neu aufgebaut.
  static ActiveHunt? tryFrom({
    required int stationOrdinal,
    required int stationCount,
    required String stationTitle,
    required double stationLatitude,
    required double stationLongitude,
    required List<int> unlockedHintIndices,
    required PuzzleDifficulty? difficulty,
    required HuntDuration duration,
  }) {
    // Diese eine Regel trägt zugleich „mindestens eine Station": aus
    // `stationOrdinal >= 1` und `stationOrdinal <= stationCount` folgt
    // `stationCount >= 1`. Hier stand deshalb einmal eine zweite Wache
    // `stationCount < 1`, und sie war **bei jeder Eingabe** unerreichbar. Zwei
    // Mutationen haben es belegt: `< 1` zu `< 0` und die ganze Bedingung zu
    // `false` blieben beide grün. Sie ist weg, weil eine Zusicherung, die keine
    // Eingabe erreichen kann, keine Tiefe ist, sondern eine Zeile, die
    // behauptet, etwas zu prüfen.
    if (stationOrdinal < 1 || stationOrdinal > stationCount) {
      return null;
    }
    // Ein negativer Index kann in der Quelle nicht entstehen, siehe die
    // Begründung am Feld. Diese Wache läuft **vor** der Normalisierung, sonst
    // würde ein negativer Index unbemerkt einsortiert statt verworfen.
    for (final int index in unlockedHintIndices) {
      if (index < 0) {
        return null;
      }
    }
    // `NaN` braucht eine eigene Regel, weil **jeder** Vergleich mit `NaN`
    // falsch ist: `double.nan.abs() > 90` ist `false`, die Bereichsregel
    // darunter würde es also durchlassen. `+Infinity` und `-Infinity` brauchen
    // keine eigene Regel, die Bereichsregel fängt sie. Beide Fälle sind
    // festgehalten, damit die Arbeitsteilung der zwei Wachen sichtbar bleibt.
    if (stationLatitude.isNaN || stationLongitude.isNaN) {
      return null;
    }
    if (stationLatitude.abs() > _maxLatitude ||
        stationLongitude.abs() > _maxLongitude) {
      return null;
    }
    return ActiveHunt._(
      stationOrdinal: stationOrdinal,
      stationCount: stationCount,
      stationTitle: stationTitle,
      stationLatitude: stationLatitude,
      stationLongitude: stationLongitude,
      unlockedHintIndices: List<int>.unmodifiable(
        <int>{...unlockedHintIndices}.toList()..sort(),
      ),
      difficulty: difficulty,
      duration: duration,
    );
  }

  /// Liest eine gespeicherte Nutzlast oder **verwirft** sie.
  ///
  /// Nimmt bewusst `Object?` und nicht `Map<String, Object?>`: was aus einem
  /// Gerätespeicher kommt, ist ungeprüft, und „das ist gar keine Abbildung" ist
  /// einer der Fälle, die verworfen werden müssen. Ein `as`-Cast auf einen
  /// Rohwert kommt hier nicht vor, aus demselben Grund wie im Fakt-Mapping: ein
  /// einziger falscher Cast nimmt die ganze Nutzlast mit.
  ///
  /// Die persistente Umsetzung in `challenges/data` besteht danach aus drei
  /// Handgriffen: Schlüssel lesen, `jsonDecode`, dieses [tryFromPayload]. Sie
  /// enthält **keine** eigene Prüfung, sonst gäbe es zwei Orte, an denen
  /// „gültig" definiert ist. Das gilt für die Schreibrichtung genauso, und dort
  /// hängt es am privaten Konstruktor: `jsonEncode` auf [toPayload] kann nicht
  /// scheitern, weil kein [ActiveHunt] eine nicht-endliche Lage tragen kann.
  /// Die Quelle nennt ihren Schlüssel
  /// `fact_active_challenge` (`storage.jsx:190-192`) und verwirft ebenfalls
  /// still, wenn `JSON.parse` scheitert (`storage.jsx:6-11`).
  ///
  /// **Was diese Prüfung nicht kann:** feststellen, ob der Fakt hinter der
  /// Station noch existiert. ADR-007 nennt das ausdrücklich („A restored hunt
  /// can reference a station whose fact no longer exists"), und es braucht den
  /// aktuellen Faktenbestand, den eine Domäne nicht sieht. Diese zweite Stufe
  /// gehört zur Wiederherstellung in Schritt 36. Wer sie vergisst, bekommt
  /// keine Ausnahme, sondern eine Jagd zu einem Ort, den es nicht mehr gibt.
  static ActiveHunt? tryFromPayload(Object? payload) {
    if (payload is! Map<Object?, Object?>) {
      return null;
    }
    if (payload['v'] != payloadVersion) {
      return null;
    }
    final Object? stationOrdinal = payload['stationOrdinal'];
    final Object? stationCount = payload['stationCount'];
    final Object? stationTitle = payload['stationTitle'];
    final Object? latitude = payload['lat'];
    final Object? longitude = payload['lng'];
    final Object? hintIndices = payload['hintIndices'];
    final Object? durationMinutes = payload['durationMinutes'];
    // Ganzzahlen müssen Ganzzahlen sein, die Lage darf `num` sein: JSON
    // schreibt eine Koordinate ohne Nachkommastelle als `11` und nicht als
    // `11.0`, und `jsonDecode` liefert dafür ein `int`. Ein Ordinalwert `3.0`
    // dagegen ist eine Formänderung und wird verworfen.
    if (stationOrdinal is! int ||
        stationCount is! int ||
        stationTitle is! String ||
        latitude is! num ||
        longitude is! num ||
        hintIndices is! List ||
        durationMinutes is! int) {
      return null;
    }
    // Jedes Element muss ein `int` sein, sonst wird die ganze Nutzlast
    // verworfen. Eine leere Liste ist gültig: keine freigeschalteten
    // Hinweise ist ein normaler Zustand, keine kaputte Nutzlast.
    final List<int> parsedHintIndices = <int>[];
    for (final Object? element in hintIndices) {
      if (element is! int) {
        return null;
      }
      parsedHintIndices.add(element);
    }
    // Fehlt der Schlüssel oder ist er `null`, ist die Stufe unbekannt und die
    // Nutzlast bleibt gültig, denn ein Rätsel ohne Stufe ist ein normaler
    // Zustand (siehe [difficulty]). Ist der Wert weder `null` noch eine
    // Zeichenkette, ist die Nutzlast kaputt. Ist er eine Zeichenkette, die
    // [PuzzleDifficulty.fromCode] nicht auflöst, wird die **ganze** Nutzlast
    // verworfen: dieselbe Entscheidung, die [_durationOfMinutes] weiter unten
    // für eine unbekannte Dauer schon trifft, und der Präzedenzfall ist das
    // Argument. Eine Jagd, deren Stufe still von der abweicht, die der Spieler
    // gesehen hat, ist schlimmer als ein Neustart.
    final Object? rawDifficulty = payload['difficulty'];
    final PuzzleDifficulty? difficulty;
    if (rawDifficulty == null) {
      difficulty = null;
    } else if (rawDifficulty is String) {
      final PuzzleDifficulty? resolved = PuzzleDifficulty.fromCode(
        rawDifficulty,
      );
      if (resolved == null) {
        return null;
      }
      difficulty = resolved;
    } else {
      return null;
    }
    final HuntDuration? duration = _durationOfMinutes(durationMinutes);
    if (duration == null) {
      return null;
    }
    return tryFrom(
      stationOrdinal: stationOrdinal,
      stationCount: stationCount,
      stationTitle: stationTitle,
      stationLatitude: latitude.toDouble(),
      stationLongitude: longitude.toDouble(),
      unlockedHintIndices: parsedHintIndices,
      difficulty: difficulty,
      duration: duration,
    );
  }

  /// Die Dauer zu einer Minutenzahl, oder `null` für jede unbekannte.
  ///
  /// Die Minuten sind der Schlüssel und nicht der Name des Aufzählungswerts,
  /// weil 30, 60 und 90 auch in der Quelle die Schlüssel sind
  /// (`stopCountByDuration` in `screen-challenge.jsx:4332`). Ein umbenannter
  /// Aufzählungswert soll keine gespeicherte Jagd verwerfen.
  static HuntDuration? _durationOfMinutes(int minutes) {
    for (final HuntDuration duration in HuntDuration.values) {
      if (duration.minutes == minutes) {
        return duration;
      }
    }
    return null;
  }

  /// Die Nutzlast für den Gerätespeicher.
  ///
  /// Nur flache Zahlen, Zeichenketten und eine flache Liste von Zahlen, damit
  /// `jsonEncode` in der Datenschicht ohne eigenes Wissen über diesen Typ
  /// auskommt. [difficulty] steht als `code`, nicht als Aufzählungsname, aus
  /// demselben Grund wie [duration] ihre Minuten speichert statt ihres Namens:
  /// siehe [_durationOfMinutes]. Ein umbenannter Aufzählungswert soll keine
  /// gespeicherte Jagd verwerfen.
  ///
  /// **Und `jsonEncode` darauf kann nicht scheitern.** Die einzigen Werte, an
  /// denen es das könnte, sind `NaN` und die beiden Unendlichkeiten, und die
  /// verwirft [tryFrom]. Das ist keine Bequemlichkeit, sondern die Bedingung
  /// dafür, dass `ActiveHuntStore.writeActiveHunt` sein „wirft nicht" halten
  /// kann, ohne die Prüfung ein zweites Mal aufzuschreiben.
  Map<String, Object?> toPayload() => <String, Object?>{
    'v': payloadVersion,
    'stationOrdinal': stationOrdinal,
    'stationCount': stationCount,
    'stationTitle': stationTitle,
    'lat': stationLatitude,
    'lng': stationLongitude,
    'hintIndices': unlockedHintIndices,
    'difficulty': difficulty?.code,
    'durationMinutes': duration.minutes,
  };

  @override
  bool operator ==(Object other) =>
      other is ActiveHunt &&
      other.stationOrdinal == stationOrdinal &&
      other.stationCount == stationCount &&
      other.stationTitle == stationTitle &&
      other.stationLatitude == stationLatitude &&
      other.stationLongitude == stationLongitude &&
      _sameHintIndices(other.unlockedHintIndices, unlockedHintIndices) &&
      other.difficulty == difficulty &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(
    stationOrdinal,
    stationCount,
    stationTitle,
    stationLatitude,
    stationLongitude,
    Object.hashAll(unlockedHintIndices),
    difficulty,
    duration,
  );

  /// Elementweiser Vergleich zweier Indexlisten für `==`.
  ///
  /// Steht hier und nicht in `core`, weil ein neues Paket für diese eine
  /// Vergleichszeile nicht gerechtfertigt ist: `List` hat aus `dart:core`
  /// keine Werthgleichheit, und [tryFrom] normalisiert jede Liste ohnehin
  /// schon vor dem Speichern, sodass ein einfacher Elementvergleich genügt.
  static bool _sameHintIndices(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  /// Ohne Lage **und ohne Titel**, aus demselben Grund wie
  /// `FactCoordinates.toString()` und `MapPosition.toString()`:
  /// `docs/engineering/security.md` §6 verbietet genaue Standortangaben im Log.
  /// Der Titel der Station, an der jemand gerade steht, ist eine
  /// Standortangabe, nur in Worten.
  @override
  String toString() => 'ActiveHunt(Station $stationOrdinal/$stationCount)';
}
