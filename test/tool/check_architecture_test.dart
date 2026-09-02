// Black-Box-Test für tool/check_architecture.dart.
//
// Das Skript ist die einzige maschinelle Grenzkontrolle des Projekts, weil
// riverpod_lint mit diesem Abhängigkeitsstand nicht auflösbar ist. Wird der
// handgeschriebene Scanner falsch-negativ, verschwinden alle Architekturregeln
// lautlos. Deshalb prüft dieser Test das Skript so, wie CI es aufruft: als
// Prozess, über Exit-Code und Ausgabe. Kein Import aus dem Skript, keine
// Änderung am Skript.
//
// Warum der Prozessaufruf ohne Skriptänderung funktioniert: das Skript liest
// `Directory('lib')` relativ zum Arbeitsverzeichnis und meldet Pfade relativ
// dazu. Ein absoluter Skriptpfad plus `workingDirectory` auf dem Temp-Baum
// genügt also. `dart <absoluter Pfad>` braucht keine package_config im
// Arbeitsverzeichnis, weil das Skript nur `dart:io` importiert.
//
// Laufzeit: alle Bäume werden einmal in setUpAll erzeugt und die Prozesse
// parallel gestartet. Vier Prozessaufrufe für die gesamte Suite, danach werten
// die einzelnen Tests nur noch die gespeicherte Ausgabe aus.
//
// Proben liegen ausschließlich unter Directory.systemTemp und werden in
// tearDownAll gelöscht, auch wenn Tests fehlschlagen. Im Repository entsteht
// keine Probe.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Infrastruktur
// ---------------------------------------------------------------------------

/// Ein Fund, aus der Ausgabe des Skripts zurückgelesen.
class Fund {
  const Fund({
    required this.datei,
    required this.zeile,
    required this.gefunden,
    required this.regel,
    required this.istHinweis,
  });

  final String datei;
  final int zeile;
  final String gefunden;
  final String regel;
  final bool istHinweis;

  @override
  String toString() =>
      '$datei:$zeile ${istHinweis ? '(Hinweis) ' : ''}$gefunden -> $regel';
}

/// Ergebnis eines Skriptlaufs in einem Probebaum.
class Lauf {
  Lauf({
    required this.name,
    required this.exitCode,
    required this.ausgabe,
    required this.fehlerausgabe,
  }) : funde = leseFunde(ausgabe);

  /// Liest die Fundblöcke aus der Ausgabe.
  ///
  /// Format je Fund: `  datei:zeile`, dann `    gefunden: ...`, dann
  /// `    verletzt: ...`. Hinweise stehen hinter der Kopfzeile des
  /// Hinweisblocks.
  static List<Fund> leseFunde(String ausgabe) {
    final ergebnis = <Fund>[];
    final zeilen = const LineSplitter().convert(ausgabe);
    final kopf = RegExp(r'^ {2}([\w./-]+\.dart):(\d+)$');
    var imHinweisblock = false;

    for (var i = 0; i < zeilen.length; i++) {
      if (zeilen[i].contains('Hinweis bzw. Hinweise')) {
        imHinweisblock = true;
        continue;
      }
      final treffer = kopf.firstMatch(zeilen[i]);
      if (treffer == null) {
        continue;
      }
      final gefunden = i + 1 < zeilen.length ? zeilen[i + 1].trim() : '';
      final regel = i + 2 < zeilen.length ? zeilen[i + 2].trim() : '';
      ergebnis.add(
        Fund(
          datei: treffer.group(1)!,
          zeile: int.parse(treffer.group(2)!),
          gefunden: gefunden.startsWith('gefunden: ')
              ? gefunden.substring('gefunden: '.length)
              : '',
          regel: regel.startsWith('verletzt: ')
              ? regel.substring('verletzt: '.length)
              : '',
          istHinweis: imHinweisblock,
        ),
      );
    }
    return ergebnis;
  }

  final String name;
  final int exitCode;
  final String ausgabe;
  final String fehlerausgabe;
  final List<Fund> funde;

  List<Fund> get verstoesse => funde.where((f) => !f.istHinweis).toList();

  List<Fund> get hinweise => funde.where((f) => f.istHinweis).toList();

  List<Fund> fuer(String datei) =>
      funde.where((f) => f.datei == datei).toList();

  Set<String> get dateienMitFund => funde.map((f) => f.datei).toSet();

  String get bericht =>
      'Baum "$name", Exit-Code $exitCode\n--- stdout ---\n$ausgabe'
      '--- stderr ---\n$fehlerausgabe';
}

/// Pfad des zu prüfenden Skripts.
///
/// `FACT_ARCH_SCRIPT` gibt es nur für die Mutationsprobe: damit lässt sich die
/// Suite gegen eine absichtlich blinde Kopie des Skripts laufen lassen, ohne
/// das Original anzufassen. Ohne die Variable prüft die Suite das Skript im
/// Repository.
String _skriptPfad() {
  final abweichung = Platform.environment['FACT_ARCH_SCRIPT'];
  if (abweichung != null && abweichung.isNotEmpty) {
    return abweichung;
  }
  return '${Directory.current.path}/tool/check_architecture.dart';
}

/// Findet die Dart-Kommandozeile. Unter `flutter test` ist
/// `Platform.resolvedExecutable` der flutter_tester, nicht Dart.
String _dartPfad() {
  final wurzel = Platform.environment['FLUTTER_ROOT'];
  if (wurzel != null && wurzel.isNotEmpty) {
    final endung = Platform.isWindows ? '.exe' : '';
    final kandidat = File('$wurzel/bin/cache/dart-sdk/bin/dart$endung');
    if (kandidat.existsSync()) {
      return kandidat.path;
    }
  }
  if (Platform.resolvedExecutable.contains('dart-sdk')) {
    return Platform.resolvedExecutable;
  }
  return Platform.isWindows ? 'dart.exe' : 'dart';
}

/// Schreibt einen Probebaum unterhalb von [wurzel].
Directory _baueBaum(
  Directory wurzel,
  String name,
  Map<String, String> dateien,
) {
  final baum = Directory('${wurzel.path}/$name')..createSync(recursive: true);
  for (final eintrag in dateien.entries) {
    final datei = File('${baum.path}/${eintrag.key}');
    datei.parent.createSync(recursive: true);
    datei.writeAsStringSync(eintrag.value);
  }
  return baum;
}

