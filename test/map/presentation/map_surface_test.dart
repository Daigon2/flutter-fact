import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/presentation/map_camera_host.dart';
import 'package:fact_app/map/presentation/map_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Die Kartenfläche als Widget.
///
/// ## Was ein Widget-Test hier **nicht** kann, und das ist der größere Teil
///
/// **Es entsteht nie ein `MapLibreMapController`.** `MapLibreMap.build` gibt
/// eine Plattform-Ansicht zurück (`method_channel_maplibre_gl.dart:133-185`),
/// und ohne Plattformkanal läuft `onPlatformViewCreated` nie; damit erreicht
/// `maplibre_map.dart:390-418` seinen Controller nicht. Folge: `onMapCreated`
/// wird hier **nie** gerufen, der Host bekommt keine Karte, und keine einzige
/// Kamerabewegung ist auf diesem Weg prüfbar.
///
/// Diese Datei sichert deshalb nur zu, was ohne Karte sichtbar ist: die
/// Fläche, die Optionen, mit denen die Karte gemountet wird, und die An- und
/// Abmeldung des Hosts. Alles Weitere prüft `map_camera_host_test.dart` ohne
/// Widget, und die Verdrahtung zum SDK bleibt eine Gerätefrage.
///
/// ## Warum hier Rom steht und nicht München
///
/// **Absichtlich eine andere Stadt und vier andere Zahlen als
/// `MapPage.placeholderCamera`.** Vorher stand hier dasselbe Literal noch
/// einmal: zwei Quellen für dieselbe Zahl, und keine davon zugesichert.
/// Änderte jemand die Startkamera der App auf Zoom 9, blieb dieser Test grün,
/// weil er seine eigene Kopie mitbrachte.
///
/// Jetzt tragen die beiden verschiedene Werte, und das misst mehr als vorher:
/// dass die Fläche die Kamera **von außen** nimmt und keine eigene erfindet,
/// ist nur an Werten sichtbar, die nirgends sonst im Code stehen.
/// Mehrstädtigkeit ist eine globale Invariante, München ist Startinhalt.
/// Festgenagelt wird `MapPage.placeholderCamera` dort, wo sie hingehört, in
/// `test/features/discovery/presentation/pages/map_page_test.dart`.
const MapCameraView startCamera = MapCameraView(
  center: MapPosition(latitude: 41.9028, longitude: 12.4964),
  zoom: 12.5,
  bearing: 45,
  pitch: 21,
);

class RecordingSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);

  List<String> get names =>
      events.map((DiagnosticEvent event) => event.name).toList();
}

MapCameraOneShot skyFall() => const MapCameraOneShot(
  change: MapCameraChange(zoom: 16.5, pitch: 58, bearing: 0),
  motion: MapCameraAnimated(Duration(milliseconds: 1200)),
  origin: MapCameraIntentOrigin.discovery,
);

