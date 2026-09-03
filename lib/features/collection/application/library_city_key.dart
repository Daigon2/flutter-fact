/// Welchem Band des Reiseführers ein Fakt zufällt.
///
/// ## Hier wird bewusst nicht nachgebaut, was die Quelle tut
///
/// `wltCityKey` (`02_Frontend/app/screen-wallet.jsx:11-29`) fragt zuerst
/// `detectCity(lat, lng)` und nimmt `f.ort` nur, wenn das nichts liefert.
/// `detectCity` (`screen-map.jsx:342-350`) gibt die **nächstgelegene von zwölf
/// Städten zurück, ohne jede Entfernungsgrenze**:
///
/// ```js
/// function detectCity(lat, lng) {
///   let nearest = CITIES[0];
///   let minD = Infinity;
///   for (const c of CITIES) { const d = haversine(...); if (d < minD) { minD = d; nearest = c; } }
///   return nearest;
/// }
/// ```
///
/// Drei gemessene Folgen, alle am 03.09.2026 nachgelesen:
///
/// 1. **Jeder Fakt landet in einem Band, auch wenn er tausend Kilometer weit
///    weg liegt.** Ein Fakt in Berlin fällt an Weimar oder Göttingen, einer in
///    Paris an Heidelberg. Es gibt keinen Zustand „keine Stadt".
/// 2. **`f.ort` ist toter Code.** Sobald `lat` und `lng` Zahlen sind, liefert
///    `detectCity` immer ein Ergebnis, und der Rückfall wird nie erreicht. Für
///    Fakten ohne Koordinate greift er, aber die haben ohnehin keinen Platz auf
///    der Karte.
/// 3. **Bände und Stadt-Trophäen können sich widersprechen, und zwar
///    konstruktiv.** Die Trophäen `münchen_first` und ihre drei Geschwister
///    vergibt der Server aus `facts.city` mit dem `nr`-Präfix als Notnagel
///    (`handle_fact_collected`, `03_Backend/supabase-schema.sql:240-250`). Das
///    Regal gruppiert nach Luftlinie. Ein Fakt kann damit im Münchner Band
///    stehen, während die Trophäe einer anderen Stadt zugerechnet wurde.
///
/// Das ist ein gemessener Defekt und keine Vorlage, siehe `CLAUDE.md`,
/// Abschnitt „The PWA is a reference, not a gold standard". Registriert als
/// E-75, und es ist der **fünfte** Stadtschlüssel neben den vier aus E-56.
///
/// ## Was stattdessen gilt
///
/// Gruppiert wird nach [FactCity.slug], also nach der Spalte `facts.city` in
/// genau der Normalisierung, die `public._slugify` im Backend anwendet. Drei
/// Gründe:
///
/// * Die Spalte ist das gepflegte Datum, die Luftlinie eine Schätzung.
/// * Der Server rechnet die Stadt-Trophäen aus derselben Spalte. Damit sagen
///   Regal und Trophäe dasselbe, statt sich zu widersprechen.
/// * Es entsteht **keine neue Normalisierung**. `FactCity.slug` liegt seit
///   Schritt 4 im Repository und ist Wort für Wort `_slugify`. Eine sechste
///   Variante wäre genau der Fehler, den E-56 beschreibt.
///
/// **Ein Fakt ohne Stadt steht in keinem Band.** Die Quelle tut an dieser
/// Stelle dasselbe (`wltGroupCityFacts`: `if (!k) continue`), nur aus einem
/// anderen Grund: bei ihr kann der Fall praktisch nicht auftreten. Der
/// `nr`-Präfix-Notnagel des Servers wird hier **nicht** nachgebaut. Er braucht
/// eine Präfix-Tabelle, und genau die ist der bestrittene Teil von E-56: der
/// Trigger bildet `ROM%` auf `Rom` ab, der Backfill vom 07.06.2026 dasselbe
/// Präfix auf `Rome`. Eine sechste Abschrift davon anzulegen, um ein paar
/// Fakten auf ein Regal zu bekommen, wäre der falsche Preis.
///
/// ## Mehrstadt-Verhalten
///
/// Nichts hier kennt München. Der Schlüssel entsteht aus dem Datensatz, und
/// jede Stadt, die Fakten hat, bekommt einen Band. Die Palette aus
/// `wallet_cities.g.dart` deckt fünf davon ab; alle anderen erhalten die
/// Vorgabe-Ausstattung, genau wie in der Quelle.
library;

import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';

/// Zweitschreibungen, die auf denselben Band gehören.
///
/// Beide stehen so in `wltCityKey` (`screen-wallet.jsx:23-27`), das dort
/// `s.includes('münchen') || s.includes('munich')` und
/// `s.includes('rom') || s.includes('rome')` prüft. Die englischen Formen sind
/// nicht theoretisch: die Migration
/// `2026-06-07_city_backfill_and_slug_match.sql` hat `ROM`-Fakten auf `Rome`
/// gesetzt, während der Trigger `Rom` schreibt, und beide Werte stehen heute in
/// der Spalte. Siehe E-56.
///
/// Die Schlüssel sind Slugs, nicht Anzeigenamen: `slug('Munich')` ist `munich`,
/// `slug('München')` ist `muenchen`.
const Map<String, String> libraryCityKeyAliases = <String, String>{
  'munich': 'muenchen',
  'rome': 'rom',
};

/// Der Bandschlüssel für einen Anzeigenamen.
///
/// Getrennt von [libraryCityKeyOf], weil auch die Palette über ihn läuft: die
/// erzeugte Tabelle trägt Quellschlüssel wie `münchen`, und die müssen auf
/// dieselbe Form kommen wie ein Fakt, sonst findet die Suche nichts.
String libraryCityKeyOfName(String name) {
  final String slug = FactCity(name).slug;
  return libraryCityKeyAliases[slug] ?? slug;
}

/// Der Bandschlüssel von [fact], oder `null`, wenn der Fakt keine Stadt trägt.
///
/// `null` und nicht die leere Zeichenkette: ein leerer Schlüssel wäre ein
/// gültiger Kartenschlüssel und hätte ein Band ohne Namen erzeugt. Ein
/// Anzeigename, der nur aus Ziffern oder Satzzeichen besteht, ergibt nach
/// `_slugify` ebenfalls nichts und fällt deshalb genauso heraus.
String? libraryCityKeyOf(Fact fact) {
  final FactCity? city = fact.city;
  if (city == null) {
    return null;
  }
  final String key = libraryCityKeyOfName(city.displayName);
  return key.isEmpty ? null : key;
}
