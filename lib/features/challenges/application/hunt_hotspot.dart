/// Die Hotspots einer Stadt: kuratierte Startpunkte für die Schnitzeljagd,
/// `02_Frontend/app/hunt-hotspots.js`.
///
/// ## So kommen kuratierte Datendateien der Quelle in den Neubau
///
/// Das hier ist die **erste** von mehreren, deshalb steht der Weg an dieser
/// Stelle und nicht nur im Werkzeug. Die PWA pflegt neben den Faktdaten eine
/// Handvoll redaktioneller Dateien ohne Gegenstück in Supabase:
/// `hunt-hotspots.js` (45 Zeilen), `damals-heute.jsx` (112),
/// `wallet-colors.jsx` (155), `hunt-routes.jsx` (229) und `city-intros.jsx`
/// (747). Alle fünf braucht der Neubau noch.
///
/// **Wo sie liegen:** in `application/` des Features, dem sie gehören, unter
/// `generated/`. Drei Regeln lassen keinen anderen Ort zu: Regel 17 hält
/// `presentation` aus jedem `data`-Verzeichnis heraus, auch aus dem eigenen;
/// Regel 11 verbietet unter `core/` jeden Geschäftsbegriff, ein gemeinsames
/// `lib/core/curated/` ist damit maschinell ausgeschlossen; und Gate 6 lässt
/// eine Feature-**Domäne** nur das Dart-SDK und die eigene Domäne importieren,
/// woran schon [MapPosition] scheitert. Über die Feature-Grenze ist
/// `application/` nach Regel 10 der erlaubte Weg, und den braucht
/// `hunt-routes.jsx` später für `tours`.
///
/// **Wie Drift bemerkt wird:** `dart run tool/generate_curated_data.dart
/// --check` vergleicht die erzeugte Datei mit der **PWA selbst**, nicht mit
/// einer Kopie unter `tool/`. Der Unterschied zu `tool/bake_map_style.dart`
/// ist beabsichtigt und dort begründet: dessen Ausgangsstil kommt aus dem
/// Netz, die PWA liegt lokal und versioniert. Bei dieser Datei ist das keine
/// Feinheit, ihr eigener Kopf sagt: „MANUAL fallback — wird später von
/// `04_Datenpipeline/scripts/compute_hotspots.py` automatisch
/// generiert/überschrieben." Genau dieser Lauf soll auffallen. Die erzeugte
/// Datei ist trotzdem **eingecheckt**, damit `flutter test` ohne Zugang zum
/// Lese-Repository durchläuft.
///
/// ## E-11, und warum der Stadtname hier nicht als roher Text durchgereicht
/// wird
///
/// Die kuratierten Dateien sind **nicht einheitlich verschlüsselt**.
/// `hunt-hotspots.js` und `hunt-routes.jsx` benutzen den deutschen
/// Anzeigenamen (`"München"`), `wallet-colors.jsx` benutzt Kleinschreibung mit
/// Umlauten (`münchen`, mit dem Kommentar „keys = lowercase, mit Umlauten, wie
/// `detectCity()` sie liefert"), und `facts.city` in der Datenbank trägt eine
/// dritte Schreibweise. **Drei Formen derselben Stadt, nicht zwei.**
///
/// E-11 ist offen und wird hier nicht gelöst. Aber der Zugriff ist so gebaut,
/// dass die Antwort **eine** Stelle kostet: [huntHotspotsForCity] nimmt eine
/// [FactCity] und keinen `String`, und der Vergleich läuft über
/// [FactCity.slug], also über dieselbe Normalisierung, die `public._slugify`
/// im Backend macht und die `FactQuery.citySlug` schon benutzt. Wer den
/// Stadtbegriff später zu einem `CityId` macht, ändert die Signatur dieser
/// einen Funktion; die erzeugte Tabelle bleibt, wie die Quelle sie schreibt.
library;

import 'package:fact_app/features/challenges/application/generated/hunt_hotspots.g.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/map/domain/map_position.dart';

/// Ein kuratierter Startpunkt.
class HuntHotspot {
  /// Erzeugt einen Hotspot.
  const HuntHotspot({
    required this.name,
    required this.position,
    required this.density,
  });

  /// Der angezeigte Name, `name` in der Quelle.
  ///
  /// **Ohne i18n-Schlüssel und ohne englische Fassung.** „Englischer Garten /
  /// Chinesischer Turm" steht so in der Datei und wird so angezeigt, auch im
  /// englischen Modus. Das ist Parität und keine vergessene Übersetzung;
  /// derselbe Fall wie `hunt-routes.jsx`, das für seine Routen wenigstens ein
  /// `nameEn` mitbringt.
  final String name;

  /// `lat` und `lng`.
  final MapPosition position;

  /// `density`, **roh** wie in der Quelle: `sehr hoch`, `hoch`, `mittel`.
  ///
  /// Bewusst kein Aufzählungstyp an dieser Stelle. Die Quelle bildet den Wert
  /// mit einer Kaskade mit Rückfall auf eine Beschriftung ab
  /// (`screen-challenge.jsx:3014-3018`), und genau dieser Rückfall ist die
  /// interessante Stelle: er greift für jeden Wert, den die Pipeline später
  /// schreibt und den niemand vorhergesehen hat. Die Abbildung steht deshalb
  /// in `hunt_start_options.dart` und ist dort geprüft, statt im Generator zu
  /// verschwinden.
  final String density;
}

/// Die Hotspots von [city], leer wenn die Quelle für sie keine kennt.
///
/// Die Quelle schreibt `(window.HUNT_HOTSPOTS || {})[city] || []`
/// (`screen-challenge.jsx:3003`), vergleicht also die Zeichenketten direkt.
/// Hier läuft der Vergleich über [FactCity.slug]; für die zehn Städte der
/// Datei ist das Ergebnis dasselbe, und für eine Stadt, die als `muenchen`
/// oder `münchen` hereinkommt, ist es das richtige statt eines leeren
/// Ergebnisses.
List<HuntHotspot> huntHotspotsForCity(FactCity city) =>
    _hotspotsBySlug[city.slug] ?? const <HuntHotspot>[];

/// Einmal umgeschlüsselt, damit nicht bei jedem Aufruf zehn Slugs entstehen.
///
/// Kollidierten zwei Anzeigenamen auf denselben Slug, verschwände einer
/// lautlos. `hunt_hotspot_test.dart` zählt deshalb nach, dass diese Karte
/// genauso viele Einträge hat wie die erzeugte.
final Map<String, List<HuntHotspot>> _hotspotsBySlug =
    <String, List<HuntHotspot>>{
      for (final MapEntry<String, List<HuntHotspotRecord>> entry
          in huntHotspotRecordsByCityName.entries)
        FactCity(entry.key).slug: <HuntHotspot>[
          for (final HuntHotspotRecord record in entry.value)
            HuntHotspot(
              name: record.name,
              position: MapPosition(
                latitude: record.latitude,
                longitude: record.longitude,
              ),
              density: record.density,
            ),
        ],
    };
