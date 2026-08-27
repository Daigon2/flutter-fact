import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lädt die echten Schriften aus `assets/fonts/` in die Testumgebung.
///
/// ## Warum das nötig ist
///
/// `flutter test` lädt die in `pubspec.yaml` deklarierten Schriften **nicht**.
/// Stattdessen zeichnet eine Ersatzschrift jede Glyphe als Quadrat mit der
/// Kantenlänge der Schriftgröße. Jede Messung an Text ist damit falsch, und
/// zwar nicht zufällig, sondern systematisch zu breit: "FACT" belegt in Nunito
/// 900 bei Größe 64 etwa 170 Pixel, mit der Ersatzschrift 257.
///
/// Praktische Folge, gemessen: die Knopfzeile des Audio-Dialogs bricht mit der
/// Ersatzschrift schon bei Skalierung 1.0 um. Ein Test, der das prüft, prüft
/// einen Zustand, den es auf keinem Gerät gibt. Genau davor warnt
/// `docs/engineering/testing.md:219`: "Pin fonts/assets and control
/// dimensions."
///
/// ## Warum diese Datei nicht bei einem Feature liegt
///
/// `docs/engineering/testing.md:215` verlangt Fixtures beim besitzenden Feature
/// und warnt vor einem globalen Fixture-Lager. Das gilt für **fachliche**
/// Fixtures. Hier geht es um die Testumgebung selbst: die Schriften sind ein
/// Projekt-Asset, kein Fakt und keine Stadt, und jeder Bildschirm in jedem
/// Feature braucht dieselben. Eine Kopie je Feature wäre die schlechtere
/// Antwort.
///
/// ## Gültigkeitsbereich
///
/// Nötig in jedem Test, der **Maße, Überlauf oder Umbruch** prüft. Wer nur
/// prüft, ob ein Text da ist oder ein Tipp ankommt, braucht es nicht: `find.text`
/// vergleicht Zeichenketten und interessiert sich nicht für Glyphenbreiten.
///
/// ## Aufruf ausschließlich aus `setUpAll`, nicht im Rumpf eines `testWidgets`
///
/// Gemessen, nicht befürchtet: ein `await loadAppFonts()` **innerhalb** von
/// `testWidgets` hängt und läuft in die Zeitüberschreitung. `testWidgets`
/// führt seinen Rumpf in einer `FakeAsync`-Zone aus, in der echte
/// Ein-/Ausgabe und der Aufruf an die Engine nie fortschreiten. `setUpAll`
/// läuft außerhalb dieser Zone. Wer es doch im Test braucht, muss
/// `tester.runAsync` benutzen.
///
/// Mehrfache Aufrufe sind billig, siehe [_loaded].
///
/// ## Gewichte
///
/// Ein [FontLoader] nimmt mehrere Schnitte unter demselben Familiennamen; die
/// Zuordnung Gewicht zu Datei liest die Engine aus der Schriftdatei selbst,
/// nicht aus der Reihenfolge hier. Geladen wird deshalb dieselbe Liste wie in
/// `pubspec.yaml`, inklusive Nunito 600, das aus der variablen Schrift
/// herausgeschnitten wurde.
Future<void> loadAppFonts() async {
  if (_loaded) {
    return;
  }
  // `pumpWidget` allein reicht nicht: ohne Binding gibt es keine Engine, die
  // eine Schrift annehmen könnte.
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final entry in _fontFamilies.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(_read(asset));
    }
    await loader.load();
  }
  _loaded = true;
}

/// Einmal je Testprozess. `flutter test` startet je Datei einen eigenen
/// Isolate, das Flag ist also nicht dateiübergreifend.
bool _loaded = false;

/// Dieselben Familien und Dateien wie im Abschnitt `fonts:` von `pubspec.yaml`.
/// Weicht diese Liste dort ab, messen Tests etwas anderes als die App zeichnet.
const Map<String, List<String>> _fontFamilies = <String, List<String>>{
  'Nunito': <String>[
    'assets/fonts/Nunito-SemiBold.ttf',
    'assets/fonts/Nunito-Bold.ttf',
    'assets/fonts/Nunito-ExtraBold.ttf',
    'assets/fonts/Nunito-Black.ttf',
  ],
  'DMSans': <String>[
    'assets/fonts/DMSans-Regular.ttf',
    'assets/fonts/DMSans-Medium.ttf',
    'assets/fonts/DMSans-SemiBold.ttf',
  ],
  'JetBrainsMono': <String>[
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/JetBrainsMono-Medium.ttf',
    'assets/fonts/JetBrainsMono-SemiBold.ttf',
  ],
};

/// Liest die Datei synchron vom Dateisystem und nicht über `rootBundle`.
///
/// `rootBundle` liefert in `flutter test` nur, was im Asset-Manifest steht, und
/// Schriftdateien stehen dort unter `FontManifest.json` statt unter den Assets.
/// Der Weg über `File` ist unabhängig davon und scheitert laut, wenn eine Datei
/// fehlt: eine still nicht geladene Schrift wäre der Fehler, den dieser Helfer
/// verhindern soll.
///
/// Synchron gelesen und in ein `SynchronousFuture` gepackt: [FontLoader.addFont]
/// verlangt ein `Future`, und ein echtes würde in einer `FakeAsync`-Zone nie
/// erfüllt.
Future<ByteData> _read(String assetPath) {
  final file = File(assetPath);
  if (!file.existsSync()) {
    throw StateError(
      'Schriftdatei "$assetPath" nicht gefunden. `flutter test` läuft im '
      'Paketwurzel-Verzeichnis; von woanders aus gestartet, findet dieser '
      'Helfer die Assets nicht.',
    );
  }
  return SynchronousFuture<ByteData>(
    ByteData.sublistView(file.readAsBytesSync()),
  );
}
