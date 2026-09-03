/// Das Bücherregal des Reiseführers als Lesemodell,
/// `02_Frontend/app/screen-wallet.jsx:1826-1832` und `:958-1012`.
///
/// Reine Funktion über Fakten und Sammelzustand. Kein Riverpod, keine Karte,
/// kein Flutter: was auf dem Regal steht, ist eine Frage an die Daten und
/// keine an die Oberfläche.
library;

import 'package:fact_app/features/collection/application/generated/wallet_cities.g.dart';
import 'package:fact_app/features/collection/application/library_city_key.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';

/// Ein Band auf dem Regal, also eine Stadt mit Fakten.
final class LibraryVolume {
  /// Erzeugt einen Band.
  const LibraryVolume({
    required this.cityKey,
    required this.name,
    required this.palette,
    required this.hasOwnPalette,
    required this.collected,
    required this.total,
  });

  /// Der Bandschlüssel, siehe [libraryCityKeyOf].
  final String cityKey;

  /// Der Name auf dem Buchrücken.
  ///
  /// ## Hier steht bewusst nicht, was die Quelle zeigt
  ///
  /// `wltCity` (`screen-wallet.jsx:197-201`) setzt für eine Stadt ohne Palette
  /// `cityKey.charAt(0).toUpperCase() + cityKey.slice(1)`, also den
  /// kleingeschriebenen Schlüssel mit großem Anfangsbuchstaben. Bei der Quelle
  /// trägt der Schlüssel echte Umlaute (`nürnberg`), dort kommt `Nürnberg`
  /// heraus.
  ///
  /// Unser Schlüssel ist ein Slug nach `_slugify`, und der schreibt `ü` zu
  /// `ue` um. Dieselbe Regel ergäbe `Nuernberg`, und eine
  /// Ersatzschreibung in einem Lesetext ist kein Verhalten, das man nachbaut.
  /// Genommen wird deshalb der **Anzeigename aus der Spalte** `facts.city`,
  /// unverändert. Der ist genauer als jede Rückrechnung aus dem Schlüssel und
  /// steht ohnehin am Datensatz.
  ///
  /// Wo eine Palette existiert, gewinnt deren `name`: die Quelle schreibt
  /// `München` und nicht `Muenchen`, und für die fünf Städte ist der Name
  /// redaktionell gesetzt.
  final String name;

  /// Die Ausstattung des Bandes, [walletCityDefault] wenn die Stadt keine
  /// eigene hat.
  final WalletCityRecord palette;

  /// Ob [palette] der Stadt gehört oder die Vorgabe ist.
  ///
  /// Als eigenes Feld und nicht über einen Vergleich mit [walletCityDefault]:
  /// eine Stadt könnte theoretisch dieselben Farben tragen, und dann wäre der
  /// Vergleich falsch. Die Oberfläche braucht die Auskunft für die Bandnummer.
  final bool hasOwnPalette;

  /// Wie viele Fakten dieser Stadt gesammelt sind.
  final int collected;

  /// Wie viele Fakten diese Stadt überhaupt hat.
  ///
  /// Immer mindestens eins: ein Band entsteht nur, wenn die Stadt Fakten hat
  /// (`screen-wallet.jsx:1831`, `.filter(k => (cityFactsMap[k] || []).length > 0)`).
  final int total;

  /// Die Bandnummer, oder `null`, wenn die Stadt keine trägt.
  ///
  /// `0` heißt „keine", nicht „Band null": die Quelle prüft
  /// `city.bandNo || (…)` und behandelt `0` deshalb als unwahr, siehe
  /// [walletCityDefault].
  int? get bandNumber => palette.bandNo > 0 ? palette.bandNo : null;

  @override
  bool operator ==(Object other) =>
      other is LibraryVolume &&
      other.cityKey == cityKey &&
      other.name == name &&
      other.palette == palette &&
      other.hasOwnPalette == hasOwnPalette &&
      other.collected == collected &&
      other.total == total;

  @override
  int get hashCode =>
      Object.hash(cityKey, name, palette, hasOwnPalette, collected, total);

  @override
  String toString() => 'LibraryVolume($cityKey, $collected/$total)';
}

/// Die Paletten aus der erzeugten Tabelle, nach Bandschlüssel.
///
/// Die Tabelle trägt Quellschlüssel mit Umlaut (`münchen`), ein Fakt bringt
/// einen Slug (`muenchen`). Beide Seiten laufen deshalb durch
/// [libraryCityKeyOfName], und genau dafür ist die Funktion getrennt.
final Map<String, WalletCityRecord> walletCityPalettes =
    <String, WalletCityRecord>{
      for (final WalletCityRecord record in walletCityRecords)
        libraryCityKeyOfName(record.key): record,
    };

/// Die Regalfolge aus der Quelle, auf Bandschlüssel gebracht.
final List<String> libraryCityOrder = <String>[
  for (final String key in walletCityOrder) libraryCityKeyOfName(key),
];

/// Baut das Regal aus [facts] und den Kennungen in [collected].
///
/// ## Reihenfolge
///
/// Erst die Städte aus [libraryCityOrder], in dieser Folge, dann alle
/// übrigen. Die Quelle macht dasselbe (`screen-wallet.jsx:1823-1832`) und
/// hängt die Übrigen in `Object.keys`-Folge an, also in der Reihenfolge, in
/// der sie zum ersten Mal in den Faktdaten vorkommen. Genau das tut auch
/// diese Funktion; eine alphabetische Sortierung wäre schöner und wäre eine
/// andere Reihenfolge als die der Quelle.
///
/// ## Ein Fakt ohne Stadt fällt heraus
///
/// Siehe [libraryCityKeyOf]. Er zählt dann in **keinem** `total`, und das
/// ist beabsichtigt: ein Band „ohne Stadt" gibt es nicht, und ihn irgendwo
/// mitzuzählen hieße, eine Stadt zu erfinden. Der Server tut an dieser Stelle
/// das Gegenteil und bucht auf den Schlüssel `unknown`, was zwei Trophäen zu
/// früh erreichbar macht; das ist E-66 und wird hier nicht nachgebaut.
List<LibraryVolume> libraryShelfOf({
  required Iterable<Fact> facts,
  required Set<int> collected,
}) {
  final Map<String, String> displayNames = <String, String>{};
  final Map<String, int> totals = <String, int>{};
  final Map<String, int> collectedCounts = <String, int>{};

  for (final Fact fact in facts) {
    final String? key = libraryCityKeyOf(fact);
    if (key == null) {
      continue;
    }
    displayNames.putIfAbsent(key, () => fact.city!.displayName);
    totals[key] = (totals[key] ?? 0) + 1;
    if (collected.contains(fact.id.value)) {
      collectedCounts[key] = (collectedCounts[key] ?? 0) + 1;
    }
  }

  final List<String> ordered = <String>[
    ...libraryCityOrder.where(totals.containsKey),
    ...totals.keys.where((String key) => !libraryCityOrder.contains(key)),
  ];

  return <LibraryVolume>[
    for (final String key in ordered)
      LibraryVolume(
        cityKey: key,
        name: walletCityPalettes[key]?.name ?? displayNames[key]!,
        palette: walletCityPalettes[key] ?? walletCityDefault,
        hasOwnPalette: walletCityPalettes.containsKey(key),
        collected: collectedCounts[key] ?? 0,
        total: totals[key]!,
      ),
  ];
}
