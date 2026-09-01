import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Die Wache um den Schreibweg zur laufenden Jagd.
///
/// ADR-007 Regel 2 nennt den verbotenen Griff namentlich: „Writes to hunt state
/// happen through `challenges`, never from the map screen." Der Lesezugang für
/// `discovery` ist `activeHuntProvider`, ein `Provider<ActiveHunt?>`, und der
/// hält von sich aus dicht: ein unveränderlicher Wert, kein `.notifier`.
///
/// Daneben liegt in derselben Bibliothek `activeHuntStoreProvider`, auf
/// `ActiveHuntStore` typisiert, öffentlich, mit `writeActiveHunt` und
/// `clearActiveHunt` daran. Er trägt genau die Fähigkeit, die Regel 2 verbietet,
/// erreichbar in **einer** Zeile.
///
/// ## Warum das eine Wache braucht und ein Kommentar nicht reicht
///
/// Weil der Fehlschlag stumm ist. `activeHuntProvider` merkt sich sein
/// Ergebnis, ein Schreibvorgang am Speicher erzeugt also **keine**
/// Benachrichtigung (festgehalten in `active_hunt_providers_test.dart`). Wer aus
/// `discovery` in den Speicher schreibt, bekommt keine Ausnahme und keine
/// Meldung, sondern eine Station, die nicht vorrückt. Der Fehler sieht dann aus
/// wie ein Fehler in der Karte und nicht wie einer in der Zuständigkeit, und
/// gesucht wird an der falschen Stelle.
///
/// Der Vergleich mit `mapHostRegistryProvider` trägt hier nicht, obwohl die
/// Bauform dieselbe ist: beim Karten-Host ist ein falscher Griff sichtbar, das
/// Kartenbild bewegt sich oder es bewegt sich nicht.
void main() {
  group('Kein Schreibweg aus discovery', () {
    test('keine Datei unter lib/features/discovery/ nennt den Speicher', () {
      // **Was diese Wache nicht kann**, fünf Grenzen, jede einzeln (Muster 16,
      // zweite Hälfte: wer die bekannte Grenze nicht aufschreibt, bekommt sie
      // beim ersten Fehlalarm entschärft):
      //
      //  1. Sie fängt den **Namen** und nicht den Missbrauch. Wer den Speicher
      //     über eine Zwischenschicht erreicht, etwa über eine Funktion oder
      //     einen Provider, der ihn woanders liest und weiterreicht, kommt
      //     durch. Sie ist ein Drahtseil quer über den kürzesten Weg, keine
      //     Mauer.
      //  2. Sie sieht nur `lib/features/discovery/`. Ein Schreibvorgang aus
      //     `lib/map/` oder aus der App-Komposition fällt hier nicht auf, und
      //     das ist Absicht: die Komposition liest diesen Provider zu Recht,
      //     dort hängt `bootstrap()` die persistente Umsetzung ein. Eine Suche
      //     über ganz `lib/` wäre ein Dauerfehlalarm und damit wertlos.
      //  3. Sie prüft keinen Import. Das tut `tool/check_architecture.dart`,
      //     und es kann hier nichts finden: `discovery` **darf**
      //     `challenges/application` importieren, ADR-007 verlangt es sogar für
      //     den Lesezugang. Der Import unterscheidet Lesen nicht von Schreiben.
      //     Gemessen, nicht vermutet: mit einer Probedatei unter
      //     `lib/features/discovery/presentation/`, die
      //     `ref.read(activeHuntStoreProvider).writeActiveHunt(hunt)` aufruft,
      //     lief der Architektur-Check auf Exit-Code 0 durch, während dieser
      //     Test rot war.
      //  4. Eine Umbenennung des Providers würde sie blind machen. Deshalb
      //     prüft sie zusätzlich, dass der Name in `challenges/application`
      //     überhaupt noch vorkommt: dann fällt sie bei einer Umbenennung
      //     sichtbar aus, statt still nichts mehr zu bewachen.
      //  5. Sie liest den Dateiinhalt **roh**. Ein Kommentar in `discovery`,
      //     der den Namen nennt, löst also einen Fehlalarm aus. Der ist
      //     billiger als die Vorverarbeitung, die in Schritt 27 die Wache des
      //     Rätsel-Sheets umgehbar gemacht hat. Sich selbst findet diese Datei
      //     nicht, sie liegt unter `test/`.
      final Directory discovery = Directory('lib/features/discovery');
      expect(
        discovery.existsSync(),
        isTrue,
        reason: 'ohne das Feature bewacht dieser Test nichts',
      );

      final List<String> offenders = <String>[];
      for (final File file
          in discovery
              .listSync(recursive: true)
              .whereType<File>()
              .where((File file) => file.path.endsWith('.dart'))) {
        final String source = file.readAsStringSync();
        for (final String forbidden in _writeAccessProviders) {
          if (source.contains(forbidden)) {
            offenders.add('${file.path.replaceAll(r'\', '/')} ($forbidden)');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'ADR-007 Regel 2: geschrieben wird die Jagd in `challenges`, nie '
            'vom Kartenbildschirm. Der Lesezugang ist `activeHuntProvider`.',
      );
    });

    test('die bewachten Namen existieren noch', () {
      // Grenze 4 von oben, als eigene Zusicherung. Ohne sie wäre die Wache
      // nach einer Umbenennung dauerhaft grün, ohne noch etwas zu prüfen, und
      // das ist der Zustand, den man von außen nicht sieht.
      //
      // **Seit dem 31.08.2026 sind es zwei Namen, und der zweite ist der
      // gefährlichere.** `huntRunProvider` ist ein `NotifierProvider`, und
      // `.notifier` darauf ist ein vollwertiger Schreibzugang zum Jagdzustand.
      // Der Zustandshalter selbst hat das gemeldet: die Wache kannte nur den
      // Speicher, und damit hätte ein späterer Schritt der Kartenoberfläche
      // Schreibrechte geben können, ohne dass hier etwas rot geworden wäre.
      final String providers = File(
        'lib/features/challenges/application/active_hunt_providers.dart',
      ).readAsStringSync();

      for (final String forbidden in _writeAccessProviders) {
        expect(
          providers,
          contains('$forbidden ='),
          reason:
              'Der bewachte Name $forbidden gibt es nicht mehr. Entweder ist '
              'er umbenannt, dann gehört diese Liste nachgezogen, oder er ist '
              'weg, dann bewacht diese Datei einen Namen ohne Gegenstück.',
        );
      }
    });
  });
}

/// Die Namen, die in `discovery` nicht vorkommen dürfen.
///
/// Als Konstante und nicht mehrfach ausgeschrieben, damit die Suche und die
/// Existenzprüfung nicht auseinanderlaufen können.
///
/// **Zwei Einträge, und sie sperren zwei verschiedene Wege zum selben
/// Schreibzugriff:**
///
///  * `activeHuntStoreProvider` führt am Zustandshalter vorbei direkt auf die
///    Platte. Wer ihn schreibt, ändert den gespeicherten Wert, ohne dass ein
///    Beobachter davon erfährt.
///  * `huntRunProvider` ist ein `NotifierProvider`. `.notifier` darauf ist der
///    reguläre Schreibzugang, und genau deshalb darf `discovery` ihn nicht
///    sehen. Er ist am 31.08.2026 mit dem Zustandshalter entstanden, und der
///    Bauende hat selbst gemeldet, dass die Wache ihn noch nicht kannte.
///
/// Der Lesezugang bleibt `activeHuntProvider`, ein `Provider<ActiveHunt?>` ohne
/// `.notifier`, und der steht bewusst **nicht** auf dieser Liste.
const List<String> _writeAccessProviders = <String>[
  'activeHuntStoreProvider',
  'huntRunProvider',
];
