/// Das Ergebnis des Routengenerators: eine spielbare Schnitzeljagd.
///
/// ## Warum diese Typen in `application/` liegen und nicht in `domain/`
///
/// Sie tragen fremde Wertobjekte: einen [Fact] und das an ihm hängende
/// [FactPuzzle]. Beides gehört der Domäne `facts`, und Gate 6 in
/// `tool/check_architecture.dart` lässt eine Feature-Domäne nur das Dart-SDK
/// und die **eigene** Domäne importieren. Ein
/// `import 'package:fact_app/features/facts/domain/entities/fact.dart'` aus
/// `lib/features/challenges/domain/` bricht mit Exit-Code 1 ab, derselbe
/// Import aus `lib/features/challenges/application/` läuft mit Exit-Code 0
/// durch. Beides ist mit Wegwerf-Proben nachgemessen, nicht angenommen.
///
/// Der Ausweg, den `puzzles` gegangen ist, wäre hier der falsche. Dort steht
/// mit `PuzzleDifficulty` eine **wortgleiche Kopie** von
/// `PuzzleDifficulty` in der eigenen Domäne, ausdrücklich als zweite
/// Wiederholung von D-9 gemeldet. Eine Jagd-Station in `challenges/domain/`
/// bräuchte dieselbe Behandlung für gleich vier Typen auf einmal: [FactId],
/// [FactCoordinates], die Rätselstufe und das Rätsel selbst. Das wäre die
/// dritte bis sechste Wiederholung derselben offenen Frage, und sie würde
/// eine Kopie des halben Faktenmodells nach sich ziehen.
///
/// Deshalb: **kein `challenges/domain/hunt_plan.dart`.** Was in dieser Domäne
/// wirklich ohne Fremdtyp auskommt, steht dort und nur das, heute
/// `HuntDuration`. Wird D-9 so beantwortet, dass ein geteilter Typ erlaubt
/// ist, zieht diese Datei ohne Feldänderung nach `domain/` um.
///
/// ## Was hier bewusst fehlt
///
/// Der Generator der Quelle baut pro Stopp mehr als die Auswahl:
///
/// * **Spielzustand** (`hunt-generator.jsx:103-106`): `status: 'pending'`,
///   `pointsAwarded`, `hintUsed`, `solvedAt`. Das ist der Fortschritt einer
///   **laufenden** Jagd und gehört der Phasenmaschine aus Schritt 36, nicht
///   der Erzeugung. Ein Feld, das immer `pending` trägt, weil es niemand
///   fortschreibt, sieht aus wie Zustand und ist keiner.
/// * **Die Hinweis-Trios** (`:317-338`). Sie sind eine reine Projektion über
///   die schon gewählten Stopps: der Hinweis an Stopp `i` beschreibt den Ort
///   von Stopp `i + 1` und steht in dessen `Fact.stationHints`. Ihr
///   Rückfallpfad (`:44-61`) bringt sechs deutsche und sechs englische Sätze
///   mit, die die PWA sichtbar anzeigt, **ohne** sie als i18n-Schlüssel zu
///   führen; sie bräuchten also zwölf Einträge nach E-39. Gezeigt werden sie
///   erst vom Navigations- und vom Auflösungsbildschirm, und beide sind
///   gesperrt (Schritte 36 und 37).
/// * **Die Routen-Kennung und die Themenroute** (`:341-347`). Kuratierte
///   Themenrouten sind in diesem Schritt nicht gebaut, siehe den Kopf von
///   [generateHuntRoute].
library;

import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:fact_app/map/domain/map_position.dart';

/// Eine Station der Jagd: ein Ort und die eine Aufgabe, die dort gilt.
class HuntStop {
  /// Erzeugt eine Station.
  const HuntStop({required this.fact, required this.puzzle});

  /// Der Fakt, an dem die Station hängt.
  ///
  /// Die Quelle kopiert stattdessen `factId`, `factNr`, `factTitle`, `lat` und
  /// `lng` in den Stopp (`hunt-generator.jsx:96-107`), weil ein Hunt dort als
  /// JSON im `localStorage` liegt und der Faktenbestand beim Wiedereinstieg
  /// ein anderer sein kann. Hier steht der Fakt selbst: es gibt noch keine
  /// Ablage, und fünf abgeschriebene Felder wären fünf Gelegenheiten, dass
  /// Titel oder Koordinate auseinanderlaufen. Wenn eine laufende Jagd
  /// gespeichert wird (Schritt 36), entscheidet die Datenschicht, was davon
  /// auf die Platte geht.
  final Fact fact;