void main() {
  late RecordingSink sink;
  late ProviderContainer container;

  setUp(() {
    // **Ohne das lädt der Stil ab dem zweiten Test nie.** `rootBundle` ist ein
    // `CachingAssetBundle` und merkt sich das `Future` je Schlüssel. Der erste
    // Test hier stößt den Ladevorgang bewusst an, ohne ihn abzuwarten; das
    // `Future` bleibt in der `FakeAsync`-Zone dieses Tests liegen und wird nie
    // erfüllt. Jeder folgende Test bekäme genau dieses tote `Future` zurück und
    // sähe eine Karte, die ewig lädt.
    rootBundle.clear();
    sink = RecordingSink();
    container = ProviderContainer(
      overrides: [diagnosticSinkProvider.overrideWithValue(sink)],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpSurface(WidgetTester tester, {Widget? child}) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: FactTheme.light(),
          home: Scaffold(
            body: child ?? const MapSurface(initialCamera: startCamera),
          ),
        ),
      ),
    );
  }

  testWidgets('zeigt die Kartenfarbe, solange der Stil nicht geladen ist', (
    tester,
  ) async {
    // Ohne `pumpAndSettle`: der Stil kommt aus einem `Future`, und genau
    // dieser Moment ist der Platzhalter.
    await pumpSurface(tester);

    expect(find.byType(MapLibreMap), findsNothing);
    final ColoredBox box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(MapSurface),
        matching: find.byType(ColoredBox),
      ),
    );
    final BuildContext context = tester.element(find.byType(MapSurface));
    expect(box.color, context.factColors.mapBg);
  });

  testWidgets('mountet danach die Karte mit dem gebackenen Stil', (
    tester,
  ) async {
    await pumpSurface(tester);
    await tester.pumpAndSettle();

    final MapLibreMap map = tester.widget<MapLibreMap>(
      find.byType(MapLibreMap),
    );
    final String baked = await rootBundle.loadString(factMapStyleAsset);
    // Der ganze Stil, nicht ein Pfad: `styleString` nimmt laut eigener Doku
    // auch rohes JSON, und so ist belegt, dass wirklich der gebackene Stil
    // ankommt und nicht der Standardstil des Pakets.
    expect(map.styleString, baked);
    expect(map.styleString, isNot(MapLibreStyles.demo));
  });

  testWidgets('verlangt Kamerarückmeldung und reicht stabile Rückrufe durch', (
    tester,
  ) async {
    await pumpSurface(tester);
    await tester.pumpAndSettle();

    final MapLibreMap map = tester.widget<MapLibreMap>(
      find.byType(MapLibreMap),
    );
    // Ohne `trackCameraPosition` gibt es überhaupt keine Kamerarückmeldung:
    // auf Android kehrt `onCameraMove()` sofort zurück, auf iOS liefert
    // `getCamera()` `nil`. Der ganze Host hinge in der Luft.
    expect(map.trackCameraPosition, isTrue);
    expect(map.onCameraMove, isNotNull);
    expect(map.onCameraIdle, isNotNull);
    expect(map.onMapCreated, isNotNull);
  });

  testWidgets('reicht dieselben Rückrufe über einen Neuaufbau hinweg durch', (
    tester,
  ) async {
    // `maplibre_map.dart:406-410` liest die beiden Rückrufe **genau einmal**,
    // bei der Erzeugung des Controllers. Eine beim Bauen erzeugte Closure wäre
    // damit für immer die erste Fassung. Der Test misst die Gleichheit über
    // zwei Aufbauten hinweg, und eine Closure-Literal-Fassung fällt hier
    // sofort durch.
    await pumpSurface(tester);
    await tester.pumpAndSettle();
    final MapLibreMap first = tester.widget<MapLibreMap>(
      find.byType(MapLibreMap),
    );

    await tester.pump();
    tester.element(find.byType(MapSurface)).markNeedsBuild();
    await tester.pump();
    final MapLibreMap second = tester.widget<MapLibreMap>(
      find.byType(MapLibreMap),
    );

    // Gleichheit und nicht `identical`: Darts Sprachvertrag sagt für zwei
    // Tear-offs derselben Methode desselben Objekts `==` zu, `identical` aber
    // ausdrücklich nicht, und gemessen ist es hier auch nicht identisch. Für
    // die Frage, um die es geht, reicht `==` vollkommen: ein beim Bauen
    // erzeugtes Closure-Literal ist niemals gleich dem des vorigen Aufbaus.
    expect(first.onCameraMove, second.onCameraMove);
    expect(first.onCameraIdle, second.onCameraIdle);
  });

  testWidgets('startet mit der Kamera, die von außen kommt', (tester) async {
    // Mehrstädtigkeit: die Startkamera steht nicht im Karten-Host.
    await pumpSurface(tester);
    await tester.pumpAndSettle();

    final MapLibreMap map = tester.widget<MapLibreMap>(
      find.byType(MapLibreMap),
    );
    final CameraPosition position = map.initialCameraPosition!;
    expect(position.target.latitude, 41.9028);
    // **Nicht auf den Zahlenwert genau.** `LatLng` normalisiert den Längengrad
    // im Konstruktor mit `(lng + 180) % 360 - 180`
    // (`maplibre_gl_platform_interface 0.26.2`, `lib/src/location.dart:17-20`),
    // und das ist in Gleitkomma nicht verlustfrei: aus 12.4964 wird
    // 12.496399999999994. Der Fehler liegt bei rund 1e-14 Grad, also unter
    // einem Nanometer.
    //
    // **Und er sammelt sich nicht an, aber nicht aus dem Grund, der hier
    // vorher stand.** Der Rückweg ist keineswegs abwesend:
    // `mapCameraViewOf` liest bei **jeder** Kamerabewegung
    // `position.target.latitude/longitude` aus dem SDK, und daraus entstehen
    // `MapPosition`, die bekannte Kamera, das aufgefüllte Ziel und der Anker
    // der Strecken-Totzone. Der Rückweg ist der Normalfall, nicht die
    // Ausnahme. Nichts driftet, weil die Normalisierung nach **einer**
    // Anwendung idempotent ist: gemessen ergeben zwölf Durchläufe von
    // `LatLng(41.9028, v).longitude` genau einen Wert, `f(f(x)) == f(x)`.
    // Der Unterschied ist nicht akademisch: mit der falschen Begründung im
    // Kopf prüft niemand nach, wenn an `mapCameraViewOf` etwas dazukommt.
    expect(position.target.longitude, closeTo(12.4964, 1e-9));
    expect(position.zoom, 12.5);
    expect(position.bearing, 45);
    // `tilt` beim SDK, `pitch` in der Domäne. Die Umbenennung ist die eine
    // Stelle, an der eine Verwechslung lautlos wäre.
    expect(position.tilt, 21);
  });

  testWidgets('mountet die Karte mit den Optionen der Quelle', (tester) async {
    await pumpSurface(tester);
    await tester.pumpAndSettle();

    final MapLibreMap map = tester.widget<MapLibreMap>(
      find.byType(MapLibreMap),
    );
    // Der native Kompass bleibt aus: die App zeichnet ihren eigenen im
    // Top-Chrome (`screen-map.jsx:3145-3190`), der native läge darunter und
    // wäre ein zweiter Knopf für dieselbe Sache.
    expect(map.compassEnabled, isFalse);
    // `screen-map.jsx:1680`: `maxZoom: 20`. Auf die Felder geprüft und nicht
    // auf ein gleich geschriebenes `const`-Objekt: Dart kanonisiert
    // konstante Ausdrücke, ein Vergleich zweier Literale prüfte am Ende die
    // Gleichheit des Pakets statt den gesetzten Wert.
    expect(map.minMaxZoomPreference.maxZoom, 20);
    expect(map.minMaxZoomPreference.minZoom, isNull);
  });

  testWidgets('entsorgt beim Ausbauen den Host samt Kamerastrom', (
    tester,
  ) async {
    // **Ohne den Haken `debugCreateHost` wäre das nicht prüfbar.** Ein
    // fehlendes `_host.dispose()` hat kein sichtbares Verhalten: der
    // `StreamController` des Hosts bliebe einfach für immer offen, je
    // gemounteter Karte einer. Mit einem Host, den der Test selbst mitbringt,
    // wird daraus eine Zusicherung.
    final MapCameraHost host = MapCameraHost();
    bool closed = false;
    host.cameraChanges.listen(null, onDone: () => closed = true);

    await pumpSurface(
      tester,
      child: MapSurface(
        initialCamera: startCamera,
        debugCreateHost: () => host,
      ),
    );
    expect(closed, isFalse, reason: 'solange die Fläche hängt, lebt der Host');

    await pumpSurface(tester, child: const SizedBox.shrink());
    await tester.pump();

    expect(closed, isTrue);
  });

  testWidgets('klinkt seinen Host beim Mounten ein', (tester) async {
    await pumpSurface(tester);

    // Nachgewiesen am Verhalten und nicht an einem Zeiger: die Registry meldet
    // ohne Host `map.host.missing`. Kommt stattdessen die Meldung des Hosts
    // über die fehlende Karte, hat wirklich er die Absicht bekommen.
    container.read(mapHostProvider).submitIntent(skyFall());

    expect(sink.names, <String>[MapCameraHost.droppedEvent]);
  });

  testWidgets('klinkt ihn beim Entsorgen wieder aus', (tester) async {
    await pumpSurface(tester);
    await pumpSurface(tester, child: const SizedBox.shrink());

    container.read(mapHostProvider).submitIntent(skyFall());

    expect(sink.names, <String>[MapHostRegistry.missingHostEvent]);
  });

  test('übersetzt `tilt` des SDK zurück in `pitch` der Domäne', () {
    // **Der Rückweg, und er ist der, der zur Laufzeit dauernd läuft.**
    // `_onCameraMove` ruft ihn bei jeder Kamerabewegung, im Widget-Test aber
    // **nie**: ohne Plattformkanal entsteht kein Controller. Eine
    // Verwechslung von `bearing` und `pitch` wäre hier lautlos und fiele erst
    // am Gerät auf. Deshalb ist er eine reine Funktion mit
    // `@visibleForTesting` und keine private Zeile im `State`.
    final MapCameraView view = mapCameraViewOf(
      const CameraPosition(
        target: LatLng(41.9028, 12.4964),
        zoom: 12.5,
        bearing: 45,
        tilt: 21,
      ),
    );

    expect(view.pitch, 21);
    expect(view.bearing, 45);
    expect(view.zoom, 12.5);
    expect(view.center.latitude, 41.9028);
    expect(view.center.longitude, closeTo(12.4964, 1e-9));
  });

  testWidgets('eine zweite Fläche verdrängt die erste nicht rückwirkend', (
    tester,
  ) async {
    // Die Lehre aus Schritt 11 an ihrem echten Ort: beim Wechsel hängen
    // kurzzeitig beide im Baum. Das `dispose` der alten darf die frische
    // Anmeldung nicht wegräumen.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: FactTheme.light(),
          home: const Scaffold(
            body: Column(
              children: <Widget>[
                Expanded(child: MapSurface(initialCamera: startCamera)),
                Expanded(child: MapSurface(initialCamera: startCamera)),
              ],
            ),
          ),
        ),
      ),
    );
    await pumpSurface(tester);

    container.read(mapHostProvider).submitIntent(skyFall());

    // Die verbliebene Fläche hat den Host, nicht die Registry-Meldung.
    expect(sink.names, <String>[MapCameraHost.droppedEvent]);
  });
}
