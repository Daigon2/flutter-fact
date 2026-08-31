import 'dart:convert';
import 'dart:io';

import 'package:fact_app/features/challenges/domain/entities/active_hunt.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Lesemodell der laufenden Jagd und seine Prüfregeln.
///
/// ## Warum die Eingaben so gewählt sind
///
/// Muster 21 in „Wie Tests hier blind werden": zwei Verhalten, die bei den
/// gewählten Eingaben zufällig dasselbe liefern, sind nicht unterscheidbar.
/// Deshalb ist hier jede Zahl so gewählt, dass eine naheliegende Verwechslung
/// ein **anderes** Ergebnis erzwingt:
///
/// * Station 3 von 7: eine Vertauschung ergäbe „7 von 3" und fällt an der
///   Prüfung `stationOrdinal <= stationCount` durch.
/// * Länge 170,5 Grad: als Breitengrad gelesen liegt sie außerhalb von ±90, ein
///   vertauschtes Lesen der Nutzlast wird also verworfen statt still zu
///   gelingen.
/// * Dauer 30 Minuten (fünf Stationen laut [HuntDuration]) bei sieben
///   Stationen: wer [ActiveHunt.stationCount] aus der Dauer ableitete, bekäme
///   5 statt 7.
/// * Ein gekaufter Hinweis, nicht null und nicht so viele wie die Minutenzahl.
void main() {
  /// Kurzform von [ActiveHunt.tryFrom] mit gültigen Vorgaben, damit jeder
  /// Prüftest genau **ein** Feld nennt.
  ActiveHunt? checked({
    int stationOrdinal = 3,
    int stationCount = 7,
    String stationTitle = 'Glyptothek',
    double stationLatitude = 48.1467,
    double stationLongitude = 170.5,
    int purchasedHintCount = 1,
    HuntDuration duration = HuntDuration.thirty,
  }) => ActiveHunt.tryFrom(
    stationOrdinal: stationOrdinal,
    stationCount: stationCount,
    stationTitle: stationTitle,
    stationLatitude: stationLatitude,
    stationLongitude: stationLongitude,
    purchasedHintCount: purchasedHintCount,
    duration: duration,
  );

  /// Dieselben Vorgaben, aber nicht nullbar, für jeden Test, der eine fertige
  /// Jagd braucht.
  ///
  /// Führt über [checked] und damit über [ActiveHunt.tryFrom], weil der
  /// Konstruktor privat ist. Das `!` ist dabei selbst eine Zusicherung: wäre
  /// eine dieser Vorgaben ungültig, bräche jeder Test dieser Datei mit einem
  /// Null-Check-Fehler ab, statt an einer harmlosen Stelle grün zu bleiben.
  ActiveHunt munich({
    int stationOrdinal = 3,
    int stationCount = 7,
    String stationTitle = 'Glyptothek',
    double stationLatitude = 48.1467,
    double stationLongitude = 170.5,
    int purchasedHintCount = 1,
    HuntDuration duration = HuntDuration.thirty,
  }) => checked(
    stationOrdinal: stationOrdinal,
    stationCount: stationCount,
    stationTitle: stationTitle,
    stationLatitude: stationLatitude,
    stationLongitude: stationLongitude,
    purchasedHintCount: purchasedHintCount,
    duration: duration,
  )!;

  Map<String, Object?> payload({
    Object? version = 1,
    Object? stationOrdinal = 3,
    Object? stationCount = 7,
    Object? stationTitle = 'Glyptothek',
    Object? latitude = 48.1467,
    Object? longitude = 170.5,
    Object? purchasedHints = 1,
    Object? durationMinutes = 30,
  }) => <String, Object?>{
    'v': version,
    'stationOrdinal': stationOrdinal,
    'stationCount': stationCount,
    'stationTitle': stationTitle,
    'lat': latitude,
    'lng': longitude,
    'purchasedHints': purchasedHints,
    'durationMinutes': durationMinutes,
  };

  group('tryFrom', () {
    test('nimmt eine gültige Jagd an und behält jedes Feld', () {
      final ActiveHunt? hunt = ActiveHunt.tryFrom(
        stationOrdinal: 3,
        stationCount: 7,
        stationTitle: 'Glyptothek',
        stationLatitude: 48.1467,
        stationLongitude: 170.5,
        purchasedHintCount: 1,
        duration: HuntDuration.thirty,
      );

      expect(hunt, isNotNull);
      expect(hunt!.stationOrdinal, 3);
      expect(hunt.stationCount, 7);
      expect(hunt.stationTitle, 'Glyptothek');
      expect(hunt.stationLatitude, 48.1467);
      expect(hunt.stationLongitude, 170.5);
      expect(hunt.purchasedHintCount, 1);
      expect(hunt.duration, HuntDuration.thirty);
      // Die Stationszahl kommt **nicht** aus der Dauer. `HuntPlan` beschreibt
      // den Fall ausdrücklich: findet der Generator weniger Stationen als die
      // Dauer vorsieht, laufen die beiden auseinander.
      expect(hunt.duration.stopCount, 5);
    });

    test('verwirft eine Station außerhalb der Stationszahl', () {
      expect(checked(stationOrdinal: 0), isNull);
      expect(checked(stationOrdinal: 8, stationCount: 7), isNull);
      expect(checked(stationOrdinal: 7, stationCount: 7), isNotNull);
      expect(checked(stationOrdinal: -3), isNull);
    });

    test('eine Stationszahl unter eins fällt an der Ordinalregel durch', () {
      // **Der Name sagt jetzt, welche Regel greift**, und das ist der ganze
      // Punkt dieser Korrektur. Vorher hieß der Test „verwirft eine Jagd ohne
      // Station" und las sich wie der Test einer eigenen Wache
      // `stationCount < 1`. Diese Wache gab es, und sie war **bei jeder
      // Eingabe** unerreichbar: `stationOrdinal >= 1 && stationOrdinal <=
      // stationCount` erzwingt `stationCount >= 1` bereits. Zwei Mutationen
      // haben es belegt, `< 1` zu `< 0` und die ganze Bedingung zu `false`,
      // beide grün. Die Eingabe hier fiel die ganze Zeit an
      // `stationOrdinal > stationCount` durch. Muster 21 wörtlich, dazu
      // Muster 9. Die Wache ist entfernt, die Zusicherung bleibt: eine Jagd
      // ohne Station kommt nicht durch.
      expect(checked(stationOrdinal: 1, stationCount: 0), isNull);
      expect(checked(stationOrdinal: 1, stationCount: -4), isNull);
      expect(checked(stationOrdinal: 1, stationCount: 1), isNotNull);
    });

    test('verwirft eine negative Zahl gekaufter Hinweise', () {
      expect(checked(purchasedHintCount: -1), isNull);
      expect(checked(purchasedHintCount: 0), isNotNull);
    });

    test('verwirft eine Lage außerhalb der Erde und jede nicht-endliche', () {
      expect(checked(stationLatitude: 90.1), isNull);
      expect(checked(stationLatitude: -90.1), isNull);
      expect(checked(stationLongitude: 180.1), isNull);
      expect(checked(stationLongitude: -180.1), isNull);
      // Zwei Wachen mit klarer Arbeitsteilung, und Muster 21 verlangt, sie zu
      // benennen: `NaN` fällt an der eigenen NaN-Wache, weil **jeder**
      // Vergleich mit `NaN` falsch ist und `double.nan.abs() > 90` deshalb
      // nicht anschlägt. Die beiden Unendlichkeiten fallen an der
      // Bereichsregel und brauchen keine eigene Wache. Fallen muss alles drei,
      // sonst wirft `jsonEncode` später auf der Nutzlast.
      expect(checked(stationLatitude: double.nan), isNull);
      expect(checked(stationLongitude: double.nan), isNull);
      expect(checked(stationLatitude: double.infinity), isNull);
      expect(checked(stationLatitude: double.negativeInfinity), isNull);
      expect(checked(stationLongitude: double.infinity), isNull);
      expect(checked(stationLongitude: double.negativeInfinity), isNull);
      // Die Grenze ist einschließend, wie in `FactCoordinates.tryFrom`.
      expect(checked(stationLatitude: 90), isNotNull);
      expect(checked(stationLongitude: -180), isNotNull);
    });

    test('nimmt einen leeren Titel an', () {
      // `Fact.canonicalTitle` fällt selbst auf eine leere Zeichenkette zurück.
      // Eine Jagd deswegen zu verwerfen hieße: Spielstand weg, weil eine
      // Überschrift fehlt.
      expect(checked(stationTitle: ''), isNotNull);
    });

    test('höher als drei gekaufte Hinweise wird bewusst nicht verworfen', () {
      // Die Obergrenze wäre heute ableitbar (drei Hinweise je Fakt, der erste
      // gratis). Sie hängt aber an der Preistabelle aus Schritt 37, und eine
      // gültige Nutzlast zu verwerfen ist der teurere Fehler. Der Test hält
      // die Entscheidung fest, damit sie nicht als Versehen gilt.
      expect(checked(purchasedHintCount: 9), isNotNull);
    });
  });

  group('Nutzlast', () {
    test('die Fassung ist 1', () {
      // Absichtlich gegen die Zahl und nicht gegen die Konstante, siehe
      // Muster 18: `expect(x.payloadVersion, ActiveHunt.payloadVersion)` wäre
      // immer wahr.
      expect(ActiveHunt.payloadVersion, 1);
    });

    test('die Schlüssel und Werte stehen fest', () {
      // Das ist der Vertrag mit der Platte. Ein umbenannter Schlüssel bleibt
      // im Hin-und-Zurück-Test unsichtbar, weil derselbe Code schreibt und
      // liest; erst diese Zusicherung sieht ihn.
      expect(munich().toPayload(), <String, Object?>{
        'v': 1,
        'stationOrdinal': 3,
        'stationCount': 7,
        'stationTitle': 'Glyptothek',
        'lat': 48.1467,
        'lng': 170.5,
        'purchasedHints': 1,
        'durationMinutes': 30,
      });
    });

    test('hin und zurück ergibt denselben Wert', () {
      final ActiveHunt written = munich(duration: HuntDuration.ninety);

      final ActiveHunt? read = ActiveHunt.tryFromPayload(written.toPayload());

      expect(read, written);
      expect(identical(read, written), isFalse);
    });

    test('eine Koordinate ohne Nachkommastelle kommt als int zurück', () {
      // `jsonDecode` liefert für `11` ein `int`, nicht `11.0`. Wer nur `double`
      // annimmt, verwirft eine Station auf einem ganzen Grad.
      final ActiveHunt? hunt = ActiveHunt.tryFromPayload(
        payload(latitude: 48, longitude: 11),
      );

      expect(hunt, isNotNull);
      expect(hunt!.stationLatitude, 48.0);
      expect(hunt.stationLongitude, 11.0);
    });

    test('eine gültige Nutzlast wird nicht vertauscht gelesen', () {
      final ActiveHunt? hunt = ActiveHunt.tryFromPayload(payload());

      expect(hunt, isNotNull);
      expect(hunt!.stationLatitude, 48.1467);
      expect(hunt.stationLongitude, 170.5);
      expect(hunt.stationOrdinal, 3);
      expect(hunt.stationCount, 7);
      expect(hunt.purchasedHintCount, 1);
      expect(hunt.duration, HuntDuration.thirty);
    });

    test('eine Nutzlast aus `jsonDecode` wird angenommen', () {
      // `jsonDecode` liefert `Map<String, dynamic>`, nicht
      // `Map<String, Object?>`. Ein zu enger Typtest hier verwürfe **jede**
      // gespeicherte Jagd, und zwar erst auf dem Gerät.
      final Map<String, dynamic> decoded = <String, dynamic>{
        ...munich().toPayload(),
      };

      expect(ActiveHunt.tryFromPayload(decoded), munich());
    });

    test('was keine Abbildung ist, wird verworfen', () {
      expect(ActiveHunt.tryFromPayload(null), isNull);
      expect(ActiveHunt.tryFromPayload('active_challenge'), isNull);
      expect(ActiveHunt.tryFromPayload(<Object?>[1, 2, 3]), isNull);
      expect(ActiveHunt.tryFromPayload(42), isNull);
      expect(ActiveHunt.tryFromPayload(<Object?, Object?>{}), isNull);
    });

    test('eine fremde Fassung wird verworfen und nicht gelesen', () {
      // Beide Richtungen: die ältere Nutzlast einer früheren Fassung und die
      // neuere eines Downgrades. Reparieren ist ausdrücklich verboten
      // (ADR-007).
      expect(ActiveHunt.tryFromPayload(payload(version: 0)), isNull);
      expect(ActiveHunt.tryFromPayload(payload(version: 2)), isNull);
      expect(ActiveHunt.tryFromPayload(payload(version: '1')), isNull);
      // Eine `1.0` kommt durch, und das ist kein Versehen: in Dart ist
      // `1.0 == 1` wahr. Eine Fassungsnummer, die als Kommazahl auf der Platte
      // landet, meint dieselbe Fassung, und daran eine Jagd zu verwerfen wäre
      // Strenge ohne Gewinn.
      expect(ActiveHunt.tryFromPayload(payload(version: 1.0)), isNotNull);
      expect(ActiveHunt.tryFromPayload(payload(version: null)), isNull);
    });

    test('ein fehlendes Feld wird verworfen', () {
      for (final String key in <String>[
        'stationOrdinal',
        'stationCount',
        'stationTitle',
        'lat',
        'lng',
        'purchasedHints',
        'durationMinutes',
      ]) {
        final Map<String, Object?> broken = payload()..remove(key);

        expect(
          ActiveHunt.tryFromPayload(broken),
          isNull,
          reason: 'ohne $key ist die Nutzlast unlesbar',
        );
      }
    });

    test('ein Feld mit falschem Typ wird verworfen', () {
      expect(ActiveHunt.tryFromPayload(payload(stationOrdinal: '3')), isNull);
      expect(ActiveHunt.tryFromPayload(payload(stationOrdinal: 3.0)), isNull);
      expect(ActiveHunt.tryFromPayload(payload(stationCount: 7.5)), isNull);
      expect(ActiveHunt.tryFromPayload(payload(stationTitle: 7)), isNull);
      expect(ActiveHunt.tryFromPayload(payload(latitude: '48.1')), isNull);
      expect(ActiveHunt.tryFromPayload(payload(longitude: true)), isNull);
      expect(ActiveHunt.tryFromPayload(payload(purchasedHints: '1')), isNull);
      expect(ActiveHunt.tryFromPayload(payload(durationMinutes: '30')), isNull);
    });

    test('eine unbekannte Dauer wird verworfen', () {
      // Die Quelle hätte hier eine 6 als Ersatz gesetzt
      // (`screen-challenge.jsx:4333`, `|| 6`). Das ist genau die Reparatur,
      // die ADR-007 verbietet: aus einer kaputten Nutzlast würde eine
      // plausibel aussehende Jagd mit einer Dauer, die niemand gewählt hat.
      expect(ActiveHunt.tryFromPayload(payload(durationMinutes: 45)), isNull);
      expect(ActiveHunt.tryFromPayload(payload(durationMinutes: 0)), isNull);
      expect(
        ActiveHunt.tryFromPayload(payload(durationMinutes: 30)),
        isNotNull,
      );
      expect(
        ActiveHunt.tryFromPayload(payload(durationMinutes: 60)),
        isNotNull,
      );
      expect(
        ActiveHunt.tryFromPayload(payload(durationMinutes: 90)),
        isNotNull,
      );
    });

    test('eine formal lesbare, aber unmögliche Nutzlast wird verworfen', () {
      // Der Weg über `tryFrom` ist der Punkt: die Typprüfung allein würde das
      // durchlassen.
      expect(ActiveHunt.tryFromPayload(payload(stationOrdinal: 9)), isNull);
      expect(ActiveHunt.tryFromPayload(payload(stationCount: 0)), isNull);
      expect(ActiveHunt.tryFromPayload(payload(purchasedHints: -1)), isNull);
      expect(ActiveHunt.tryFromPayload(payload(latitude: 91)), isNull);
      expect(ActiveHunt.tryFromPayload(payload(longitude: -181)), isNull);
    });
  });

  group('Der Weg zu einem Wert ist zu', () {
    test('eine Nutzlast übersteht jsonEncode und jsonDecode', () {
      // **Das ist die Zusicherung, die vorher fehlte.** Der Vertrag von
      // `ActiveHuntStore.writeActiveHunt` verspricht, nicht zu werfen, und der
      // Kopfkommentar von `tryFromPayload` schreibt der Datenschicht vor, keine
      // eigene Prüfung zu enthalten. Solange der Konstruktor offen war, war
      // beides gleichzeitig unmöglich: eine Jagd mit `NaN`, `+Infinity` oder
      // `-Infinity` als Lage war über den öffentlichen Konstruktor erreichbar,
      // `writeActiveHunt` nahm sie an, und `jsonEncode(hunt.toPayload())` warf
      // dann `JsonUnsupportedObjectError`.
      expect(
        jsonDecode(jsonEncode(munich().toPayload())),
        munich().toPayload(),
      );
    });

    test('keine nicht-endliche Lage kommt in eine Jagd hinein', () {
      // Beide Zugänge, weil beide gebraucht werden: `tryFrom` für die
      // Projektion aus einem Plan, `tryFromPayload` für die Platte. Ein
      // `jsonDecode` kann `NaN` nicht erzeugen, aber `tryFromPayload` nimmt
      // absichtlich `Object?` aus einer ungeprüften Quelle, und dann ist die
      // Frage berechtigt.
      for (final double value in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(checked(stationLatitude: value), isNull, reason: 'lat $value');
        expect(checked(stationLongitude: value), isNull, reason: 'lng $value');
        expect(
          ActiveHunt.tryFromPayload(payload(latitude: value)),
          isNull,
          reason: 'Nutzlast mit lat $value',
        );
        expect(
          ActiveHunt.tryFromPayload(payload(longitude: value)),
          isNull,
          reason: 'Nutzlast mit lng $value',
        );
      }
    });

    test('die Datei erklärt keinen öffentlichen Konstruktor', () {
      // **Warum eine Textsuche für etwas, das der Übersetzer hält:** der
      // Übersetzer hält nur, dass der private Konstruktor privat ist. Wer
      // daneben einen zweiten, öffentlichen erklärt, bricht keinen Test dieser
      // Suite. Die Lücke wäre zurück, und rot würde nichts.
      //
      // **Was diese Wache nicht kann**, drei Grenzen, jede einzeln (Muster 16):
      //
      //  1. Sie fällt bei einer Umbenennung der Klasse, ohne dass etwas
      //     kaputt ist. Der Preis ist eine Zeile hier.
      //  2. Sie sieht keine Fabrik, die die Prüfung umgeht. Ein
      //     `factory ActiveHunt.of(...)` **in derselben Datei** erreicht den
      //     privaten Konstruktor und heißt nicht `ActiveHunt({`.
      //  3. Sie prüft die Erklärung und nicht die Prüfregeln dahinter. Wer
      //     `tryFrom` aushöhlt, kommt hier durch.
      //  4. Sie sucht am **Zeilenanfang**, weil eine Erklärung dort steht und
      //     die Datei sich sonst über ihren eigenen Kopfkommentar selbst
      //     auslöste (Muster 16, erste Hälfte). Eine Erklärung, die hinter
      //     anderem Code auf derselben Zeile klebt, entgeht ihr deshalb.
      //     `dart format` erzeugt so eine Zeile nicht, und der Dateiinhalt
      //     wird trotzdem **nicht** vorverarbeitet: genau das hat die Wache des
      //     Rätsel-Sheets umgehbar gemacht.
      final String source = File(
        'lib/features/challenges/domain/entities/active_hunt.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('const ActiveHunt._({'),
        reason: 'der geprüfte Weg muss der einzige bleiben',
      );
      expect(
        _publicConstructor.hasMatch(source),
        isFalse,
        reason:
            'ein öffentlicher Konstruktor nimmt eine ungültige Jagd an, die '
            'erst beim nächsten Start der App verschwindet',
      );
    });
  });

  group('Gleichheit', () {
    test('zwei gleich gefüllte Jagden sind gleich', () {
      final ActiveHunt one = munich();
      final ActiveHunt two = munich();

      // Muster 7: `const` würde beide Seiten kanonisieren, und der Test
      // prüfte dann nichts. Deshalb erst der Nachweis, dass es zwei Objekte
      // sind.
      expect(identical(one, two), isFalse);
      expect(one, two);
      expect(one.hashCode, two.hashCode);
    });

    test('jedes Feld zählt für die Gleichheit', () {
      final ActiveHunt reference = munich();

      expect(reference, isNot(munich(stationOrdinal: 4)));
      expect(reference, isNot(munich(stationCount: 8)));
      expect(reference, isNot(munich(stationTitle: 'Alte Pinakothek')));
      expect(reference, isNot(munich(stationLatitude: 48.1468)));
      expect(reference, isNot(munich(stationLongitude: 170.6)));
      expect(reference, isNot(munich(purchasedHintCount: 2)));
      expect(reference, isNot(munich(duration: HuntDuration.sixty)));
    });

    test('ein anderer Typ ist nicht gleich', () {
      expect(munich(), isNot('ActiveHunt(Station 3/7)'));
    });

    test('keine Jagd kann sich selbst ungleich sein', () {
      // In Dart ist `double.nan == double.nan` **falsch**, und `NaN` ist damit
      // die einzige Möglichkeit, die Reflexivität dieser Gleichheit zu
      // brechen: eine Jagd mit `NaN`-Lage wäre sich selbst nicht gleich. In
      // einem `Provider<ActiveHunt?>` sähe dann jede Neuberechnung wie eine
      // Änderung aus, und die Karte würde ohne Anlass neu aufgebaut.
      //
      // Der Nachweis hat zwei Hälften, und die erste ist die wichtige: die
      // Eigenschaft von `NaN` ist echt, sie ist hier nicht bloß behauptet.
      // Deshalb ist die zweite Hälfte, dass es keinen Weg zu so einer Jagd
      // gibt, überhaupt eine Aussage.
      // Über eine Variable, weil `dart analyze` den direkten Vergleich mit
      // `double.nan` als `unnecessary_nan_comparison` meldet: der Übersetzer
      // weiß, dass er immer falsch ist. Das ist kein Grund, die Zusicherung
      // wegzulassen, sondern eine Bestätigung von außen.
      final double notANumber = double.nan;
      expect(notANumber == notANumber, isFalse);
      expect(checked(stationLatitude: double.nan), isNull);
      expect(checked(stationLongitude: double.nan), isNull);

      final ActiveHunt hunt = munich();
      expect(hunt == hunt, isTrue);
    });
  });

  test('toString nennt weder Lage noch Titel', () {
    // `security.md` §6 verbietet genaue Standortangaben im Log, und der Titel
    // der Station, an der jemand gerade steht, ist eine Standortangabe in
    // Worten. Dieselbe Entscheidung wie in `FactCoordinates.toString()`.
    final String text = munich().toString();

    expect(text, 'ActiveHunt(Station 3/7)');
    expect(text, isNot(contains('Glyptothek')));
    expect(text, isNot(contains('48.1')));
    expect(text, isNot(contains('170')));
  });
}

/// Eine **Erklärung** eines öffentlichen Konstruktors von `ActiveHunt`, am
/// Zeilenanfang und in allen drei Formen, die Dart dafür kennt: `const`,
/// `factory` und der schlichte generative Konstruktor.
final RegExp _publicConstructor = RegExp(
  r'^\s*(?:const\s+|factory\s+)?ActiveHunt\s*\(',
  multiLine: true,
);