  /// Das Rätsel, das der Generator an dieser Station ausgewählt hat.
  ///
  /// Eines aus [Fact.puzzles], ausgewählt nach der Typ-Vielfalt der schon
  /// gesetzten Stationen (`hunt-generator.jsx:93-95`). Bewusst als
  /// [FactPuzzle] und nicht als `Puzzle` aus der Domäne `puzzles`: die
  /// Übersetzung ist Schritt 38, und D-15 ist offen.
  final FactPuzzle puzzle;

  /// Der Ort der Station.
  ///
  /// Nicht nullbar, weil der Generator Fakten ohne Koordinate gar nicht erst
  /// in den Kandidatenpool lässt (`hunt-generator.jsx:158`).
  MapPosition get position => MapPosition(
    latitude: fact.coordinates!.latitude,
    longitude: fact.coordinates!.longitude,
  );
}

/// Eine fertig erzeugte Schnitzeljagd.
class HuntPlan {
  /// Erzeugt einen Plan.
  const HuntPlan({
    required this.stops,
    required this.difficulty,
    required this.duration,
  });

  /// Die Stationen in Laufreihenfolge, mindestens eine.
  final List<HuntStop> stops;

  /// Die Stufe, mit der der Plan erzeugt wurde (`hunt-generator.jsx:349`).
  ///
  /// Sie steht hier, weil die Stufe während der Jagd sichtbar bleibt und
  /// nicht nur eine Eingabe der Erzeugung ist: `screen-challenge.jsx:2828`
  /// zeigt sie im Kopf des Pause-Bildschirms an.
  final PuzzleDifficulty difficulty;

  /// Die Dauer, die der Nutzer im Assistenten gewählt hat.
  ///
  /// Sie steht im Plan und nicht nur im Assistenten, weil eine laufende Jagd
  /// sie überlebt: der Pause-Bildschirm zeigt sie nach einem Neustart der App
  /// wieder an, und dann ist der Assistent längst weg.
  final HuntDuration duration;

  /// Die Dauer, die dem Nutzer angesagt wird, in Minuten.
  ///
  /// ## Hier weicht der Neubau bewusst von der Quelle ab (E-45)
  ///
  /// `hunt-generator.jsx:354` rechnet `estimatedDurationMin: stops.length * 14`
  /// und kommt damit auf 70, 98 beziehungsweise 126 Minuten, während der
  /// Nutzer unmittelbar davor 30, 60 oder 90 gewählt hat
  /// (`screen-challenge.jsx:4332`). Aus „30 min" werden dort 70.
  ///
  /// **Janek hat das am 30.08.2026 entschieden:** die gewählte Dauer gilt.
  /// Die 30, 60 oder 90 Minuten sind die Ansage an den Nutzer, und ein Wert,
  /// der ihm unmittelbar nach seiner eigenen Wahl etwas anderes sagt, ist ein
  /// Fehler und keine Parität. Deshalb liefert dieser Wert [HuntDuration] und
  /// nicht die Rechnung der Quelle.
  ///
  /// Die Spur dorthin bleibt absichtlich stehen: wer die Quelle liest, findet
  /// dort eine andere Zahl, und hier den Grund.
  ///
  /// ## Der Rest bleibt offen, und dafür gibt es keine Formel
  ///
  /// Findet der Generator weniger Stationen als die Dauer vorsieht, steht die
  /// Ansage über dem, was die Jagd wirklich kostet: 30 Minuten angesagt,
  /// aber nur drei statt fünf Stationen gebaut. Der Fall ist an
  /// `stops.length` gegenüber `duration.stopCount` ablesbar und wird hier
  /// **nicht** überschlagen. Eine heruntergerechnete Minutenzahl wäre eine
  /// erfundene Größe; was der Nutzer in dieser Lage sehen soll, ist eine
  /// Produktfrage und keine Rechenaufgabe.
  int get estimatedDurationMinutes => duration.minutes;
}