Future<Lauf> _starte(String name, Directory baum) async {
  final ergebnis = await Process.run(
    _dartPfad(),
    <String>[_skriptPfad()],
    workingDirectory: baum.path,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return Lauf(
    name: name,
    exitCode: ergebnis.exitCode,
    ausgabe: ergebnis.stdout as String,
    fehlerausgabe: ergebnis.stderr as String,
  );
}

/// Setzt eine Probe auf CRLF um, ohne vorhandene CRLF zu verdoppeln.
String _crlf(String inhalt) =>
    inhalt.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');

// ---------------------------------------------------------------------------
// Proben
// ---------------------------------------------------------------------------

/// Baum 1: alles, was gemeldet werden muss. Jeder Fall bekommt eine eigene
/// Datei, damit kein Fall einen anderen verdecken kann.
Map<String, String> _verstossProben() => <String, String>{
  // Alle Technikverbote der Domäne in einer Datei, eine Zeile je Verbot.
  'lib/features/tours/domain/entities/technik_importe.dart': r'''
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class Tour {}
''',
  'lib/features/tours/domain/usecases/core_import.dart': r'''
import 'package:fact_app/core/types/result.dart';

class TourLaden {}
''',
  'lib/features/tours/domain/usecases/schicht_importe.dart': r'''
import '../../data/tour_dto.dart';
import '../../presentation/pages/tour_page.dart';

class TourVerbiegen {}
''',
  'lib/features/tours/presentation/pages/supabase_seite.dart': r'''
import 'package:supabase_flutter/supabase_flutter.dart';

class TourSeite {}
''',
  'lib/features/tours/presentation/pages/fremdes_feature_paket.dart': r'''
import 'package:fact_app/features/challenges/presentation/challenge_page.dart';
import 'package:fact_app/features/challenges/data/challenge_dto.dart';

class FremdSeite {}
''',
  'lib/features/tours/presentation/pages/fremdes_feature_relativ.dart': r'''
import '../../../challenges/presentation/challenge_page.dart';
import '../../../challenges/data/challenge_dto.dart';

class FremdSeiteRelativ {}
''',
  'lib/app/di.dart': r'''
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

class Container {}
''',
  // Gate 7 gilt projektweit, also auch in test/ und tool/.
  'test/di_test.dart': r'''
import 'package:get_it/get_it.dart';

void main() {}
''',
  'tool/generieren.dart': r'''
import 'package:injectable/injectable.dart';

void main() {}
''',
  // Scanner: Schlüsselwort und URI in verschiedenen Zeilen.
  'lib/features/tours/domain/entities/mehrzeilige_direktive.dart': r'''
import
    'package:flutter/material.dart';

class Mehrzeilig {}
''',
  // Scanner: bedingte Direktive, Verstoß im zweiten URI.
  'lib/features/tours/domain/entities/bedingte_direktive.dart': r'''
import 'stub.dart'
    if (dart.library.io) 'package:flutter/material.dart';

class Bedingt {}
''',
  // Scanner: zwei verletzende URIs in einer Direktive geben zwei Meldungen.
  'lib/features/tours/domain/entities/zwei_uris.dart': r'''
import 'package:go_router/go_router.dart' if (dart.library.io) 'package:riverpod/riverpod.dart';

class ZweiUris {}
''',
  // Scanner: auskommentierte Verbote werden ignoriert, der echte Verstoß
  // dahinter wird trotzdem gemeldet und die Zeile verschiebt sich nicht.
  'lib/features/tours/domain/entities/kommentierter_import.dart': r'''
// import 'package:flutter/material.dart';
/* import 'package:riverpod/riverpod.dart'; */
import 'package:go_router/go_router.dart';

class Kommentiert {}
''',
  // Scanner: Direktiven in einem dreifach gequoteten Literal sind Text, der
  // echte Verstoß in Zeile 1 bleibt sichtbar.
  'lib/features/tours/domain/entities/vorlage_im_literal.dart': r'''
import 'package:go_router/go_router.dart';

const vorlage = """
import 'package:flutter/material.dart';
export 'package:supabase_flutter/supabase_flutter.dart';
""";
''',
  // Scanner: CRLF darf Zeilennummern nicht verschieben, weder beim URI einer
  // Direktive (Zeile 4) noch bei einem Treffer im Code (Zeile 7).
  'lib/features/tours/domain/entities/crlf.dart': _crlf(r'''
// Datei mit CRLF-Zeilenenden.
import 'dart:async';

import 'package:flutter/material.dart';

void protokolliere() {
  print('crlf');
}
'''),
  // Scanner: rohe, dreifach gequotete und interpolierte Literale erzeugen
  // keine Falschmeldung und verschieben die Position des echten Verstoßes in
  // Zeile 12 nicht.
  'lib/features/tours/presentation/widgets/literale.dart': r"""
class Literale {
  static const roh = r"context.go('/roh')";
  static const drei = '''
context.go('/drei')
''';
  static const gemischt = 'Pfad: ${Literale.roh.length} von ${1 + 2}';

  // Ein Kommentar mit Apostroph: der Nutzer's Pfad.
  static const escaped = 'context.go(\'/maskiert\')';

  void tippen(dynamic context) {
    context.go('/echt');
  }
}
""",
  // Regel 11: Geschäftsbegriff im Pfad unter core.
  'lib/core/facts/helper.dart': r'''
class FactHelper {}
''',
  // Gate 8: rohe Navigator-API außerhalb von lib/app/routing/.
  'lib/features/tours/presentation/pages/navigator_api.dart': r'''
class NavigatorSeite {
  void oeffne(dynamic context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => this));
  }
}
''',
  // Gate 8: Route-Literal wird gemeldet, die Variante mit Variable nicht.
  'lib/features/tours/presentation/pages/route_string.dart': r'''
class RouteSeite {
  void mitLiteral(dynamic context) {
    context.go('/tours');
  }

  void mitVariable(dynamic context, String ziel) {
    context.go(ziel);
  }
}
''',
  // Gate 9: print, debugPrint und die Tear-off-Form. printWidth und sprintf
  // sind keine Verstöße.
  'lib/features/tours/presentation/widgets/ausgabe.dart': r'''
class Ausgabe {
  void direkt() {
    print('x');
    debugPrint('y');
  }

  void indirekt() {
    final f = print;
    const printWidth = 3;
    final text = sprintf('%d', [printWidth]);
    f(text);
  }
}
''',
  // Regel 7: Instanziierung in presentation. Feld, abstrakte Deklaration,
  // Provider-Bezug und benannter Konstruktor stehen bewusst daneben.
  'lib/features/tours/presentation/widgets/instanziierung.dart': r'''
abstract class TourRepository {}

class TourAnsicht {
  TourAnsicht(this.repository);

  final TourRepository repository;

  void baue(dynamic ref) {
    final direkt = TourRepository();
    final quelle = TourRemoteDataSource();
    final client = SupabaseClient('url', 'key');
    final ueberProvider = ref.watch(tourRepositoryProvider);
    final benannt = TourRepository.remote();
  }
}
''',
  // Regel 12: der Notifier navigiert, das Widget in derselben Datei darf es.
  'lib/features/tours/presentation/notifier_und_widget.dart': r'''
class TourNotifier extends AsyncNotifier<int> {
  void zurueck() {
    router.pop();
  }
}

class TourWidget {
  void zurueck() {
    router.pop();
  }
}
''',
  // Regel 13: verbotene Rückgabetypen im Repository-Vertrag, daneben ein
  // erlaubter.
  'lib/features/tours/domain/repositories/tour_repository.dart': r'''
abstract class TourRepository {
  Future<Map<String, dynamic>> roh();
  AsyncValue<int> zustand();
  Future<TourDto> eins();
  Future<List<Tour>> alle();
}
''',
  // Ä1: eine Schicht unterhalb einer Unterstruktur des Features wird wie eine
  // Schicht behandelt. Vorher passte dieser Pfad auf kein Schichtmuster, damit
  // fiel jedes Domänenverbot aus.
  'lib/features/tours/karte/domain/entities/verschachtelte_domaene.dart': r'''
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerschachtelteDomaene {}
''',
  // Ä2: die Erlaubnisliste fängt genau die Pakete, die eine Verbotsliste nicht
  // namentlich kennt.
  'lib/features/tours/domain/entities/domain_weitere_sdk.dart': r'''
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart';
import 'package:hive/hive.dart';

class DomainWeitereSdk {}
''',
  // Ä2: dieselbe Erlaubnisliste schließt app/ und services/ aus, obwohl beide
  // zum eigenen Paket gehören.
  'lib/features/tours/domain/entities/domain_app_services.dart': r'''
import 'package:fact_app/app/routing/routes.dart';
import 'package:fact_app/services/supabase/supabase_client_provider.dart';

class DomainAppServices {}
''',
  // Ä3: Regel 7 greift auch in application, weil ein Notifier je nach
  // Reifegrad dort liegt.
  'lib/features/tours/application/application_instanziierung.dart': r'''
class TourSteuerung {
  void baue() {
    final direkt = TourRepository();
    final client = SupabaseClient('url', 'key');
  }
}
''',
  // Ä4: presentation darf nicht auf das eigene data zeigen, weder über den
  // Paketpfad noch relativ.
  'lib/features/tours/presentation/pages/eigenes_data.dart': r'''
import 'package:fact_app/features/tours/data/tour_dto.dart';
import '../../data/tour_remote_data_source.dart';

class EigenesData {}
''',
  // Ä5: integration_test/ wird eingelesen, Gate 7 gilt auch dort.
  'integration_test/getit_test.dart': r'''
import 'package:get_it/get_it.dart';

void main() {}
''',
  // Ä6: presentation außerhalb von lib/features/<feature>/ ist dieselbe
  // Schicht mit derselben Regel.
  'lib/shared/presentation/geteilte_seite.dart': r'''
import 'package:supabase_flutter/supabase_flutter.dart';

class GeteilteSeite {}
''',
  // Ä7: domain, application und data gelten überall unterhalb von lib/, nicht
  // nur unter lib/features/. Vorher passierte genau diese Datei das Gate.
  'lib/map/domain/karten_technik.dart': r'''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class KartenTechnik {}
''',
  // Ä7: die Erlaubnisliste greift im Modul genauso. Ein fremdes Paket und
  // eine fremde Feature-Domäne fallen beide durch.
  'lib/map/domain/fremde_importe.dart': r'''
import 'package:http/http.dart';
import 'package:fact_app/features/tours/domain/entities/tour.dart';

class FremdeImporte {}
''',
  // Ä8: Regel 8 und 9 hängen nicht mehr am eigenen Feature. Derselbe Import
  // war unter lib/features/ ein Verstoß und hier stillschweigend erlaubt.
  'lib/map/presentation/karten_host.dart': r'''
import 'package:fact_app/features/tours/presentation/pages/tour_page.dart';
import 'package:fact_app/features/challenges/data/challenge_dto.dart';

class KartenHost {}
''',
  // Ä8: dasselbe außerhalb von lib/map/, damit die Regel nicht als
  // Sonderfall des Karten-Hosts gelesen wird.
  'lib/services/karten_adapter.dart': r'''
import 'package:fact_app/features/tours/presentation/pages/tour_page.dart';

class KartenAdapter {}
''',
  // Ä9: Features sehen vom Karten-Host nur map/domain/.
  'lib/features/discovery/presentation/karten_zugriff.dart': r'''
import 'package:fact_app/map/presentation/map_host.dart';
import 'package:fact_app/map/data/tile_cache.dart';

class KartenZugriff {}
''',
  // Ä11: das Karten-SDK gehört dem Host. Regel 18 hält Features aus
  // map/presentation/ heraus, Regel 20 verbietet den direkten Griff zum
  // Paket. Ohne sie dürfte ein Feature die Karte nicht über den Host steuern,
  // wohl aber an ihm vorbei.
  'lib/features/discovery/presentation/karten_sdk_versuch.dart': r'''
import 'package:maplibre_gl/maplibre_gl.dart';

class KartenSdkVersuch {}
''',
  // Ä12: das Geo-SDK gehört dem Ortungsdienst. Regel 4 verbietet es nur in
  // einer Domäne, jedes andere Verzeichnis unterhalb von lib/ durfte es vor
  // Regel 21 holen. Gemessen am 29.08.2026, nicht vermutet.
  'lib/features/discovery/presentation/ortung_versuch.dart': r'''
import 'package:geolocator/geolocator.dart';

class OrtungVersuch {}
''',
  // Ä12: auch der Karten-Host bekommt das Geo-SDK nicht. Die Nutzerposition
  // gehört dem Ortungsdienst, nicht der Karte.
  'lib/map/presentation/ortung_daneben.dart': r'''
import 'package:geolocator/geolocator.dart';

class OrtungDaneben {}
''',
  // Ä12: das Verbot trifft die ganze Paketfamilie, nicht nur `geolocator`
  // selbst. `Position` und `LocationAccuracy` stammen aus
  // `geolocator_platform_interface`, das ist also der naheliegendste Umweg.
  // Bewusste Abweichung von Regel 20, die `^package:maplibre_gl` vollständig
  // nennt; die Begründung steht bei _geoSdkBans im Skript.
  'lib/features/discovery/presentation/ortung_familie.dart': r'''
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

class OrtungFamilie {}
''',
  // Ä13: der Gerätespeicher gehört dem Präferenz-Adapter. Wie bei Regel 21
  // verbietet Regel 4 ihn nur in einer Domäne; jedes andere Verzeichnis
  // unterhalb von lib/ durfte ihn vor Regel 22 holen, und die Lücke stand im
  // Skript ausdrücklich als bewusst offen gelassen.
  'lib/features/settings/data/praeferenz_versuch.dart': r'''
import 'package:shared_preferences/shared_preferences.dart';

class PraeferenzVersuch {}
''',
  // Ä13: auch die App-Komposition bekommt ihn nicht, obwohl sie den Speicher
  // lädt. Sie holt ihn über `loadKeyValueStore` und sieht das Paket nie.
  'lib/app/praeferenz_daneben.dart': r'''
import 'package:shared_preferences/shared_preferences.dart';

class PraeferenzDaneben {}
''',
  // Ä13: das Verbot trifft die ganze Paketfamilie. `shared_preferences_platform_interface`
  // ist der naheliegendste Umweg, dort liegt `SharedPreferencesStorePlatform`.
  'lib/features/settings/data/praeferenz_familie.dart': r'''
import 'package:shared_preferences_android/shared_preferences_android.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class PraeferenzFamilie {}
''',
  // Ä14: der Kern darf keine Feature-Domäne importieren. Regel 23 dreht die
  // Aufnahmerichtung um: eine Domäne darf den Kern sehen (D-18), der Kern darf
  // niemals zurückblicken. Sonst wäre der Kern kein geteilter Ort mehr,
  // sondern eine versteckte Abhängigkeit auf `facts`.
  'lib/kernel/greift_auf_feature.dart': r'''
import 'package:fact_app/features/facts/domain/entities/fact.dart';

class GreiftAufFeature {}
''',
  // Ä14: auch `core` ist dem Kern verwehrt. `core` liegt selbst schon tiefer
  // als jedes Feature, aber der Kern liegt laut ADR-008 noch darunter, und
  // die Erlaubnisliste in [_isAllowedKernelImport] nennt `core` bewusst nicht.
  'lib/kernel/greift_auf_core.dart': r'''
import 'package:fact_app/core/types/result.dart';

class GreiftAufCore {}
''',
  // Ä14: Flutter selbst ist verboten. Regel 2 aus ADR-008 verlangt reines
  // Dart, damit jede Domäne den Kern ohne Widget-Abhängigkeit importieren
  // kann; ein einziger Flutter-Import hier würde das für alle drei zugleich
  // aufheben.
  'lib/kernel/holt_flutter.dart': r'''
import 'package:flutter/material.dart';

class HoltFlutter {}
''',
  // Ä10: webview_flutter ist auf lib/map/presentation/avatar/ beschränkt.
  'lib/features/discovery/presentation/avatar_versuch.dart': r'''
import 'package:webview_flutter/webview_flutter.dart';

class AvatarVersuch {}
''',
  // Ä10: auch lib/map/presentation/ selbst reicht nicht. Nur der
  // Avatar-Ordner darf.
  'lib/map/presentation/webview_daneben.dart': r'''
import 'package:webview_flutter/webview_flutter.dart';

class WebviewDaneben {}
''',
  // Ä10: dasselbe in einer Domäne. Hier muss genau **eine** Meldung stehen,
  // und zwar die der Domäne. Regel 19 verweist auf
  // lib/map/presentation/avatar/, und dorthin darf eine Domäne nie zeigen; die
  // Meldung wäre dort also nicht nur doppelt, sondern irreführend.
  'lib/features/discovery/domain/avatar_vertrag.dart': r'''
import 'package:webview_flutter/webview_flutter.dart';

class AvatarVertrag {}
''',
  // Ä8: core importiert eine Feature-Presentation. Regel 11 verbietet das
  // schon, deshalb muss hier genau eine Meldung stehen und nicht zwei.
  'lib/core/greift_auf_feature.dart': r'''
import 'package:fact_app/features/tours/presentation/pages/tour_page.dart';

class GreiftAufFeature {}
''',
  // Ä15: der Kompass-Sensor gehört dem Orientierungsdienst. Wie bei Regel 21
  // und 22 verbietet Regel 4 ihn nur in einer Domäne; jedes andere Verzeichnis
  // unterhalb von lib/ durfte ihn vor Regel 24 holen.
  'lib/features/discovery/presentation/orientierung_versuch.dart': r'''
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart';

class OrientierungVersuch {}
''',
  // Ä15: auch die App-Komposition bekommt ihn nicht, obwohl sie den Dienst
  // per Override einsetzt. Sie holt ihn über den Provider und sieht das Paket
  // nie.
  'lib/app/orientierung_daneben.dart': r'''
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart';

class OrientierungDaneben {}
''',
  // Ä15: das Verbot trifft beide Pakete der Familie. Anders als bei Regel 21
  // und 22 teilen sie sich kein gemeinsames Namenspräfix, siehe die
  // Begründung bei _orientationSdkBans im Skript: `native_device_orientation`
  // ist die transitive Abhängigkeit, in der eine eigene Gerätestellungs-API
  // liegt, und damit der naheliegendste Umweg.
  'lib/features/discovery/presentation/orientierung_familie.dart': r'''
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class OrientierungFamilie {}
''',
  // Ä16: die Sprachausgabe gehört dem Sprachdienst. Wie bei den Regeln 21,
  // 22 und 24 verbietet Regel 4 sie nur in einer Domäne; jedes andere
  // Verzeichnis unterhalb von lib/ durfte sie vor Regel 25 holen.
  'lib/features/facts/presentation/sprach_versuch.dart': r'''
import 'package:flutter_tts/flutter_tts.dart';

class SprachVersuch {}
''',
  // Ä16: auch die App-Komposition bekommt sie nicht, obwohl sie den Dienst
  // per Override einsetzt. Sie holt ihn über den Provider und sieht das Paket
  // nie. Genau diese Zeile wäre der bequeme Weg gewesen.
  'lib/app/sprache_daneben.dart': r'''
import 'package:flutter_tts/flutter_tts.dart';

class SpracheDaneben {}
''',
  // Ä17: die Tonwiedergabe gehört dem Ton-Dienst. Wie bei den Regeln 21,
  // 22, 24 und 25 verbietet Regel 4 sie nur in einer Domäne; jedes andere
  // Verzeichnis unterhalb von lib/ durfte sie vor Regel 26 holen.
  'lib/features/discovery/presentation/ton_versuch.dart': r'''
import 'package:audioplayers/audioplayers.dart';

class TonVersuch {}
''',
  // Ä17: und in einer Domäne greift Regel 4 mit einem eigenen Eintrag.
  // Anders als flutter_tts trägt audioplayers kein `flutter_`-Präfix, fiele
  // dort also sonst nur unter die allgemeine Erlaubnisliste.
  'lib/features/tours/domain/entities/ton_in_domaene.dart': r'''
import 'package:audioplayers/audioplayers.dart';

class TonInDomaene {}
''',
  // Lücke 1 geschlossen: die Cross-Feature-Prüfung griff nur die Schicht
  // direkt unter dem fremden Feature. Ein fremdes presentation und ein
  // fremdes data hinter einer Unterstruktur entkamen den Regeln 8 und 9,
  // während dieselbe Verschachtelung für die eigenen Schichten längst
  // geschlossen war (Ä1).
  'lib/features/tours/presentation/pages/fremdes_feature_verschachtelt.dart':
      r'''
import 'package:fact_app/features/challenges/unterstruktur/presentation/challenge_page.dart';
import 'package:fact_app/features/challenges/unterstruktur/data/challenge_dto.dart';

class FremdSeiteVerschachtelt {}
''',
  // Lücke 2 geschlossen: Regel 17 hing an lib/features/ und _pointsIn-
  // toOwnFeatureLayer. Ein Modul außerhalb davon, hier der Karten-Host,
  // durfte sein eigenes data/ ungestraft lesen. Derselbe Fall, der bis eben
  // unter "Offene Lücken" als gemessen und offen festgehalten war.
  'lib/map/presentation/luecke_eigenes_data.dart': r'''
import 'package:fact_app/map/data/tile_cache.dart';

class LueckeEigenesData {}
''',
  // Lücke 2, Doppelmeldungs-Probe: derselbe Karten-Host, diesmal mit einem
  // fremden Feature-data/ statt dem eigenen. Hier muss weiterhin nur Regel 9
  // greifen, nicht zusätzlich die neue Regel-17-Prüfung, denn die
  // Modulwurzel des Karten-Hosts (package:fact_app/map/) passt nicht auf
  // einen Import unter package:fact_app/features/.
  'lib/map/presentation/fremdes_feature_data_regel17.dart': r'''
import 'package:fact_app/features/tours/data/tour_dto.dart';

class FremdesFeatureDataRegel17 {}
''',
};

/// Baum 2: alles, was still bleiben muss. Enthält die Gegenproben und die
/// bekannten Lücken. Dieser Baum muss Exit-Code 0 ohne jeden Fund ergeben.
Map<String, String> _stilleProben() => <String, String>{
  // Ä13 Gegenprobe: im Präferenz-Adapter ist der Gerätespeicher erlaubt. Sonst
  // hätte Regel 22 kein Ziel, sondern wäre ein Verbot ohne Ort.
  'lib/services/preferences/praeferenz_adapter.dart': r'''
import 'package:shared_preferences/shared_preferences.dart';

class PraeferenzAdapter {}
''',
  // Ä15 Gegenprobe: im Orientierungsdienst ist der Kompass-Sensor erlaubt.
  // Sonst hätte Regel 24 kein Ziel, sondern wäre ein Verbot ohne Ort.
  'lib/services/orientation/orientierungs_adapter.dart': r'''
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart';

class OrientierungsAdapter {}
''',
  // Ä16 Gegenprobe: im Sprachdienst ist flutter_tts erlaubt. Sonst hätte
  // Regel 25 kein Ziel, sondern wäre ein Verbot ohne Ort.
  'lib/services/speech/sprach_adapter.dart': r'''
import 'package:flutter_tts/flutter_tts.dart';

class SprachAdapter {}
''',
  // Ä17 Gegenprobe: im Ton-Dienst ist audioplayers erlaubt. Sonst hätte
  // Regel 26 kein Ziel, sondern wäre ein Verbot ohne Ort.
  'lib/services/audio/ton_adapter.dart': r'''
import 'package:audioplayers/audioplayers.dart';

class TonAdapter {}
''',
  // Ä14 Gegenprobe: eine Feature-Domäne darf den Kern importieren. Das ist die
  // Gegenprobe, um die es Dairen mit D-18 ging: ohne sie ist Regel 23 nur eine
  // Behauptung, dass eine Richtung erlaubt bleibt, ohne dass ein Test es prüft.
  'lib/features/tours/domain/entities/nutzt_kern.dart': r'''
import 'package:fact_app/kernel/puzzle_difficulty.dart';

class NutztKern {}
''',
  // Ä14 Gegenprobe: der Kern darf das Dart-SDK und sich selbst importieren.
  // Ohne sie könnte [_isAllowedKernelImport] versehentlich auf eine leere
  // Erlaubnisliste schrumpfen, und der Kern könnte sich nicht mehr selbst
  // zusammensetzen.
  'lib/kernel/nutzt_dart_und_sich_selbst.dart': r'''
import 'dart:convert';

import 'package:fact_app/kernel/puzzle_operand.dart';

class NutztDartUndSichSelbst {}
''',
  // Gegenprobe zu Regel 8 und 9: Import innerhalb des eigenen Features,
  // absolut und relativ.
  'lib/features/tours/presentation/pages/eigenes_feature.dart': r'''
import 'package:fact_app/features/tours/presentation/widgets/tour_karte.dart';
import 'package:fact_app/features/tours/application/tour_steuerung.dart';
import 'package:fact_app/features/tours/domain/entities/tour.dart';
import 'package:fact_app/core/types/result.dart';
import '../widgets/tour_karte.dart';

class Eigen {}
''',
  // Gegenprobe zu Ä1 und Ä2: eine korrekte verschachtelte Domäne. Nur das
  // Dart-SDK und die eigene Feature-Domäne, absolut und relativ geschrieben.
  // Diese Datei muss still bleiben, sonst ist die Verschärfung zu breit.
  'lib/features/tours/karte/domain/entities/saubere_verschachtelung.dart': r'''
import 'dart:math';

import 'package:fact_app/features/tours/karte/domain/entities/punkt.dart';
import '../value_objects/zoomstufe.dart';

class SaubereVerschachtelung {}
''',
  // Gegenprobe zu Ä3: application bezieht die Abhängigkeit über einen
  // Provider und deklariert sie als Feld. Beides ist keine Instanziierung.
  'lib/features/tours/application/saubere_steuerung.dart': r'''
class TourSteuerung {
  TourSteuerung(this.repository);

  final TourRepository repository;

  void laden(dynamic ref) {
    final ueberProvider = ref.watch(tourRepositoryProvider);
  }
}
''',
  // Gegenprobe zu Ä5: eine Datei in integration_test/ ohne zweites DI-System.
  'integration_test/saubere_integration_test.dart': r'''
import 'package:flutter_test/flutter_test.dart';

void main() {}
''',
  // Gegenprobe zu Ä6: dasselbe presentation außerhalb von features, diesmal
  // mit erlaubten Importen.
  'lib/shared/presentation/saubere_seite.dart': r'''
import 'package:flutter/material.dart';
import 'package:fact_app/core/types/result.dart';

class SaubereSeite {}
''',
  // Gegenprobe zu Ä1: ein Verzeichnis, dessen Name nur mit einem Schichtnamen
  // beginnt, ist keine Schicht. Der Core-Import wäre in der Domäne ein Verstoß
  // gegen Gate 6, in presentation ist er erlaubt. Bliebe er hier unbemerkt
  // still, hätte das Muster "domain_helpers" als Domäne gelesen.
  'lib/features/tours/presentation/domain_helpers/kein_domain.dart': r'''
import 'package:fact_app/core/types/result.dart';

class KeinDomain {}
''',
  // Gegenprobe zu Regel 11: technischer Begriff unter core.
  'lib/core/types/result.dart': r'''
class Result<T> {}
''',
  // Gegenprobe zu Gate 8: dieselbe Navigator-Nutzung in der
  // Routing-Infrastruktur bleibt still.
  'lib/app/routing/navigator_api.dart': r'''
class RoutingSchale {
  void oeffne(dynamic context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => this));
    context.go('/tours');
  }
}
''',
  // Gegenprobe zu Regel 13.
  'lib/features/tours/domain/repositories/sauberer_vertrag.dart': r'''
abstract class SaubererRepository {
  Future<List<Tour>> alle();
  Stream<Tour> beobachte();
}
''',
  // Bekannte Lücke 1: benannte Konstruktoren umgehen Regel 7. Bewusst so, ein
  // breiteres Muster würde statische Factory-Helfer melden.
  'lib/features/tours/presentation/widgets/luecke_benannt.dart': r'''
class TourAnsicht {
  void baue() {
    final repository = TourRepository.remote();
    final quelle = TourRemoteDataSource.fromEnv();
  }
}
''',
  // Bekannte Lücke 2: eine Direktive, die nicht am Zeilenanfang beginnt, wird
  // nicht erkannt. Hier bleibt der Flutter-Import in der Domäne unsichtbar.
  // Der erste Export zeigt in die eigene Domäne und ist erlaubt.
  'lib/features/tours/domain/entities/luecke_zeilenanfang.dart': r'''
export 'stub.dart'; import 'package:flutter/material.dart';

class LueckeZeilenanfang {}
''',
  // Bekannte Lücke 3: Navigation mit einer Variable statt einem Literal wird
  // nicht gemeldet. Genau so sieht eine typisierte Route aus.
  'lib/features/tours/presentation/pages/luecke_route_variable.dart': r'''
class RouteVariable {
  void oeffne(dynamic context, String ziel) {
    context.go(ziel);
  }
}
''',
  // Bekannte Lücke 4: ein fremdes domain/ ist kein Verstoß im Skript, Regel 10
  // verlangt aber einen öffentlichen Vertrag.
  'lib/features/tours/application/luecke_fremde_domain.dart': r'''
import 'package:fact_app/features/challenges/domain/entities/challenge.dart';

class LueckeFremdeDomain {}
''',
  // Ä7 Gegenprobe: die Domäne eines Moduls außerhalb von features/ darf sich
  // selbst importieren, absolut und relativ. Ohne die Modulwurzel meldet die
  // Erlaubnisliste hier zwei Verstöße, und die Verallgemeinerung der
  // Schichtmuster wäre unbenutzbar.
  'lib/map/domain/saubere_absicht.dart': r'''
import 'dart:math';

import 'package:fact_app/map/domain/kamera_absicht.dart';
import 'value_objects/zoomstufe.dart';

class SaubereAbsicht {}
''',
  // Ä8 Gegenprobe: die App-Komposition darf alles, was die Tabelle in
  // dependency-rules.md ihr zugesteht. Fällt diese Ausnahme, ist der Router
  // rot.
  'lib/app/komposition.dart': r'''
import 'package:fact_app/features/tours/presentation/pages/tour_page.dart';
import 'package:fact_app/features/challenges/data/challenge_dto.dart';
import 'package:fact_app/map/presentation/map_host.dart';

class Komposition {}
''',
  // Ä9 Gegenprobe: map/domain/ ist genau das, was ein Feature sehen darf.
  'lib/features/discovery/presentation/karten_absicht.dart': r'''
import 'package:fact_app/map/domain/kamera_absicht.dart';

class KartenAbsicht {}
''',
  // Ä11 Gegenprobe: im Karten-Host ist das SDK erlaubt. Sonst hätte die Karte
  // keinen Ort und die Regel wäre ein Verbot statt einer Zuordnung.
  'lib/map/presentation/map_host_sdk.dart': r'''
import 'package:maplibre_gl/maplibre_gl.dart';

class MapHostSdk {}
''',
  // Ä12 Gegenprobe: im Ortungsdienst ist das Geo-SDK erlaubt. Sonst wäre die
  // Regel ein Verbot statt einer Zuordnung, und die App hätte keine Ortung
  // mehr.
  'lib/services/location/ortungsdienst.dart': r'''
import 'package:geolocator/geolocator.dart';

class Ortungsdienst {}
''',
  // Ä10 Gegenprobe: im Avatar-Ordner ist die WebView erlaubt, sonst wäre die
  // Regel ein Verbot statt einer Kapselung.
  'lib/map/presentation/avatar/avatar_view.dart': r'''
import 'package:webview_flutter/webview_flutter.dart';

class AvatarView {}
''',
  // Lücke 1 Gegenprobe: ein Import in die eigene verschachtelte Schicht
  // (features/tours/unterstruktur/data/ aus features/tours/) bleibt still,
  // denn cross.group(1) == ownFeature. Bewusst außerhalb jeder Schicht
  // (kein domain/, application/, presentation/ oder data/ im eigenen Pfad),
  // damit keine andere Prüfung hineinspielt und nur die Cross-Feature-Prüfung
  // selbst auf dem Prüfstand steht.
  'lib/features/tours/orchestrierung/eigene_verschachtelung.dart': r'''
import 'package:fact_app/features/tours/unterstruktur/data/tour_dto.dart';

class EigeneVerschachtelung {}
''',
  // Lücke 2 Gegenprobe: im Karten-Host ist application erlaubt, nur data
  // nicht. Sonst wäre die neue Prüfung ein Verbot der ganzen Modulwurzel und
  // nicht nur der data-Schicht.
  'lib/map/presentation/erlaubte_application.dart': r'''
import 'package:fact_app/map/application/kamera_steuerung.dart';

class ErlaubteApplication {}
''',
  // Lücke 2, zweite Falle: eine Schicht direkt unter lib/ liefert bei
  // _modulwurzel bewusst null. Diese Datei prüft, dass der zweite Zweig der
  // Regel-17-Prüfung dann ausbleibt, ohne Ausnahme und ohne Absturz.
  'lib/presentation/schicht_direkt_unter_lib.dart': r'''
import 'package:fact_app/map/data/tile_cache.dart';

class SchichtDirektUnterLib {}
''',
};

/// Baum 3: nur ein Hinweis, kein Verstoß. Prüft die Exit-Code-Semantik.
Map<String, String> _hinweisProben() => <String, String>{
  'lib/features/tours/application/protokoll.dart': r'''
import 'dart:async';
import 'dart:developer';

class Protokoll {}
''',
};

// ---------------------------------------------------------------------------
// Ablauf
// ---------------------------------------------------------------------------

void main() {
  late Directory tempWurzel;
  late Lauf verstoss;
  late Lauf still;
  late Lauf hinweis;
  late Lauf ohneLib;

  setUpAll(() async {
    tempWurzel = Directory.systemTemp.createTempSync('fact_arch_check_');
    final baumVerstoss = _baueBaum(tempWurzel, 'verstoesse', _verstossProben());
    final baumStill = _baueBaum(tempWurzel, 'still', _stilleProben());
    final baumHinweis = _baueBaum(tempWurzel, 'hinweis', _hinweisProben());
    final baumOhneLib = _baueBaum(tempWurzel, 'ohne_lib', <String, String>{
      'tool/leer.dart': 'void main() {}\n',
    });

    final laeufe = await Future.wait(<Future<Lauf>>[
      _starte('verstoesse', baumVerstoss),
      _starte('still', baumStill),
      _starte('hinweis', baumHinweis),
      _starte('ohne_lib', baumOhneLib),
    ]);
    verstoss = laeufe[0];
    still = laeufe[1];
    hinweis = laeufe[2];
    ohneLib = laeufe[3];
  });

  tearDownAll(() {
    // Auch nach fehlgeschlagenen Tests aufräumen. Windows hält Handles
    // manchmal kurz, deshalb ein paar Versuche, danach lieber laut scheitern
    // als ein verwaistes Temp-Verzeichnis verschweigen.
    Object? letzterFehler;
    for (var versuch = 0; versuch < 5; versuch++) {
      try {
        if (tempWurzel.existsSync()) {
          tempWurzel.deleteSync(recursive: true);
        }
        return;
      } on FileSystemException catch (fehler) {
        letzterFehler = fehler;
      }
    }
    fail('Temp-Baum ${tempWurzel.path} blieb liegen: $letzterFehler');
  });

  /// Vergleicht die Funde einer Datei genau: gleiche Zeilen, keine zusätzliche
  /// Meldung, und pro Zeile eine Regel, die den erwarteten Text enthält.
  void erwarteFunde(
    Lauf lauf,
    String datei,
    List<(int zeile, String regelTeil)> erwartet,
  ) {
    final funde = lauf.fuer(datei);
    expect(
      funde.map((f) => f.zeile).toList()..sort(),
      erwartet.map((e) => e.$1).toList()..sort(),
      reason: 'Zeilennummern für $datei\n${lauf.bericht}',
    );
    for (final eintrag in erwartet) {
      expect(
        funde.where((f) => f.zeile == eintrag.$1).map((f) => f.regel),
        anyElement(contains(eintrag.$2)),
        reason:
            'Regeltext in $datei Zeile ${eintrag.$1}\n'
            '${lauf.bericht}',
      );
    }
  }

  group('Grundverhalten', () {
    test('ein sauberer Baum ergibt Exit-Code 0 und keine Verstöße', () {
      expect(still.exitCode, 0, reason: still.bericht);
      expect(still.ausgabe, contains('keine Verstöße'), reason: still.bericht);
      expect(still.funde, isEmpty, reason: still.bericht);
    });

    test('ein Baum mit Verstößen ergibt Exit-Code 1', () {
      expect(verstoss.exitCode, 1, reason: verstoss.bericht);
      expect(verstoss.verstoesse, isNotEmpty, reason: verstoss.bericht);
    });

    test('ein fehlendes lib/ ergibt Exit-Code 2, nicht 0 und nicht 1', () {
      expect(ohneLib.exitCode, 2, reason: ohneLib.bericht);
      expect(
        ohneLib.fehlerausgabe,
        contains('lib/ nicht gefunden'),
        reason: ohneLib.bericht,
      );
    });

    test('die Ausgabe nennt bei jedem Fund Datei, Zeile und Regel', () {
      final kopf = RegExp(
        r'Architektur-Check: (\d+) Verstoß bzw\. Verstöße',
      ).firstMatch(verstoss.ausgabe);
      expect(kopf, isNotNull, reason: verstoss.bericht);
      expect(
        verstoss.verstoesse.length,
        int.parse(kopf!.group(1)!),
        reason:
            'Die Kopfzeile nennt eine andere Zahl als die Fundblöcke.\n'
            '${verstoss.bericht}',
      );
      for (final fund in verstoss.verstoesse) {
        expect(fund.datei, endsWith('.dart'), reason: verstoss.bericht);
        expect(fund.zeile, greaterThan(0), reason: verstoss.bericht);
        expect(fund.gefunden, isNotEmpty, reason: verstoss.bericht);
        expect(fund.regel, isNotEmpty, reason: verstoss.bericht);
      }
      expect(
        verstoss.ausgabe,
        contains('docs/architecture/dependency-rules.md'),
        reason: verstoss.bericht,
      );
    });

    test('gemeldete Pfade sind relativ und in Posix-Schreibweise', () {
      for (final fund in verstoss.funde) {
        expect(fund.datei, isNot(contains(r'\')), reason: verstoss.bericht);
        expect(fund.datei, isNot(startsWith('/')), reason: verstoss.bericht);
        expect(fund.datei, isNot(contains(':')), reason: verstoss.bericht);
      }
    });

    test('nur die erwarteten Dateien werden überhaupt gemeldet', () {
      expect(verstoss.dateienMitFund, <String>{
        'lib/app/di.dart',
        'test/di_test.dart',
        'tool/generieren.dart',
        'integration_test/getit_test.dart',
        'lib/core/facts/helper.dart',
        'lib/shared/presentation/geteilte_seite.dart',
        'lib/features/tours/application/application_instanziierung.dart',
        'lib/features/tours/karte/domain/entities/verschachtelte_domaene.dart',
        'lib/features/tours/domain/entities/domain_app_services.dart',
        'lib/features/tours/domain/entities/domain_weitere_sdk.dart',
        'lib/features/tours/presentation/pages/eigenes_data.dart',
        'lib/features/tours/domain/entities/technik_importe.dart',
        'lib/features/tours/domain/entities/mehrzeilige_direktive.dart',
        'lib/features/tours/domain/entities/bedingte_direktive.dart',
        'lib/features/tours/domain/entities/zwei_uris.dart',
        'lib/features/tours/domain/entities/kommentierter_import.dart',
        'lib/features/tours/domain/entities/vorlage_im_literal.dart',
        'lib/features/tours/domain/entities/crlf.dart',
        'lib/features/tours/domain/repositories/tour_repository.dart',
        'lib/features/tours/domain/usecases/core_import.dart',
        'lib/features/tours/domain/usecases/schicht_importe.dart',
        'lib/features/tours/presentation/notifier_und_widget.dart',
        'lib/features/tours/presentation/pages/fremdes_feature_paket.dart',
        'lib/features/tours/presentation/pages/fremdes_feature_relativ.dart',
        'lib/features/tours/presentation/pages/navigator_api.dart',
        'lib/features/tours/presentation/pages/route_string.dart',
        'lib/features/tours/presentation/pages/supabase_seite.dart',
        'lib/features/tours/presentation/widgets/ausgabe.dart',
        'lib/features/tours/presentation/widgets/instanziierung.dart',
        'lib/features/tours/presentation/widgets/literale.dart',
        'lib/map/domain/karten_technik.dart',
        'lib/map/domain/fremde_importe.dart',
        'lib/map/presentation/karten_host.dart',
        'lib/map/presentation/webview_daneben.dart',
        'lib/services/karten_adapter.dart',
        'lib/features/discovery/presentation/karten_zugriff.dart',
        'lib/features/discovery/presentation/avatar_versuch.dart',
        'lib/features/discovery/domain/avatar_vertrag.dart',
        'lib/features/discovery/presentation/karten_sdk_versuch.dart',
        'lib/features/discovery/presentation/ortung_versuch.dart',
        'lib/features/discovery/presentation/ortung_familie.dart',
        'lib/map/presentation/ortung_daneben.dart',
        'lib/features/settings/data/praeferenz_versuch.dart',
        'lib/features/settings/data/praeferenz_familie.dart',
        'lib/app/praeferenz_daneben.dart',
        'lib/core/greift_auf_feature.dart',
        'lib/kernel/greift_auf_feature.dart',
        'lib/kernel/greift_auf_core.dart',
        'lib/kernel/holt_flutter.dart',
        'lib/features/discovery/presentation/orientierung_versuch.dart',
        'lib/app/orientierung_daneben.dart',
        'lib/features/discovery/presentation/orientierung_familie.dart',
        'lib/features/facts/presentation/sprach_versuch.dart',
        'lib/app/sprache_daneben.dart',
        'lib/features/discovery/presentation/ton_versuch.dart',
        'lib/features/tours/domain/entities/ton_in_domaene.dart',
        'lib/features/tours/presentation/pages/fremdes_feature_verschachtelt.dart',
        'lib/map/presentation/luecke_eigenes_data.dart',
        'lib/map/presentation/fremdes_feature_data_regel17.dart',
      }, reason: verstoss.bericht);
    });
  });

  group('Import-Grenzen', () {
    test('Domain darf keine Technik importieren', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/entities/technik_importe.dart',
        <(int, String)>[
          (1, 'Regel 1: Domain darf Flutter nicht importieren'),
          (2, 'Regel 2: Domain darf Riverpod nicht importieren'),
          // flutter_riverpod trifft das Flutter-Verbot, nicht das
          // Riverpod-Verbot. Festgehalten, damit die Reihenfolge der
          // Verbotsmuster nicht unbemerkt kippt.
          (3, 'Regel 1: Domain darf Flutter nicht importieren'),
          (4, 'Regel 3: Domain darf Supabase nicht importieren'),
          (5, 'Regel 4: Domain darf kein Routing importieren'),
          (6, 'Regel 4: Domain darf keine Geräte-SDK importieren'),
          (7, 'Regel 4: Domain darf keine Storage-SDK importieren'),
          (8, 'Regel 4: Domain darf keine Karten-SDK importieren'),
          // flutter_rotation_sensor trifft das Flutter-Verbot, nicht das
          // Geräte-SDK-Verbot: der Paketname beginnt selbst mit `flutter_`.
          // Dieselbe Lage wie bei flutter_riverpod in Zeile 3.
          (9, 'Regel 1: Domain darf Flutter nicht importieren'),
          (10, 'Regel 4: Domain darf keine Geräte-SDK importieren'),
        ],
      );
    });

    test('Domain darf nicht aus core importieren', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/usecases/core_import.dart',
        <(int, String)>[
          (1, 'Gate 6: Feature-Domain darf nicht aus core importieren'),
        ],
      );
    });

    test('Domain darf nicht auf data oder presentation zeigen', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/usecases/schicht_importe.dart',
        <(int, String)>[
          (1, 'domain darf nicht auf data zeigen'),
          (2, 'domain darf nicht auf presentation zeigen'),
        ],
      );
    });

    test('Presentation darf Supabase nicht direkt aufrufen', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/presentation/pages/supabase_seite.dart',
        <(int, String)>[
          (1, 'Regel 5: Presentation darf Supabase nicht direkt aufrufen'),
        ],
      );
    });

    test('fremdes presentation und data über den Paketpfad', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/presentation/pages/fremdes_feature_paket.dart',
        <(int, String)>[
          (1, 'Regel 8: presentation von "challenges" darf nur dieses Feature'),
          (2, 'Regel 9: data von "challenges" darf nur dieses Feature'),
        ],
      );
    });

    test('fremdes presentation und data über einen relativen Pfad', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/presentation/pages/fremdes_feature_relativ.dart',
        <(int, String)>[
          (1, 'Regel 8: presentation von "challenges" darf nur dieses Feature'),
          (2, 'Regel 9: data von "challenges" darf nur dieses Feature'),
        ],
      );
      final funde = verstoss.fuer(
        'lib/features/tours/presentation/pages/fremdes_feature_relativ.dart',
      );
      expect(
        funde.first.gefunden,
        contains('aufgelöst: package:fact_app/features/challenges/'),
        reason:
            'Der relative Pfad muss in der Meldung aufgelöst erscheinen.\n'
            '${verstoss.bericht}',
      );
    });

    test(
      'Gegenprobe: Importe innerhalb des eigenen Features bleiben still',
      () {
        expect(
          still.fuer(
            'lib/features/tours/presentation/pages/eigenes_feature.dart',
          ),
          isEmpty,
          reason: still.bericht,
        );
      },
    );

    test('GetIt und injectable in lib, test und tool', () {
      erwarteFunde(verstoss, 'lib/app/di.dart', <(int, String)>[
        (1, 'ADR-005: GetIt ist ausgeschlossen'),
        (2, 'ADR-005: injectable ist ausgeschlossen'),
      ]);
      erwarteFunde(verstoss, 'test/di_test.dart', <(int, String)>[
        (1, 'ADR-005: GetIt ist ausgeschlossen'),
      ]);
      erwarteFunde(verstoss, 'tool/generieren.dart', <(int, String)>[
        (1, 'ADR-005: injectable ist ausgeschlossen'),
      ]);
    });
  });

  group('Scanner', () {
    test('mehrzeilige Direktive: gemeldet wird die Zeile des URI', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/entities/mehrzeilige_direktive.dart',
        <(int, String)>[(2, 'Regel 1: Domain darf Flutter nicht importieren')],
      );
    });

    test('bedingte Direktive: der Verstoß im zweiten URI wird gefunden', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/entities/bedingte_direktive.dart',
        <(int, String)>[(2, 'Regel 1: Domain darf Flutter nicht importieren')],
      );
    });

    test('zwei verletzende URIs in einer Direktive geben zwei Meldungen', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/entities/zwei_uris.dart',
        <(int, String)>[
          (1, 'Regel 4: Domain darf kein Routing importieren'),
          (1, 'Regel 2: Domain darf Riverpod nicht importieren'),
        ],
      );
    });

    test('auskommentierte Verbote werden ignoriert', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/entities/kommentierter_import.dart',
        <(int, String)>[(3, 'Regel 4: Domain darf kein Routing importieren')],
      );
    });

    test('Direktiven in einem String-Literal sind kein Verstoß', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/entities/vorlage_im_literal.dart',
        <(int, String)>[(1, 'Regel 4: Domain darf kein Routing importieren')],
      );
    });

    test('CRLF verschiebt keine Zeilennummer', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/entities/crlf.dart',
        <(int, String)>[
          (4, 'Regel 1: Domain darf Flutter nicht importieren'),
          (7, 'Gate 9: kein print() oder debugPrint()'),
        ],
      );
      final printFund = verstoss
          .fuer('lib/features/tours/domain/entities/crlf.dart')
          .firstWhere((f) => f.zeile == 7);
      expect(
        printFund.gefunden,
        "print('crlf');",
        reason:
            'Der Zeilentext einer CRLF-Datei darf kein Wagenrücklaufzeichen '
            'enthalten.\n${verstoss.bericht}',
      );
    });

    test('rohe, dreifache und interpolierte Literale bringen den Scanner nicht '
        'aus dem Tritt', () {
      // Das Muster steht in Zeile 2, 4 und 9 in Literalen, echter Verstoß
      // erst in Zeile 12. Genau hier verschluckt eine zu breite Maskierung
      // typischerweise den echten Fund.
      erwarteFunde(
        verstoss,
        'lib/features/tours/presentation/widgets/literale.dart',
        <(int, String)>[(12, 'ADR-004: keine rohen Route-Strings')],
      );
    });
  });

  group('Weitere Prüfungen', () {
    test('Geschäftsbegriff im Pfad unter core', () {
      erwarteFunde(verstoss, 'lib/core/facts/helper.dart', <(int, String)>[
        (1, 'Regel 11: core darf das Konzept "fact" nicht besitzen'),
      ]);
    });

    test('Gegenprobe: technischer Begriff unter core bleibt still', () {
      expect(
        still.fuer('lib/core/types/result.dart'),
        isEmpty,
        reason: still.bericht,
      );
    });

    test('rohe Navigator-API außerhalb der Routing-Infrastruktur', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/presentation/pages/navigator_api.dart',
        <(int, String)>[(3, 'ADR-004: die Navigator-API umgeht go_router')],
      );
    });

    test(
      'Gegenprobe: dieselbe Navigation in lib/app/routing/ bleibt still',
      () {
        expect(
          still.fuer('lib/app/routing/navigator_api.dart'),
          isEmpty,
          reason: still.bericht,
        );
      },
    );

    test('Route-Literal wird gemeldet, eine Variable bewusst nicht', () {
      // Die Ausnahme für Variablen ist im Skript begründet: typisierte Routen
      // liefern den Pfad, ein Verbot würde korrekten Code melden.
      erwarteFunde(
        verstoss,
        'lib/features/tours/presentation/pages/route_string.dart',
        <(int, String)>[(3, 'ADR-004: keine rohen Route-Strings')],
      );
    });

    test('print, debugPrint und die Tear-off-Form', () {
      // printWidth in Zeile 9 und sprintf in Zeile 10 sind keine Verstöße.
      erwarteFunde(
        verstoss,
        'lib/features/tours/presentation/widgets/ausgabe.dart',
        <(int, String)>[
          (3, 'Gate 9: kein print() oder debugPrint()'),
          (4, 'Gate 9: kein print() oder debugPrint()'),
          (8, 'Gate 9: kein print() oder debugPrint()'),
        ],
      );
    });

    test(
      'dart:developer in lib/features ist ein Hinweis und lässt Exit-Code 0',
      () {
        expect(hinweis.exitCode, 0, reason: hinweis.bericht);
        expect(hinweis.verstoesse, isEmpty, reason: hinweis.bericht);
        expect(hinweis.hinweise, hasLength(1), reason: hinweis.bericht);
        final fund = hinweis.hinweise.single;
        expect(fund.datei, 'lib/features/tours/application/protokoll.dart');
        expect(fund.zeile, 2);
        expect(fund.regel, contains('Logging-Vertrag'));
        expect(
          hinweis.ausgabe,
          contains('die den Lauf nicht abbrechen'),
          reason: hinweis.bericht,
        );
      },
    );

    test('Regel 7: Instanziierung in presentation', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/presentation/widgets/instanziierung.dart',
        <(int, String)>[
          (9, 'Regel 7: presentation instanziiert keine Repositories'),
          (10, 'Regel 7: presentation instanziiert keine Repositories'),
          (11, 'Regel 7: presentation instanziiert keine Repositories'),
        ],
      );
      // Zeile 1 abstrakte Deklaration, Zeile 6 Feld, Zeile 12 Provider-Bezug
      // und Zeile 13 benannter Konstruktor sind bewusst nicht dabei.
    });

    test('Regel 12: der Notifier navigiert, das Widget daneben nicht', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/presentation/notifier_und_widget.dart',
        <(int, String)>[(3, 'Regel 12: Notifier navigieren nicht')],
      );
    });

    test('Regel 13: verbotene Rückgabetypen im Repository-Vertrag', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/repositories/tour_repository.dart',
        <(int, String)>[
          (2, 'Regel 13: Repository-Vertrag liefert keine JSON-Map'),
          (3, 'Regel 13: Repository-Vertrag liefert kein AsyncValue'),
          (4, 'Regel 13: Repository-Vertrag kennt keine DTOs'),
        ],
      );
      // Zeile 5 ist Future<List<Tour>> und bleibt still.
    });

    test('Gegenprobe: ein sauberer Repository-Vertrag bleibt still', () {
      expect(
        still.fuer(
          'lib/features/tours/domain/repositories/sauberer_vertrag.dart',
        ),
        isEmpty,
        reason: still.bericht,
      );
    });
  });

  // Die sechs Verschärfungen Ä1 bis Ä6. Jede hat eine Positivprobe, und wo
  // eine zu breite Umsetzung korrekten Code melden würde, auch eine
  // Gegenprobe. Die Gegenproben liegen im stillen Baum, der insgesamt
  // Exit-Code 0 ohne einen einzigen Fund ergeben muss.
  group('Verschärfte Prüfungen', () {
    test('Ä1: Schichtverbote greifen auch unterhalb einer Unterstruktur', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/karte/domain/entities/verschachtelte_domaene.dart',
        <(int, String)>[
          (1, 'Regel 1: Domain darf Flutter nicht importieren'),
          (2, 'Regel 3: Domain darf Supabase nicht importieren'),
        ],
      );
    });

    test('Ä1 Gegenprobe: eine korrekte verschachtelte Domäne bleibt still', () {
      expect(
        still.fuer(
          'lib/features/tours/karte/domain/entities/'
          'saubere_verschachtelung.dart',
        ),
        isEmpty,
        reason:
            'Dart-SDK und eigene Feature-Domäne, absolut und relativ. Wird '
            'hier etwas gemeldet, ist die Erlaubnisliste zu eng.\n'
            '${still.bericht}',
      );
    });

    test('Ä1 Gegenprobe: ein Verzeichnis "domain_helpers" ist keine Domäne', () {
      expect(
        still.fuer(
          'lib/features/tours/presentation/domain_helpers/kein_domain.dart',
        ),
        isEmpty,
        reason:
            'Der Core-Import wäre in der Domäne ein Verstoß gegen Gate 6. Ein '
            'Fund hier hieße, das Muster liest ein Präfix als Segment.\n'
            '${still.bericht}',
      );
    });

    test('Ä2: die Domäne darf app/ und services/ nicht importieren', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/entities/domain_app_services.dart',
        <(int, String)>[
          (1, 'Domain-Erlaubnisliste'),
          (2, 'Domain-Erlaubnisliste'),
        ],
      );
    });

    test('Ä2: sqflite, http und hive fallen in der Domäne durch', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/entities/domain_weitere_sdk.dart',
        <(int, String)>[
          (1, 'Domain-Erlaubnisliste'),
          (2, 'Domain-Erlaubnisliste'),
          (3, 'Domain-Erlaubnisliste'),
        ],
      );
    });

    test(
      'Ä2: die allgemeine Meldung nennt den Grund, nicht nur das Verbot',
      () {
        final fund = verstoss
            .fuer('lib/features/tours/domain/entities/domain_weitere_sdk.dart')
            .first;
        expect(
          fund.regel,
          contains('dependency-rules.md'),
          reason:
              'Die Meldung muss auf das Quelldokument verweisen.\n'
              '${verstoss.bericht}',
        );
        expect(
          fund.regel,
          contains('data oder services'),
          reason:
              'Die Meldung muss sagen, wohin die Technik stattdessen gehört.\n'
              '${verstoss.bericht}',
        );
      },
    );

    test('Ä2: ein benanntes Verbot verdrängt die allgemeine Meldung', () {
      // technik_importe.dart hat zehn Importe, die alle ein benanntes Verbot
      // treffen. Gäbe es zusätzlich die allgemeine Meldung, stünden hier
      // zwanzig Funde und der Leser bekäme zwei Sätze für denselben Import.
      final funde = verstoss.fuer(
        'lib/features/tours/domain/entities/technik_importe.dart',
      );
      expect(funde, hasLength(10), reason: verstoss.bericht);
      expect(
        funde.where((f) => f.regel.contains('Domain-Erlaubnisliste')),
        isEmpty,
        reason: verstoss.bericht,
      );
    });

    test('Ä3: Regel 7 greift auch in application', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/application/application_instanziierung.dart',
        <(int, String)>[
          (3, 'Regel 7: application instanziiert keine Repositories'),
          (4, 'Regel 7: application instanziiert keine Repositories'),
        ],
      );
    });

    test(
      'Ä3 Gegenprobe: Provider-Bezug und Feld in application bleiben still',
      () {
        expect(
          still.fuer('lib/features/tours/application/saubere_steuerung.dart'),
          isEmpty,
          reason: still.bericht,
        );
      },
    );

    test('Ä4: presentation darf nicht auf das eigene data zeigen', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/presentation/pages/eigenes_data.dart',
        <(int, String)>[
          (1, 'presentation darf nicht auf data zeigen'),
          (2, 'presentation darf nicht auf data zeigen'),
        ],
      );
    });

    test('Ä4: fremdes data bleibt eine Meldung, nicht zwei', () {
      // Regel 9 deckt fremdes data schon ab. Die neue Prüfung gilt deshalb nur
      // für das eigene Feature, sonst stünden hier zwei Sätze pro Import.
      final funde = verstoss.fuer(
        'lib/features/tours/presentation/pages/fremdes_feature_paket.dart',
      );
      expect(
        funde.where((f) => f.zeile == 2),
        hasLength(1),
        reason: verstoss.bericht,
      );
    });

    test('Ä4 Gegenprobe: presentation darf application und domain kennen', () {
      expect(
        still.fuer(
          'lib/features/tours/presentation/pages/eigenes_feature.dart',
        ),
        isEmpty,
        reason: still.bericht,
      );
    });

    test('Ä5: Gate 7 greift auch in integration_test/', () {
      erwarteFunde(
        verstoss,
        'integration_test/getit_test.dart',
        <(int, String)>[(1, 'ADR-005: GetIt ist ausgeschlossen')],
      );
    });

    test(
      'Ä5 Gegenprobe: eine saubere Datei in integration_test/ bleibt still',
      () {
        expect(
          still.fuer('integration_test/saubere_integration_test.dart'),
          isEmpty,
          reason: still.bericht,
        );
      },
    );

    test('Ä5: ein fehlendes integration_test/ bricht den Lauf nicht ab', () {
      // Der Hinweisbaum hat kein integration_test/. Das Verzeichnis existiert
      // im Repository derzeit ebenfalls nicht.
      expect(hinweis.exitCode, 0, reason: hinweis.bericht);
      expect(
        hinweis.fehlerausgabe,
        isEmpty,
        reason:
            'Ein fehlendes Verzeichnis darf keine Fehlerausgabe erzeugen.\n'
            '${hinweis.bericht}',
      );
    });

    test('Ä6: presentation außerhalb von features/ wird geprüft', () {
      erwarteFunde(
        verstoss,
        'lib/shared/presentation/geteilte_seite.dart',
        <(int, String)>[
          (1, 'Regel 5: Presentation darf Supabase nicht direkt aufrufen'),
        ],
      );
    });

    test('Ä6 Gegenprobe: dasselbe presentation mit erlaubten Importen', () {
      expect(
        still.fuer('lib/shared/presentation/saubere_seite.dart'),
        isEmpty,
        reason: still.bericht,
      );
    });
  });

  // Ä7 bis Ä10: die drei gemessenen blinden Flecken vom 28.08.2026 und die
  // Regel, die den Karten-Host trägt. Alle vier hängen an einer einzigen
  // Frage: gilt eine Schichtregel nur unter `lib/features/` oder überall
  // unter `lib/`? Bis hierher galt sie an drei von vier Stellen nur dort,
  // und derselbe Import war je nach Ordner Verstoß oder erlaubt.
  group('Modulgrenzen und Karten-Host', () {
    test('Ä7: Schichtverbote gelten überall unter lib/, nicht nur in '
        'features/', () {
      erwarteFunde(
        verstoss,
        'lib/map/domain/karten_technik.dart',
        <(int, String)>[
          (1, 'Regel 1: Domain darf Flutter nicht importieren'),
          (2, 'Regel 1: Domain darf Flutter nicht importieren'),
          (3, 'Regel 3: Domain darf Supabase nicht importieren'),
          (4, 'Regel 4: Domain darf keine Karten-SDK importieren'),
        ],
      );
    });

    test('Ä7: die Erlaubnisliste greift auch in einem Modul ohne Feature', () {
      erwarteFunde(
        verstoss,
        'lib/map/domain/fremde_importe.dart',
        <(int, String)>[
          (1, 'Domain-Erlaubnisliste'),
          (2, 'Domain-Erlaubnisliste'),
        ],
      );
    });

    test('Ä7 Gegenprobe: die Domäne eines Moduls darf sich selbst '
        'importieren', () {
      expect(
        still.fuer('lib/map/domain/saubere_absicht.dart'),
        isEmpty,
        reason:
            'Die Modulwurzel fehlt oder ist falsch abgeleitet. Ohne sie meldet '
            'die Erlaubnisliste jeden modulinternen Import, und die '
            'Verallgemeinerung der Schichtmuster ist unbenutzbar.\n'
            '${still.bericht}',
      );
    });

    test('Ä8: fremdes presentation und data auch außerhalb von features/', () {
      erwarteFunde(
        verstoss,
        'lib/map/presentation/karten_host.dart',
        <(int, String)>[
          (1, 'Regel 8: presentation von "tours" darf nur dieses Feature'),
          (2, 'Regel 9: data von "challenges" darf nur dieses Feature'),
        ],
      );
      erwarteFunde(
        verstoss,
        'lib/services/karten_adapter.dart',
        <(int, String)>[
          (1, 'Regel 8: presentation von "tours" darf nur dieses Feature'),
        ],
      );
    });

    test('Ä8 Gegenprobe: die App-Komposition ist ausgenommen', () {
      expect(
        still.fuer('lib/app/komposition.dart'),
        isEmpty,
        reason:
            'dependency-rules.md gibt der App-Komposition "All public feature '
            'entry points and services". Fällt diese Ausnahme, sind '
            'app_routes.dart, app.dart, bootstrap.dart und tour_steps.dart '
            'rot.\n${still.bericht}',
      );
    });

    test('Ä8: core bekommt eine Meldung, nicht zwei', () {
      // _coreBans verbietet package:fact_app/features/ schon pauschal und
      // nennt dabei die genauere Regel 11. Ohne die Ausnahme für core stünden
      // hier zwei Sätze für denselben Import.
      final funde = verstoss.fuer('lib/core/greift_auf_feature.dart');
      expect(funde, hasLength(1), reason: verstoss.bericht);
      expect(
        funde.single.regel,
        contains('Regel 11'),
        reason: verstoss.bericht,
      );
    });

    test('Ä9: ein Feature sieht vom Karten-Host nur map/domain/', () {
      erwarteFunde(
        verstoss,
        'lib/features/discovery/presentation/karten_zugriff.dart',
        <(int, String)>[
          (1, 'Regel 18: Features sehen vom Karten-Host nur map/domain/'),
          (2, 'Regel 18: Features sehen vom Karten-Host nur map/domain/'),
        ],
      );
    });

    test('Ä9 Gegenprobe: map/domain/ bleibt für Features offen', () {
      expect(
        still.fuer('lib/features/discovery/presentation/karten_absicht.dart'),
        isEmpty,
        reason:
            'Ein Feature muss seine Absicht abgeben können. Wird das hier '
            'gemeldet, ist der Host von außen gar nicht mehr ansprechbar.\n'
            '${still.bericht}',
      );
    });

    test('Ä10: webview_flutter außerhalb des Avatar-Ordners', () {
      // Das Paket steht heute nicht in pubspec.yaml. Die Regel entsteht
      // trotzdem jetzt, damit sie da ist, wenn E-10 es freigibt.
      erwarteFunde(
        verstoss,
        'lib/features/discovery/presentation/avatar_versuch.dart',
        <(int, String)>[(1, 'Regel 19: webview_flutter ist auf')],
      );
      erwarteFunde(
        verstoss,
        'lib/map/presentation/webview_daneben.dart',
        <(int, String)>[(1, 'Regel 19: webview_flutter ist auf')],
      );
    });

    test('Ä10 Gegenprobe: im Avatar-Ordner ist die WebView erlaubt', () {
      expect(
        still.fuer('lib/map/presentation/avatar/avatar_view.dart'),
        isEmpty,
        reason:
            'Sonst ist die Regel ein Verbot statt einer Kapselung, und der '
            'Avatar hat keinen Ort mehr.\n${still.bericht}',
      );
    });

    test('Ä10 Gegenprobe: in einer Domäne meldet nur Regel 4', () {
      // Gemessen, nicht vermutet: vor der Behebung standen hier **zwei**
      // Meldungen, `[avatar-kapselung] Regel 19` und die allgemeine
      // `[domain] Domain-Erlaubnisliste`. Dieselbe Abgrenzung wie bei Regel 20
      // und 21, mit einem Zusatz: in einer Domäne wäre Regel 19 sogar
      // irreführend, denn sie verweist auf lib/map/presentation/avatar/, und
      // dorthin darf eine Domäne unter keinen Umständen zeigen.
      erwarteFunde(
        verstoss,
        'lib/features/discovery/domain/avatar_vertrag.dart',
        <(int, String)>[(1, 'Regel 4: Domain darf keine WebView-SDK')],
      );

      final funde = verstoss.fuer(
        'lib/features/discovery/domain/avatar_vertrag.dart',
      );
      expect(funde, hasLength(1), reason: verstoss.bericht);
      expect(
        funde.single.regel,
        isNot(contains('Regel 19')),
        reason:
            'Regel 19 muss in einer Domäne schweigen, sonst steht die '
            'Heimatverzeichnis-Regel neben der Domänenregel.\n'
            '${verstoss.bericht}',
      );
      expect(
        funde.single.regel,
        isNot(contains('Domain-Erlaubnisliste')),
        reason:
            'Das benannte Verbot muss die allgemeine Meldung verdrängen, '
            'siehe „Ä2: ein benanntes Verbot verdrängt die allgemeine '
            'Meldung".\n${verstoss.bericht}',
      );
    });

    test('Ä11: das Karten-SDK außerhalb des Karten-Hosts', () {
      // Regel 18 hält Features aus map/presentation/ heraus, Regel 20
      // verbietet den direkten Griff zum Paket. Ohne sie dürfte ein Feature
      // die Karte nicht über den Host steuern, wohl aber an ihm vorbei.
      erwarteFunde(
        verstoss,
        'lib/features/discovery/presentation/karten_sdk_versuch.dart',
        <(int, String)>[(1, 'Regel 20: das Karten-SDK gehört dem Karten-Host')],
      );
    });

    test('Ä11 Gegenprobe: im Karten-Host ist das SDK erlaubt', () {
      expect(
        still.fuer('lib/map/presentation/map_host_sdk.dart'),
        isEmpty,
        reason:
            'Sonst hat die Karte keinen Ort, an dem sie gezeichnet werden '
            'darf.\n${still.bericht}',
      );
    });

    test('Ä12: das Geo-SDK außerhalb des Ortungsdienstes', () {
      // Vor Regel 21 lief dieser Import überall unterhalb von lib/ durch,
      // außer in einem domain/-Segment. `domain-map.md:153-156` zählt den
      // geolocation provider zu den unterstützenden Techniken, damit ist
      // lib/services/location/ sein Ort und kein anderer.
      erwarteFunde(
        verstoss,
        'lib/features/discovery/presentation/ortung_versuch.dart',
        <(int, String)>[(1, 'Regel 21: das Geo-SDK gehört dem Ortungsdienst')],
      );
      erwarteFunde(
        verstoss,
        'lib/map/presentation/ortung_daneben.dart',
        <(int, String)>[(1, 'Regel 21: das Geo-SDK gehört dem Ortungsdienst')],
      );
    });

    test('Ä12: das Verbot trifft die ganze geolocator-Familie', () {
      // Absichtlich breiter als Regel 20: dort steht `^package:maplibre_gl`
      // vollständig, hier nur `^package:geolocator`. Die Typen `Position` und
      // `LocationAccuracy` liegen in `geolocator_platform_interface`, ein
      // Verbot nur auf `geolocator` ließe den naheliegendsten Umweg offen.
      erwarteFunde(
        verstoss,
        'lib/features/discovery/presentation/ortung_familie.dart',
        <(int, String)>[
          (1, 'Regel 21: das Geo-SDK gehört dem Ortungsdienst'),
          (2, 'Regel 21: das Geo-SDK gehört dem Ortungsdienst'),
        ],
      );
    });

    test('Ä12 Gegenprobe: im Ortungsdienst ist das Geo-SDK erlaubt', () {
      expect(
        still.fuer('lib/services/location/ortungsdienst.dart'),
        isEmpty,
        reason:
            'Sonst hat die Ortung keinen Ort mehr, an dem sie stattfinden '
            'darf.\n${still.bericht}',
      );
    });

    test('Ä13: der Gerätespeicher außerhalb des Präferenz-Adapters', () {
      // Die Regel ist am 31.08.2026 entstanden, und sie ist genau das, was das
      // Skript vorher ausdrücklich nicht sein wollte. Solange das Paket nicht
      // in pubspec.yaml stand, wäre sie eine Entscheidung gewesen; seit es
      // drinsteht und `lib/services/preferences/` sein Ort ist, ist sie eine
      // Durchsetzung.
      erwarteFunde(
        verstoss,
        'lib/features/settings/data/praeferenz_versuch.dart',
        <(int, String)>[
          (1, 'Regel 22: der Gerätespeicher gehört dem Präferenz-Adapter'),
        ],
      );
      erwarteFunde(verstoss, 'lib/app/praeferenz_daneben.dart', <(int, String)>[
        (1, 'Regel 22: der Gerätespeicher gehört dem Präferenz-Adapter'),
      ]);
    });

    test('Ä13: das Verbot trifft die ganze shared_preferences-Familie', () {
      // Wie bei Regel 21 breiter als der Paketname: in
      // `shared_preferences_platform_interface` liegt
      // `SharedPreferencesStorePlatform`, und das ist der Weg, auf dem jemand
      // am Adapter vorbei eine eigene Plattform setzen würde.
      erwarteFunde(
        verstoss,
        'lib/features/settings/data/praeferenz_familie.dart',
        <(int, String)>[
          (1, 'Regel 22: der Gerätespeicher gehört dem Präferenz-Adapter'),
          (2, 'Regel 22: der Gerätespeicher gehört dem Präferenz-Adapter'),
        ],
      );
    });

    test('Ä13 Gegenprobe: im Präferenz-Adapter ist er erlaubt', () {
      expect(
        still.fuer('lib/services/preferences/praeferenz_adapter.dart'),
        isEmpty,
        reason:
            'Sonst hat der Gerätespeicher keinen Ort mehr, an dem er '
            'angesprochen werden darf. ${still.bericht}',
      );
    });

    test('Ä14: der Kern importiert eine Feature-Domäne', () {
      // Regel 23 dreht die Aufnahmerichtung von D-18 um: eine Domäne darf den
      // Kern sehen, aber der Kern darf niemals zu einem Feature zurückgreifen.
      erwarteFunde(
        verstoss,
        'lib/kernel/greift_auf_feature.dart',
        <(int, String)>[
          (1, '[kernel] Regel 23: der geteilte Kern darf nur das Dart-SDK'),
        ],
      );
    });

    test('Ä14: der Kern importiert core', () {
      // `core` liegt selbst schon tiefer als jedes Feature, aber ADR-008
      // zieht den Kern noch eine Ebene darunter, und [_isAllowedKernelImport]
      // nennt `core` deshalb bewusst nicht in seiner Erlaubnisliste.
      erwarteFunde(verstoss, 'lib/kernel/greift_auf_core.dart', <(int, String)>[
        (1, '[kernel] Regel 23: der geteilte Kern darf nur das Dart-SDK'),
      ]);
    });

    test('Ä14: der Kern importiert Flutter', () {
      // Regel 2 aus ADR-008 verlangt reines Dart im Kern, damit jede der drei
      // Domänen ihn ohne Widget-Abhängigkeit importieren kann.
      erwarteFunde(verstoss, 'lib/kernel/holt_flutter.dart', <(int, String)>[
        (1, '[kernel] Regel 23: der geteilte Kern darf nur das Dart-SDK'),
      ]);
    });

    test('Ä14 Gegenprobe: eine Feature-Domäne darf den Kern importieren', () {
      expect(
        still.fuer('lib/features/tours/domain/entities/nutzt_kern.dart'),
        isEmpty,
        reason:
            'Sonst hätte D-18 keinen Weg, die Schwierigkeitsstufe aus dem '
            'Kern in einer Domäne zu nutzen.\n${still.bericht}',
      );
    });

    test(
      'Ä14 Gegenprobe: der Kern importiert das Dart-SDK und sich selbst',
      () {
        expect(
          still.fuer('lib/kernel/nutzt_dart_und_sich_selbst.dart'),
          isEmpty,
          reason:
              'Sonst könnte sich der Kern nicht mehr selbst zusammensetzen.\n'
              '${still.bericht}',
        );
      },
    );

    test('Ä17: die Tonwiedergabe außerhalb des Ton-Dienstes', () {
      // Vor Regel 26 lief dieser Import überall unterhalb von lib/ durch,
      // außer in einem domain/-Segment.
      erwarteFunde(
        verstoss,
        'lib/features/discovery/presentation/ton_versuch.dart',
        <(int, String)>[
          (1, 'Regel 26: die Tonwiedergabe gehört dem Ton-Dienst'),
        ],
      );
    });

    test('Ä17: in einer Domäne meldet Regel 4 und nicht Regel 26', () {
      // Die schichtgenaue Regel gewinnt, die allgemeine schweigt, und
      // umgekehrt: in einer Domäne ist Regel 4 die genauere Aussage. Ohne
      // den eigenen Eintrag in _domainBans stünde hier die unspezifische
      // Meldung der Erlaubnisliste.
      erwarteFunde(
        verstoss,
        'lib/features/tours/domain/entities/ton_in_domaene.dart',
        <(int, String)>[
          (1, 'Regel 4: Domain darf keine Geräte-SDK importieren'),
        ],
      );
    });

    test('Ä16: die Sprachausgabe außerhalb des Sprachdienstes', () {
      // Vor Regel 25 lief dieser Import überall unterhalb von lib/ durch,
      // außer in einem domain/-Segment. Die Sprachausgabe ist eine
      // unterstützende Technik wie die Ortung und der Kompass, damit ist
      // lib/services/speech/ ihr Ort und kein anderer.
      erwarteFunde(
        verstoss,
        'lib/features/facts/presentation/sprach_versuch.dart',
        <(int, String)>[
          (1, 'Regel 25: die Sprachausgabe gehört dem Sprachdienst'),
        ],
      );
      erwarteFunde(verstoss, 'lib/app/sprache_daneben.dart', <(int, String)>[
        (1, 'Regel 25: die Sprachausgabe gehört dem Sprachdienst'),
      ]);
    });

    test('Ä15: der Kompass-Sensor außerhalb des Orientierungsdienstes', () {
      // Vor Regel 24 lief dieser Import überall unterhalb von lib/ durch,
      // außer in einem domain/-Segment. Der Kompass-Sensor ist eine
      // unterstützende Technik wie die Ortung, damit ist
      // lib/services/orientation/ sein Ort und kein anderer.
      erwarteFunde(
        verstoss,
        'lib/features/discovery/presentation/orientierung_versuch.dart',
        <(int, String)>[
          (1, 'Regel 24: der Kompass-Sensor gehört dem Orientierungsdienst'),
        ],
      );
      erwarteFunde(
        verstoss,
        'lib/app/orientierung_daneben.dart',
        <(int, String)>[
          (1, 'Regel 24: der Kompass-Sensor gehört dem Orientierungsdienst'),
        ],
      );
    });

    test('Ä15: das Verbot trifft beide Pakete der Familie', () {
      // Anders als bei Regel 21 und 22 teilen sich die beiden Pakete kein
      // gemeinsames Namenspräfix: `native_device_orientation` ist die
      // transitive Abhängigkeit mit einer eigenen Gerätestellungs-API und
      // damit der naheliegendste Umweg am Orientierungsdienst vorbei.
      erwarteFunde(
        verstoss,
        'lib/features/discovery/presentation/orientierung_familie.dart',
        <(int, String)>[
          (1, 'Regel 24: der Kompass-Sensor gehört dem Orientierungsdienst'),
          (2, 'Regel 24: der Kompass-Sensor gehört dem Orientierungsdienst'),
        ],
      );
    });

    test('Ä15 Gegenprobe: im Orientierungsdienst ist der Sensor erlaubt', () {
      expect(
        still.fuer('lib/services/orientation/orientierungs_adapter.dart'),
        isEmpty,
        reason:
            'Sonst hat der Kompass-Sensor keinen Ort mehr, an dem er '
            'angesprochen werden darf.\n${still.bericht}',
      );
    });

    test('Ä13 Gegenprobe: in einer Domäne meldet nur Regel 4', () {
      // Dieselbe Abgrenzung wie bei Regel 20 und 21. Regel 4 verbietet
      // Storage-SDKs in jeder Domäne und ist dort die genauere Aussage.
      final zeile7 = verstoss
          .fuer('lib/features/tours/domain/entities/technik_importe.dart')
          .where((fund) => fund.zeile == 7)
          .toList();

      expect(zeile7, hasLength(1), reason: verstoss.bericht);
      expect(zeile7.single.regel, contains('Regel 4: Domain darf keine'));
    });

    test('Ä12 Gegenprobe: in einer Domäne meldet nur Regel 4', () {
      // Dieselbe Abgrenzung wie bei Regel 20 und aus demselben Grund: Regel 4
      // verbietet Geräte-SDKs in jeder Domäne und ist dort die genauere
      // Aussage. Regel 21 lässt Domänen deshalb aus, sonst stünden für
      // denselben Import zwei Meldungen da.
      final zeile6 = verstoss
          .fuer('lib/features/tours/domain/entities/technik_importe.dart')
          .where((fund) => fund.zeile == 6)
          .toList();

      expect(zeile6, hasLength(1), reason: verstoss.bericht);
      expect(zeile6.single.regel, contains('Regel 4: Domain darf keine'));
    });

    test('Ä11 Gegenprobe: in einer Domäne meldet nur Regel 4', () {
      // Regel 4 verbietet Karten-SDK in jeder Domäne und ist die genauere
      // Aussage. Regel 20 lässt Domänen deshalb aus, sonst stünden für
      // denselben Import zwei Meldungen da. Dasselbe Muster wie in Ä2.
      //
      // Gemessen, nicht theoretisch: die erste Fassung von Regel 20 ohne
      // diese Ausnahme hat genau hier eine doppelte Meldung erzeugt und zwei
      // bestehende Tests rot gemacht.
      final zeile8 = verstoss
          .fuer('lib/features/tours/domain/entities/technik_importe.dart')
          .where((fund) => fund.zeile == 8)
          .toList();

      expect(zeile8, hasLength(1), reason: verstoss.bericht);
      expect(zeile8.single.regel, contains('Regel 4: Domain darf keine'));
    });

    test('Ä15 Gegenprobe: in einer Domäne meldet nur Regel 4', () {
      // Für native_device_orientation, nicht für flutter_rotation_sensor:
      // dessen Paketname beginnt selbst mit `flutter_` und trifft in einer
      // Domäne bereits Regel 1, siehe Zeile 9 im Test „Domain darf keine
      // Technik importieren" und die Begründung bei [_orientationSdkBans] im
      // Skript. Für native_device_orientation gilt dieselbe Abgrenzung wie
      // bei Regel 21 und 22: Regel 4 verbietet Geräte-SDKs in jeder Domäne
      // und ist dort die genauere Aussage. Regel 24 lässt Domänen deshalb
      // aus, sonst stünden für denselben Import zwei Meldungen da.
      final zeile10 = verstoss
          .fuer('lib/features/tours/domain/entities/technik_importe.dart')
          .where((fund) => fund.zeile == 10)
          .toList();

      expect(zeile10, hasLength(1), reason: verstoss.bericht);
      expect(zeile10.single.regel, contains('Regel 4: Domain darf keine'));
    });
  });

  // Die beiden Lücken, die REBUILD_STATUS.md unter "Drei verbleibende
  // Asymmetrien im Architektur-Check" als erste und dritte führte. Jede
  // bekommt beide Richtungen: die Positivprobe im verstoss-Baum und die
  // Gegenprobe(n) im stillen Baum, sonst prüft der Test nur die Hälfte der
  // Behauptung.
  group('Geschlossene Lücken: Cross-Feature-Tiefe und Regel 17 im Modul', () {
    test('Lücke 1: fremdes presentation und data hinter einer '
        'Unterstruktur', () {
      erwarteFunde(
        verstoss,
        'lib/features/tours/presentation/pages/'
        'fremdes_feature_verschachtelt.dart',
        <(int, String)>[
          (1, 'Regel 8: presentation von "challenges" darf nur dieses Feature'),
          (2, 'Regel 9: data von "challenges" darf nur dieses Feature'),
        ],
      );
    });

    test(
      'Lücke 1 Gegenprobe: die eigene verschachtelte Schicht bleibt still',
      () {
        expect(
          still.fuer(
            'lib/features/tours/orchestrierung/eigene_verschachtelung.dart',
          ),
          isEmpty,
          reason:
              'cross.group(1) == ownFeature, also gilt hier weder Regel 8 '
              'noch Regel 9. Wird hier etwas gemeldet, ist die '
              'Eigen/Fremd-Unterscheidung nach der Tiefenerweiterung '
              'kaputtgegangen.\n${still.bericht}',
        );
      },
    );

    test('Lücke 2: der Karten-Host darf sein eigenes data/ nicht lesen', () {
      erwarteFunde(
        verstoss,
        'lib/map/presentation/luecke_eigenes_data.dart',
        <(int, String)>[(1, 'Regel 17: presentation darf nicht auf data')],
      );
    });

    test('Lücke 2 Gegenprobe: application bleibt im Karten-Host erlaubt', () {
      expect(
        still.fuer('lib/map/presentation/erlaubte_application.dart'),
        isEmpty,
        reason:
            'Nur data ist verboten, nicht die ganze Modulwurzel. Wird hier '
            'etwas gemeldet, prüft die neue Regel-17-Fassung die falsche '
            'Schicht.\n${still.bericht}',
      );
    });

    test('Lücke 2 Gegenprobe: fremdes Feature-data bleibt eine Meldung, '
        'nicht zwei', () {
      // Die Modulwurzel des Karten-Hosts (package:fact_app/map/) passt
      // nicht auf einen Import unter package:fact_app/features/. Ohne
      // diese Abgrenzung stünden hier Regel 9 und die neue Regel-17-Prüfung
      // nebeneinander für denselben Import.
      final funde = verstoss.fuer(
        'lib/map/presentation/fremdes_feature_data_regel17.dart',
      );
      expect(funde, hasLength(1), reason: verstoss.bericht);
      expect(
        funde.single.regel,
        contains('Regel 9: data von "tours" darf nur dieses Feature'),
        reason: verstoss.bericht,
      );
    });

    test('Lücke 2 Gegenprobe: eine Schicht direkt unter lib/ kennt keine '
        'Modulwurzel', () {
      // _modulwurzel liefert hier bewusst null (die Wurzel wäre sonst das
      // ganze Paket). Dieser Test hält fest, dass der zweite Zweig der
      // Regel-17-Prüfung diesen Fall ohne Ausnahme und ohne Absturz
      // überspringt.
      expect(
        still.fuer('lib/presentation/schicht_direkt_unter_lib.dart'),
        isEmpty,
        reason: still.bericht,
      );
    });
  });

  // Diese Gruppe hält den heutigen Zustand fest. Jeder Test hier ist grün,
  // weil das Skript nichts meldet.
  //
  // Die Begründung für jede der vier Lücken steht im Kopfkommentar von
  // tool/check_architecture.dart unter "Bewusst offene Lücken". Wer eine
  // davon schließen will, muss zuerst die dortige Begründung widerlegen.
  group('Offene Lücken', () {
    test('Lücke 1: benannte Konstruktoren umgehen Regel 7', () {
      expect(
        still.fuer(
          'lib/features/tours/presentation/widgets/luecke_benannt.dart',
        ),
        isEmpty,
        reason:
            'TourRepository.remote() trifft das Muster nicht, weil hinter dem '
            'Namen ein Punkt statt einer Klammer steht. Ein breiteres Muster '
            'würde statische Factory-Helfer melden.\n${still.bericht}',
      );
    });

    test('Lücke 2: Direktiven werden nur am Zeilenanfang erkannt', () {
      expect(
        still.fuer(
          'lib/features/tours/domain/entities/luecke_zeilenanfang.dart',
        ),
        isEmpty,
        reason:
            'Die zweite Direktive derselben Zeile bleibt unsichtbar, obwohl '
            'sie Flutter in die Domäne holt. dart format erzeugt diese Form '
            'nie, und das Format-Gate läuft in derselben Pipeline.\n'
            '${still.bericht}',
      );
    });

    test('Lücke 3: Navigation mit einer Variable wird nicht gemeldet', () {
      expect(
        still.fuer(
          'lib/features/tours/presentation/pages/luecke_route_variable.dart',
        ),
        isEmpty,
        reason:
            'context.go(ziel) ist genau die Form, die eine typisierte Route '
            'erzeugt. Ein Verbot würde überwiegend korrekten Code melden.\n'
            '${still.bericht}',
      );
    });

    test('Lücke 4: ein fremdes domain/ ist kein Verstoß', () {
      expect(
        still.fuer('lib/features/tours/application/luecke_fremde_domain.dart'),
        isEmpty,
        reason:
            'Regel 10 verlangt einen öffentlichen Vertrag. Ein Import von '
            'features/x/domain/ kann der Vertrag selbst sein oder dessen '
            'Umgehung, und beides sieht im Quelltext gleich aus. Bleibt '
            'Review-Sache.\n${still.bericht}',
      );
    });
  });
}
