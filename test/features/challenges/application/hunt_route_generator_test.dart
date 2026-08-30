import 'dart:math' as math;

import 'package:fact_app/features/challenges/application/hunt_plan.dart';
import 'package:fact_app/features/challenges/application/hunt_route_generator.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_puzzle_difficulty.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Routengenerator, `02_Frontend/app/hunt-generator.jsx`.
///
/// ## Warum hier kein Widget vorkommt
///
/// Die Funktion ist rein und bei gegebenem Seed deterministisch. Alles, was
/// diese Datei prüft, hängt an Eingabewerten und an nichts sonst: keine
/// Datenbank, keine Uhr, kein Zufall außer dem, den der Test selbst setzt.
///
/// ## Die Fakten liegen auf einem Meterraster
///
/// [_gridFacts] legt die Fakten in einem Gitter mit 300 Metern Abstand aus.
/// Diagonal sind das 424 Meter, also fast genau der bevorzugte Abstand von 420
/// (`hunt-generator.jsx:126`). Damit gibt es in jedem Schritt Kandidaten im
/// primären Fenster, und die Schleife bricht nie aus Mangel ab. Wo eine
/// Zusicherung genau diesen Mangel braucht, steht ein eigener Bestand.
void main() {
  group('Bestandsfilter', () {
    test('ein Fakt ohne Rätsel ist kein Kandidat', () {
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0, puzzles: const <FactPuzzle>[]),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        seed: 'probe',
      );

      expect(plan, isNull);
    });

    test('ein Fakt ohne Koordinate ist kein Kandidat', () {
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[_fact(1, north: 0, east: 0).copyWithoutCoordinates()],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        seed: 'probe',
      );

      expect(plan, isNull);
    });

    test('ein leerer Bestand liefert null und wirft nicht', () {
      expect(
        generateHuntRoute(
          facts: const <Fact>[],
          difficulty: FactPuzzleDifficulty.leicht,
          duration: HuntDuration.thirty,
          seed: 'probe',
        ),
        isNull,
      );
    });
  });

  group('Stationszahl', () {
    // `screen-challenge.jsx:4332` rechnet die gewählte Dauer in genau diese
    // Zahlen um. Der Test geht durch alle drei, weil die Zuordnung sonst nur
    // an einer Stelle geprüft wäre und die Dauer-Karten eine zweite ist.
    for (final HuntDuration duration in HuntDuration.values) {
      test('${duration.minutes} Minuten ergeben ${duration.stopCount} '
          'Stationen', () {
        final HuntPlan? plan = generateHuntRoute(
          facts: _gridFacts(),
          difficulty: FactPuzzleDifficulty.leicht,
          duration: duration,
          startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
        );

        expect(plan, isNotNull);
        expect(plan!.stops.length, duration.stopCount);
      });
    }

    test('keine Station kommt zweimal vor', () {
      final HuntPlan? plan = generateHuntRoute(
        facts: _gridFacts(),
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.ninety,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      final List<int> ids = _ids(plan!);
      expect(ids.toSet().length, ids.length);
    });

    test('reicht der Bestand nicht, kommt eine kürzere Jagd statt null', () {
      // Zwei Fakten, 300 Meter auseinander, angefordert sind fünf Stationen.
      // Die Quelle bricht die Schleife ab (`:298`) und liefert trotzdem einen
      // Plan; erst gar keine Kandidaten ergeben `null` (`:226`).
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 300, east: 0),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(plan, isNotNull);
      expect(plan!.stops.length, 2);
    });
  });

  group('Genre-Filter', () {
    test('greift, solange genug Fakten übrig bleiben', () {
      final List<Fact> facts = <Fact>[
        for (final Fact fact in _gridFacts())
          // Nur die Fakten mit gerader Kennung tragen das gesuchte Thema.
          fact.copyWith(genre: fact.id.value.isEven ? 'Geschichte' : 'Natur'),
      ];

      final HuntPlan? plan = generateHuntRoute(
        facts: facts,
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        genres: const <String>['Geschichte'],
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(plan!.stops.length, 5);
      expect(
        plan.stops.map((HuntStop stop) => stop.fact.genre).toSet(),
        <String>{'Geschichte'},
      );
    });

    test('wird gelockert, wenn danach zu wenige übrig blieben', () {
      // `:171-175`: der Filter fällt weg, sobald weniger als `stopCount`
      // Fakten ihn überstehen. Sonst bekäme eine Stadt mit wenigen
      // klassifizierten Fakten gar keine Jagd.
      final List<Fact> facts = <Fact>[
        for (final Fact fact in _gridFacts())
          fact.copyWith(genre: fact.id.value <= 3 ? 'Geschichte' : 'Natur'),
      ];

      final HuntPlan? plan = generateHuntRoute(
        facts: facts,
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        genres: const <String>['Geschichte'],
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(plan!.stops.length, 5);
      expect(
        plan.stops.map((HuntStop stop) => stop.fact.genre).toSet(),
        contains('Natur'),
      );
    });

    test('ein Fakt ohne Thema fällt bei gesetztem Filter heraus', () {
      final List<Fact> facts = <Fact>[
        for (final Fact fact in _gridFacts())
          if (fact.id.value <= 8) fact.copyWith(genre: 'Geschichte') else fact,
      ];

      final HuntPlan? plan = generateHuntRoute(
        facts: facts,
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        genres: const <String>['Geschichte'],
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(
        plan!.stops.every((HuntStop stop) => stop.fact.genre == 'Geschichte'),
        isTrue,
      );
    });
  });

  group('Kreisbogen statt Linie', () {
    // Beide Regeln hängen an der **Position** im Lauf: die vorletzte Station
    // wird auf 900 Meter um den Anfang eingeschränkt, die letzte auf 600
    // (`:279-290`). Seit der Generator nur noch die Dauer entgegennimmt, ist
    // diese Position bei 30 Minuten der vierte und der fünfte Stopp. Die
    // Fakten liegen deshalb so, dass der Lauf sie deterministisch erreicht;
    // die Zwischenschritte stehen im Kommentar, damit man den Lauf nachrechnen
    // kann, ohne ihn auszufuehren.

    test('die letzte Station liegt wieder nah am Anfang', () {
      // Lauf: 1 (Start) → 2 (420 m) → 3 (420 m) → 4 (424 m).
      //
      // Beim fünften Stopp stehen noch Fakt 5 (550 m vom Anfang, 716 m vom
      // letzten Stopp) und Fakt 6 (1260 m vom Anfang, 688 m vom letzten
      // Stopp). **Ohne** den Zwang gewänne 6, weil er näher am Gipfel der
      // Kurve liegt (0,407 gegen 0,335). Mit ihm bleibt nur 5 übrig.
      final List<Fact> facts = <Fact>[
        _fact(1, north: 0, east: 0),
        _fact(2, north: 420, east: 0),
        _fact(3, north: 840, east: 0),
        _fact(4, north: 700, east: 400),
        _fact(5, north: 0, east: 550),
        _fact(6, north: 1260, east: 0),
      ];

      final HuntPlan? plan = generateHuntRoute(
        facts: facts,
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 2, 3, 4, 5]);
      final double zurueckWeg = plan.stops.first.position.distanceInMetersTo(
        plan.stops.last.position,
      );
      // `:286`: höchstens 600 Meter zurück zum Anfang.
      expect(zurueckWeg, lessThanOrEqualTo(600));
    });

    test('auch die vorletzte Station wird schon zurückgezogen', () {
      // Lauf: 1 (Start) → 2 (420 m) → 3 (420 m).
      //
      // Beim vierten Stopp, dem vorletzten, stehen Fakt 4 (1260 m vom Anfang,
      // 420 m vom letzten Stopp, Wert 1,0) und Fakt 5 (533 m vom Anfang, 500 m
      // vom letzten Stopp, Wert 0,923). **Ohne** den Zwang gewänne 4. Mit ihm
      // fällt 4 heraus, und er kommt erst als letzter Stopp dran, wo alle
      // Stufen leerlaufen und die Bedingung fallengelassen wird (`:288`).
      final List<Fact> facts = <Fact>[
        _fact(1, north: 0, east: 0),
        _fact(2, north: 420, east: 0),
        _fact(3, north: 840, east: 0),
        _fact(4, north: 1260, east: 0),
        _fact(5, north: 440, east: 300),
      ];

      final HuntPlan? plan = generateHuntRoute(
        facts: facts,
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 2, 3, 5, 4]);
    });

    test('gibt es nichts in Startnähe, läuft die Jagd trotzdem weiter', () {
      // Eine Kette ohne jeden Fakt in Startnähe: `:282` und `:288` lassen die
      // Bedingung fallen, statt die Station wegzulassen.
      //
      // Zugleich der Fall, den `HuntPlan.estimatedDurationMinutes` im
      // Kommentar offen lässt: angesagt sind 30 Minuten und fünf Stationen,
      // gebaut werden vier, weil der Bestand nicht mehr hergibt. Die Ansage
      // bleibt trotzdem die gewählte Dauer, es wird nichts heruntergerechnet.
      final List<Fact> facts = <Fact>[
        _fact(1, north: 0, east: 0),
        _fact(2, north: 400, east: 0),
        _fact(3, north: 800, east: 0),
        _fact(4, north: 1200, east: 0),
      ];

      final HuntPlan? plan = generateHuntRoute(
        facts: facts,
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 2, 3, 4]);
      expect(plan.stops.length, lessThan(plan.duration.stopCount));
      expect(plan.estimatedDurationMinutes, 30);
    });
  });

  group('Erste Station', () {
    test(
      'ohne Startpunkt entscheidet der Seed, und zwar wie in der Quelle',
      () {
        // Der erwartete Wert stammt **nicht** aus einem Lauf dieser
        // Dart-Fassung: `huntHashStr` und `huntMulberry32` aus
        // `hunt-generator.jsx:18-34` wurden unverändert in Node ausgeführt. Für
        // den Seed `probe` liefert der erste Aufruf 0.4656275734305382, bei 10
        // Kandidaten also `Math.floor(0.4656… * 10) = 4`, und das ist der Fakt
        // mit der Kennung 5.
        final HuntPlan? plan = generateHuntRoute(
          facts: <Fact>[
            for (int i = 0; i < 10; i++) _fact(i + 1, north: i * 400, east: 0),
          ],
          difficulty: FactPuzzleDifficulty.leicht,
          duration: HuntDuration.thirty,
          seed: 'probe',
        );

        expect(_ids(plan!).first, 5);
      },
    );

    test('derselbe Seed liefert dieselbe Jagd', () {
      List<int> run() => _ids(
        generateHuntRoute(
          facts: _gridFacts(),
          difficulty: FactPuzzleDifficulty.leicht,
          duration: HuntDuration.thirty,
          seed: 'muc-1',
        )!,
      );

      expect(run(), run());
    });

    test('ein anderer Seed liefert eine andere erste Station', () {
      // Gegenprobe: ohne sie wäre der Test darüber auch dann grün, wenn der
      // Seed gar nicht ankommt.
      List<int> first(String seed) => _ids(
        generateHuntRoute(
          facts: <Fact>[
            for (int i = 0; i < 10; i++) _fact(i + 1, north: i * 400, east: 0),
          ],
          difficulty: FactPuzzleDifficulty.leicht,
          duration: HuntDuration.thirty,
          seed: seed,
        )!,
      );

      // `test-seed` ergibt in Node 0.35841897572390735, also Index 3.
      expect(first('test-seed').first, 4);
      expect(first('probe').first, 5);
    });

    test('mit Startpunkt gewinnt der nächstgelegene Kandidat', () {
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 900, east: 0),
          _fact(2, north: 120, east: 0),
          _fact(3, north: 460, east: 0),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!).first, 2);
    });

    test('auch wenn alle weiter als 1000 Meter entfernt sind', () {
      // Der dritte Zweig aus `:246`: keine Vorauswahl greift, es bleibt die
      // Entfernung.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 3000, east: 0),
          _fact(2, north: 1400, east: 0),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[2]);
    });
  });

  group('Auswahl der Rätsel', () {
    test('eine noch nicht gespielte Rätselform wird bevorzugt', () {
      // `:93-94`. Beide Fakten tragen dieselben zwei Formen; der zweite Stopp
      // muss die nehmen, die der erste liegen gelassen hat.
      final List<FactPuzzle> both = <FactPuzzle>[
        _puzzle(type: 'inschrift'),
        _puzzle(type: 'zaehlen'),
      ];
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0, puzzles: both),
          _fact(2, north: 420, east: 0, puzzles: both),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(plan!.stops.first.puzzle.type, 'inschrift');
      expect(plan.stops.last.puzzle.type, 'zaehlen');
    });

    test('gibt es keine neue Form, wird eine wiederholt', () {
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(
            1,
            north: 0,
            east: 0,
            puzzles: <FactPuzzle>[_puzzle(type: 'inschrift')],
          ),
          _fact(
            2,
            north: 420,
            east: 0,
            puzzles: <FactPuzzle>[_puzzle(type: 'inschrift')],
          ),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(plan!.stops.length, 2);
      expect(plan.stops.last.puzzle.type, 'inschrift');
    });

    test('die Stufe des Rätsels entscheidet, nicht die des Fakts', () {
      // Stufe 3 der Kaskade, `:212-218`, und das ist der Weg, den der heutige
      // Bestand nimmt: `confidence` steht überall auf `curated`, `quality`
      // fehlt. Der Fakt mit dem schweren Rätsel darf bei `leicht` nicht
      // vorkommen.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(
            2,
            north: 420,
            east: 0,
            puzzles: <FactPuzzle>[
              _puzzle(difficulty: FactPuzzleDifficulty.schwer),
            ],
          ),
          _fact(3, north: 840, east: 0),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 3]);
    });

    test('kommt die gewünschte Stufe gar nicht vor, gilt jedes Rätsel', () {
      // Stufe 4, `:220-224`. Sie greift erst bei **null** Kandidaten, nicht
      // schon bei zu wenigen.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(
            1,
            north: 0,
            east: 0,
            puzzles: <FactPuzzle>[
              _puzzle(difficulty: FactPuzzleDifficulty.schwer),
            ],
          ),
          _fact(
            2,
            north: 420,
            east: 0,
            puzzles: <FactPuzzle>[_puzzle(difficulty: null)],
          ),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 2]);
    });

    test('als nicht findbar markierte Fakten fliegen immer heraus', () {
      // `:186`. Die einzige Stelle des Findability-Blocks, die auch dann
      // wirkt, wenn die Stufe gelockert wird.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(
            2,
            north: 420,
            east: 0,
            puzzles: <FactPuzzle>[_puzzle(findability: FactPuzzle.notFindable)],
          ),
          _fact(3, north: 840, east: 0),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 3]);
    });
  });

  group('Bewertung', () {
    // **Zu den drei Kennungen in den Erwartungen.** Angefordert sind 30
    // Minuten, also fünf Stationen, im Bestand liegen aber nur drei Fakten.
    // Der Lauf setzt deshalb den Startpunkt, den Gewinner des Vergleichs und
    // danach den Verlierer, der als einziger Kandidat übrig ist und im
    // Ausweichfenster von 1400 Metern liegt (`:295`). Die Aussage jedes Tests
    // steckt in der **zweiten** Kennung; die dritte steht mit da, damit
    // auffällt, wenn sich sonst etwas an der Reihenfolge ändert.
    test('unter dem Mindestabstand ist der Entfernungswert 0', () {
      // `:132`, die harte Untergrenze von 220 Metern.
      expect(huntDistanceScore(219.9), 0);
      expect(huntDistanceScore(220), greaterThan(0));
    });

    test('der Gipfel liegt beim bevorzugten Abstand', () {
      // `:133`, Gaußkurve um 420 Meter mit Sigma 200. Die drei Werte stehen
      // als Zahlen da und nicht als Ausdruck über die Konstanten: eine
      // Zusicherung gegen die Konstante, die sie festnageln soll, prüft
      // nichts.
      expect(huntDistanceScore(420), closeTo(1, 1e-12));
      expect(huntDistanceScore(620), closeTo(math.exp(-0.5), 1e-12));
      expect(huntDistanceScore(820), closeTo(math.exp(-2), 1e-12));
    });

    test(
      'ein goldener Fakt schlägt einen gleich weit entfernten ohne Güte',
      () {
        // `:302-306`: 0.45 bei `quality_score` 3. Beide Kandidaten liegen 420
        // Meter vom ersten Stopp entfernt, in entgegengesetzte Richtungen, und
        // bringen dieselbe Rätselform mit; der Bonus ist damit der einzige
        // Unterschied.
        final HuntPlan? plan = generateHuntRoute(
          facts: <Fact>[
            _fact(1, north: 0, east: 0),
            _fact(2, north: 420, east: 0),
            _fact(3, north: -420, east: 0, qualityScore: 3),
          ],
          difficulty: FactPuzzleDifficulty.leicht,
          duration: HuntDuration.thirty,
          startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
        );

        expect(_ids(plan!), <int>[1, 3, 2]);
      },
    );

    test('eine frische Rätselform schlägt eine schon gespielte', () {
      // `:304-306`, der Diversitäts-Bonus von 0.3. Beide Kandidaten liegen 420
      // Meter entfernt; der eine bringt dieselbe Form mit wie der erste Stopp,
      // der andere eine neue.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 420, east: 0),
          _fact(
            3,
            north: -420,
            east: 0,
            puzzles: <FactPuzzle>[_puzzle(type: 'zaehlen')],
          ),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 3, 2]);
    });

    test('ohne Güte gewinnt der zuerst gelistete Kandidat', () {
      // Gegenprobe zum Test darüber: ohne sie wäre er auch dann grün, wenn
      // schlicht immer der zweite Fakt gewänne.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 420, east: 0),
          _fact(3, north: -420, east: 0),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 2, 3]);
    });

    test('das primäre Fenster schlägt jeden Bonus außerhalb davon', () {
      // `:292-295`: erst wird auf höchstens 850 Meter gesucht, und nur wenn
      // dort **nichts** steht, auf 1400. Der goldene Fakt liegt 900 Meter
      // entfernt und käme mit seinem Bonus von 0.45 über den näheren; er kommt
      // aber gar nicht erst zur Bewertung, weil das primäre Fenster nicht leer
      // ist.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 840, east: 0),
          _fact(3, north: -900, east: 0, qualityScore: 3),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 2]);
    });

    // ── Die vier Bonuswerte, gegen ihre Kippgrenze ──────────────────────
    //
    // Die Tests darüber prüfen nur die **Richtung** („Gold schlägt keine
    // Güte"). Damit überlebt jede Änderung des Wertes: 0,45 auf 0,55
    // ändert an der Richtung nichts, an der erzeugten Jagd sehr wohl, weil
    // die vier Boni sich gegenseitig überholen können.
    //
    // Deshalb hier je zwei Läufe um die Kippgrenze. Die Rechnung dahinter:
    // ein Kandidat im Gipfel der Gaußkurve (420 Meter) bekommt genau 1,0 und
    // sonst nichts. Ein zweiter Kandidat mit Bonus gewinnt genau dann, wenn
    // `Bonus > 1 − distScore(seine Entfernung)`. Die Entfernungen unten sind
    // so gewählt, dass diese Differenz knapp unter und knapp über dem
    // erwarteten Bonus liegt. Die Zahlen stammen aus der Gaußkurve der
    // Quelle (`:131-134`) und nicht aus den Konstanten des Codes.

    test('der Bonus für eine frische Rätselform liegt über 0,2797', () {
      // Kandidat 3 liegt 582 Meter entfernt, sein Entfernungswert ist
      // 0,72033. Er gewinnt gegen die 1,0 des näheren nur, wenn der
      // Diversitäts-Bonus größer als 0,27967 ist.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 420, east: 0),
          _fact(
            3,
            north: -582,
            east: 0,
            puzzles: <FactPuzzle>[_puzzle(type: 'zaehlen')],
          ),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 3, 2]);
    });

    test('und unter 0,3211', () {
      // Derselbe Aufbau mit 596 Metern, Entfernungswert 0,67896. Jetzt
      // bräuchte die frische Form mehr als 0,32104, um zu gewinnen. Ohne
      // diesen zweiten Lauf überlebt jeder größere Wert, etwa 0,5.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 420, east: 0),
          _fact(
            3,
            north: -596,
            east: 0,
            puzzles: <FactPuzzle>[_puzzle(type: 'zaehlen')],
          ),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 2, 3]);
    });

    test('der Gold-Bonus liegt über 0,3995', () {
      // 622 Meter, Entfernungswert 0,60047. Drei Stationen, damit die
      // Kandidaten nicht schon am Zwang der letzten Station scheitern; Fakt 4
      // ist nur Füllung für den Schlussstopp.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 420, east: 0),
          _fact(3, north: -622, east: 0, qualityScore: 3),
          _fact(4, north: 0, east: 300),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!)[1], 3);
    });

    test('und unter 0,4986', () {
      // 655 Meter, Entfernungswert 0,50142. Ein Gold-Bonus von 0,55 würde
      // hier gewinnen und fällt damit auf.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 420, east: 0),
          _fact(3, north: -655, east: 0, qualityScore: 3),
          _fact(4, north: 0, east: 300),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!)[1], 2);
    });

    test('der Silber-Bonus liegt über 0,1499', () {
      // 534 Meter, Entfernungswert 0,85006.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 420, east: 0),
          _fact(3, north: -534, east: 0, qualityScore: 2),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 3, 2]);
    });

    test('und unter 0,2508', () {
      // 572 Meter, Entfernungswert 0,74916. Ein Silber-Bonus von 0,30 würde
      // hier gewinnen.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 420, east: 0),
          _fact(3, north: -572, east: 0, qualityScore: 2),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 2, 3]);
    });

    test('Bronze bringt gar nichts', () {
      // `:302`: `{ 3: 0.45, 2: 0.20, 1: 0 }`. Beide Kandidaten liegen exakt
      // 420 Meter entfernt, in entgegengesetzte Richtungen. Bei Gleichstand
      // gewinnt der zuerst gelistete; jeder Bonus größer als null würde den
      // bronzenen nach vorn ziehen.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 420, east: 0),
          _fact(3, north: -420, east: 0, qualityScore: 1),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 2, 3]);
    });

    test('ein Fakt näher als 220 Meter kommt nicht als Nächstes dran', () {
      // `:293`. Der nahe Fakt ist nur 150 Meter entfernt und wird übersprungen,
      // obwohl er der nächste wäre. Als dritte Station kommt er trotzdem dran:
      // vom zweiten Stopp aus liegt er 270 Meter weg und damit über der
      // Untergrenze. Die Regel gilt dem Abstand zwischen zwei Stationen, nicht
      // dem Fakt.
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[
          _fact(1, north: 0, east: 0),
          _fact(2, north: 150, east: 0),
          _fact(3, north: 420, east: 0),
        ],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(_ids(plan!), <int>[1, 3, 2]);
    });
  });

  group('Der Plan', () {
    test('die angesagte Dauer ist die gewählte, nicht die geschätzte', () {
      // **E-45, entschieden am 30.08.2026.** Die Quelle rechnet
      // `estimatedDurationMin: stops.length * 14` (`hunt-generator.jsx:354`)
      // und sagt dem Nutzer damit 70 Minuten an, obwohl er unmittelbar davor
      // 30 gewaehlt hat. Der Neubau weicht hier bewusst ab: die gewählte
      // Dauer gilt.
      //
      // Die 70 steht in der Zusicherung mit, weil genau sie herauskäme, wenn
      // jemand die Rechnung der Quelle wieder einsetzt.
      final HuntPlan? plan = generateHuntRoute(
        facts: _gridFacts(),
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(plan!.stops.length, 5);
      expect(plan.estimatedDurationMinutes, 30);
      expect(plan.estimatedDurationMinutes, isNot(plan.stops.length * 14));
      expect(plan.duration, HuntDuration.thirty);
    });

    test('sie folgt der Dauer und nicht der Zahl der Stationen', () {
      // Gegenprobe mit einer anderen Dauer: eine Zusicherung allein gegen 30
      // ließe sich auch mit einer festverdrahteten 30 erfüllen.
      final HuntPlan? plan = generateHuntRoute(
        facts: _gridFacts(),
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.ninety,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(plan!.stops.length, 9);
      expect(plan.estimatedDurationMinutes, 90);
    });

    test('die Stufe der Anfrage steht im Plan', () {
      final HuntPlan? plan = generateHuntRoute(
        facts: _gridFacts(),
        difficulty: FactPuzzleDifficulty.mittel,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      expect(plan!.difficulty, FactPuzzleDifficulty.mittel);
    });

    test('der Ort einer Station ist der Ort ihres Fakts', () {
      final HuntPlan? plan = generateHuntRoute(
        facts: <Fact>[_fact(1, north: 0, east: 0)],
        difficulty: FactPuzzleDifficulty.leicht,
        duration: HuntDuration.thirty,
        startNear: const MapPosition(latitude: _lat0, longitude: _lng0),
      );

      final HuntStop stop = plan!.stops.single;
      expect(stop.position.latitude, stop.fact.coordinates!.latitude);
      expect(stop.position.longitude, stop.fact.coordinates!.longitude);
    });
  });
}

/// Marienplatz, wie in `hunt-routes.jsx:25`.
const double _lat0 = 48.1374;

/// Siehe [_lat0].
const double _lng0 = 11.5755;

/// Ein Grad Breite in Metern, mit dem Erdradius der Quelle (6371000).
const double _metersPerDegreeLatitude = 2 * math.pi * 6371000 / 360;

List<int> _ids(HuntPlan plan) =>
    plan.stops.map((HuntStop stop) => stop.fact.id.value).toList();

FactPuzzle _puzzle({
  String? type = 'inschrift',
  FactPuzzleDifficulty? difficulty = FactPuzzleDifficulty.leicht,
  String? findability,
}) {
  return FactPuzzle(
    question: 'Wie viele Löwen bewachen das Tor?',
    type: type,
    difficulty: difficulty,
    findability: findability,
    // Der Wert, der im gesamten ausgelieferten Bestand steht. Damit läuft
    // dieser Test durch dieselbe Stufe der Kaskade wie die echte App.
    confidence: 'curated',
  );
}

/// Ein Fakt [north] Meter nördlich und [east] Meter östlich von [_lat0].
Fact _fact(
  int id, {
  required double north,
  required double east,
  List<FactPuzzle>? puzzles,
  int? qualityScore,
  String? genre,
}) {
  final double latitude = _lat0 + north / _metersPerDegreeLatitude;
  final double longitude =
      _lng0 +
      east / (_metersPerDegreeLatitude * math.cos(_lat0 * math.pi / 180));
  return Fact(
    id: FactId(id),
    content: FactText(title: 'Fakt $id'),
    coordinates: FactCoordinates(latitude: latitude, longitude: longitude),
    qualityScore: qualityScore,
    genre: genre,
    puzzles: puzzles ?? <FactPuzzle>[_puzzle()],
  );
}

/// Fünf mal fünf Fakten im Abstand von 300 Metern, Kennungen 1 bis 25.
///
/// Diagonal sind das 424 Meter. Der Bestand ist absichtlich großzügig: die
/// Zusicherungen dieser Gruppe gelten der Länge der Jagd, nicht der Frage, wo
/// sie entlangführt.
List<Fact> _gridFacts() {
  final List<Fact> facts = <Fact>[];
  int id = 1;
  for (int row = -2; row <= 2; row++) {
    for (int column = -2; column <= 2; column++) {
      facts.add(_fact(id++, north: row * 300, east: column * 300));
    }
  }
  return facts;
}

extension on Fact {
  /// `copyWith` kann eine Koordinate nicht auf `null` setzen.
  Fact copyWithoutCoordinates() =>
      Fact(id: id, content: content, puzzles: puzzles);
}
