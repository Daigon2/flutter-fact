/// Die zwölf Fakt-Kategorien mit Emoji und Farbe, und die Tabelle, die die
/// Kategorietexte der Daten darauf abbildet.
///
/// ## Quelle
///
/// `02_Frontend/app/screen-map.jsx:195-208` (`CAT`), `:211-256` (`KAT_MAP`)
/// und
/// `:259-262` (`catStyle`). Vollständig übernommen, nichts erfunden und nichts
/// weggelassen.
///
/// ## Warum das hier liegt und nicht in `lib/map/`
///
/// Weil `lib/map/` nicht wissen darf, was eine Fakt-Kategorie ist (Regel 18).
/// Der Karten-Host bekommt fertige Bilder und eine Stil-Kennung als
/// Zeichenkette; welche es gibt, entscheidet dieses Feature.
///
/// ## Warum der Anzeigename fehlt
///
/// `CAT` trägt neben Emoji und Farbe ein `label`, also „Historisch",
/// „Mythos" und so weiter. Das ist **Oberflächentext** und gehört damit in den
/// i18n-Weg des Projekts und nicht in eine Stiltabelle; die Kategorien werden
/// in `_i18n` mitübersetzt (`02_Frontend/app/api.jsx:25`, siehe auch
/// `Fact.canonicalCategory`). Auf der Karte wird ohnehin keiner angezeigt: der
/// Ballon trägt nur das Emoji. Er kommt dazu, wenn der erste Bildschirm ihn
/// wirklich anzeigt, und dann über `AppStrings`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Emoji und Farben einer Kategorie.
@immutable
final class FactCategoryStyle {
  /// Erzeugt einen Kategoriestil.
  const FactCategoryStyle({
    required this.key,
    required this.emoji,
    required this.color,
    required this.darkColor,
  });

  /// Der kurze Schlüssel der Kategorie, etwa `hist`.
  ///
  /// Das ist der Schlüssel aus `CAT` und derselbe, den `KAT_MAP` liefert.
  final String key;

  /// Das Zeichen im Kopf des Ballons.
  final String emoji;

  /// Die Kategoriefarbe: Kopf, Stiel und Bodenschatten.
  final Color color;

  /// Die dunkle Schwester, `dk` in der Quelle.
  ///
  /// Sie zeichnet den harten Schatten unter dem Kopf
  /// (`box-shadow: 0 2px 0 {dk}`, `screen-map.jsx:1848`) und sonst nichts.
  final Color darkColor;

  @override
  bool operator ==(Object other) =>
      other is FactCategoryStyle &&
      other.key == key &&
      other.emoji == emoji &&
      other.color == color &&
      other.darkColor == darkColor;

  @override
  int get hashCode => Object.hash(key, emoji, color, darkColor);

  @override
  String toString() => 'FactCategoryStyle($key, $emoji)';
}

/// Der Schlüssel, auf den ein unbekannter Kategorietext fällt.
///
/// `catStyle` in `screen-map.jsx:260` schreibt `CAT[KAT_MAP[label]] || CAT.hist`.
/// Das ist **Parität und kein Fehler**: ein Fakt ohne erkennbare Kategorie
/// bekommt einen roten Ballon und verschwindet nicht. Gemeldet wird er
/// trotzdem, siehe `fact_overlay.dart`, denn eine neue Kategorie in den Daten
/// soll nicht stillschweigend rot werden.
const String fallbackFactCategoryKey = 'hist';

/// Die zwölf Kategorien, in der Reihenfolge der Quelle.
///
/// Eine Liste und keine Map, damit die Reihenfolge festliegt: die Bildfabrik
/// läuft darüber, und eine Map ohne feste Reihenfolge machte aus jedem Testlauf
/// eine andere Reihenfolge der erzeugten Bilder.
const List<FactCategoryStyle> factCategoryStyles = <FactCategoryStyle>[
  FactCategoryStyle(
    key: 'hist',
    emoji: '🏛',
    color: Color(0xFFE8380D),
    darkColor: Color(0xFFA82508),
  ),
  FactCategoryStyle(
    key: 'myth',
    emoji: '⚡',
    color: Color(0xFFA855F7),
    darkColor: Color(0xFF7C3AC0),
  ),
  FactCategoryStyle(
    key: 'fun',
    emoji: '😄',
    color: Color(0xFFF5C518),
    darkColor: Color(0xFFC49A0A),
  ),
  FactCategoryStyle(
    key: 'geo',
    emoji: '🗺',
    color: Color(0xFF00C2A8),
    darkColor: Color(0xFF007A6B),
  ),
  FactCategoryStyle(
    key: 'arch',
    emoji: '🗼',
    color: Color(0xFF3B82F6),
    darkColor: Color(0xFF1D4ED8),
  ),
  FactCategoryStyle(
    key: 'nat',
    emoji: '🌿',
    color: Color(0xFF22C55E),
    darkColor: Color(0xFF15803D),
  ),
  FactCategoryStyle(
    key: 'kul',
    emoji: '🍺',
    color: Color(0xFFF97316),
    darkColor: Color(0xFFC2410C),
  ),
  FactCategoryStyle(
    key: 'pers',
    emoji: '👤',
    color: Color(0xFFD946EF),
    darkColor: Color(0xFFA21CAF),
  ),
  FactCategoryStyle(
    key: 'kult',
    emoji: '🎭',
    color: Color(0xFFF59E0B),
    darkColor: Color(0xFFB45309),
  ),
  FactCategoryStyle(
    key: 'dark',
    emoji: '☠️',
    color: Color(0xFF64748B),
    darkColor: Color(0xFF1E293B),
  ),
  FactCategoryStyle(
    key: 'kirche',
    emoji: '⛪',
    color: Color(0xFF818CF8),
    darkColor: Color(0xFF4338CA),
  ),
  FactCategoryStyle(
    key: 'heute',
    emoji: '📸',
    color: Color(0xFFEC4899),
    darkColor: Color(0xFFBE185D),
  ),
];

/// Die Kategoriestile nach ihrem Schlüssel.
final Map<String, FactCategoryStyle> factCategoryStylesByKey =
    Map<String, FactCategoryStyle>.unmodifiable(<String, FactCategoryStyle>{
      for (final FactCategoryStyle style in factCategoryStyles)
        style.key: style,
    });

/// Die Kategorietexte der Daten, deutsch und englisch, auf ihren Schlüssel.
///
/// Wörtlich `KAT_MAP` aus `screen-map.jsx:211-256`, einschließlich der beiden
/// Einträge, die aus der Reihe fallen: `'Historical Figures'` zeigt auf `pers`
/// und nicht auf `hist`, und `'Dark History'` zeigt auf `dark`. Beides sieht
/// nach einem Tippfehler aus und ist keiner.
///
/// **Der Vergleich ist genau, nicht ungefähr.** Groß- und Kleinschreibung
/// zählen, Leerzeichen zählen, ein nachlaufendes Leerzeichen führt in den
/// Rückfall. Die Quelle greift ebenfalls direkt mit dem Rohtext in ihr Objekt
/// (`KAT_MAP[label]`); die Vergleiche zu lockern wäre eine Verhaltensänderung
/// und keine Verbesserung, denn sie würde in den Daten eine Sorgfalt
/// vortäuschen, die dort nicht steht.
const Map<String, String> factCategoryAliases = <String, String>{
  // Historisch
  'Historisch': 'hist',
  'Historical': 'hist',
  'Historical Figures': 'pers',
  // Architektur
  'Architektur': 'arch',
  'Architecture': 'arch',
  // Fun
  'Fun-Fact': 'fun',
  'Fun Fact': 'fun',
  // Geografie
  'Geografie': 'geo',
  'Geographie': 'geo',
  // Mythos
  'Mythos': 'myth',
  'Mythen': 'myth',
  'Myth & Legend': 'myth',
  // Natur
  'Natur': 'nat',
  'Nature': 'nat',
  // Kulinarik
  'Kulinarik': 'kul',
  'Kulinarisch': 'kul',
  'Food & Drink': 'kul',
  // Persönlichkeiten
  'Persönlichkeiten': 'pers',
  'Personalities': 'pers',
  // Kultur
  'Kultur': 'kult',
  'Kunst & Kultur': 'kult',
  'Art & Culture': 'kult',
  // Dunkel
  'Dunkel & Kriminell': 'dark',
  'Dark & Criminal': 'dark',
  'Dark History': 'dark',
  // Kirche
  'Kirche & Glaube': 'kirche',
  'Church & Faith': 'kirche',
  // Stadt heute (aktuelle Themen: Bauprojekte, Klima, Kurioses der Gegenwart)
  'Stadt heute': 'heute',
  'Stadt Heute': 'heute',
  'City Today': 'heute',
  'Today': 'heute',
  'Aktuell': 'heute',
};

/// Der Kategorieschlüssel zu einem Kategorietext, oder `null`.
///
/// **Bewusst ohne Rückfall.** `null` heißt „diesen Text kennt die Tabelle
/// nicht", und nur wer das sieht, kann es melden. Eine Funktion, die still
/// `hist` zurückgäbe, machte den Unterschied zwischen „ist historisch" und
/// „ist unbekannt" für jeden Aufrufer unsichtbar; genau das ist die Schwäche
/// von `catStyle` in der Quelle. Den Rückfall setzt `fact_overlay.dart`, und
/// dort wird er auch gemeldet.
String? factCategoryKeyOrNull(String category) => factCategoryAliases[category];
