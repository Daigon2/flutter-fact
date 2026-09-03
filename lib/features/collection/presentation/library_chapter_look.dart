/// Was die Kapitelliste zum Zeichnen braucht und was keine Daten sind:
/// die Farben eines Kapitels und seine römische Zahl.
///
/// ## Der Rückfall der Quelle ist toter Code, und diesmal harmlos
///
/// `screen-wallet.jsx:723` schreibt `t('cat.' + catKey, lang) || c.kategorie`.
/// Wie bei E-63 kann das `||` nie feuern: `window.t` gibt bei einem fehlenden
/// Schlüssel den **Schlüssel selbst** zurück, und der ist wahrheitswertig.
///
/// **Anders als bei E-63 und E-73 richtet das hier keinen Schaden an**, und
/// das ist nachgezählt: die sechs Schlüssel `cat.hist`, `cat.arch`,
/// `cat.myth`, `cat.fun`, `cat.geo` und `cat.heute` stehen alle in
/// `translations.jsx`, in beiden Sprachen. Der Rückfall wird nie gebraucht.
/// Deshalb steht `WalletCategoryRecord.category` hier auch nicht auf dem
/// Bildschirm; es bleibt in der erzeugten Tabelle als Abschrift der Quelle.
///
/// Es gibt **dreizehn** `cat.*`-Schlüssel, und der Reiseführer erreicht sechs
/// davon. `cat.kul`, `cat.pers` und `cat.chr` sind übersetzt und im
/// Reiseführer unerreichbar, weil `libraryCategoryKeyOf` diese Schlüssel nie
/// liefert. Das gehört zu E-78 und ist dort das Argument, das die Entscheidung
/// billiger macht: für drei der fünf zusammengefalteten Kategorien liegt der
/// Wortlaut schon vor. Für `kult` und `dark` nicht, siehe
/// `facts/presentation/fact_category_look.dart`, wo derselbe Befund Schritt 21
/// geprägt hat.
library;

import 'package:fact_app/features/collection/application/generated/wallet_categories.g.dart';
import 'package:flutter/painting.dart';

/// Die Farben eines Kapitels.
class LibraryChapterLook {
  /// Erzeugt eine Kapitelfassung.
  const LibraryChapterLook({
    required this.key,
    required this.glyph,
    required this.color,
    required this.darkColor,
  });

  /// Der Kapitelschlüssel, etwa `hist`.
  final String key;

  /// Das Zeichen der Quelle, etwa `§`.
  ///
  /// Die Kapitelliste zeigt es **nicht**: dort steht die römische Zahl
  /// (`screen-wallet.jsx:748`). Es ist übernommen, weil die Kapitelansicht aus
  /// Schritt 47 es in der Kopfzeile eines Kapitels braucht.
  final String glyph;

  /// Die Kategoriefarbe, `color` in der Quelle.
  final Color color;

  /// Die dunkle Schwester, `dk` in der Quelle.
  final Color darkColor;

  @override
  bool operator ==(Object other) =>
      other is LibraryChapterLook &&
      other.key == key &&
      other.glyph == glyph &&
      other.color == color &&
      other.darkColor == darkColor;

  @override
  int get hashCode => Object.hash(key, glyph, color, darkColor);
}

/// Die fünf Kapitel, die die Quelle nicht hat, mit Zeichen und Farbe
/// aus der **Kartentabelle** (`screen-map.jsx:195-208`).
///
/// **Warum von dort und nicht aus `WalletCats`:** dort stehen sie nicht.
/// Der Reiseführer der Quelle kennt nur sechs Kapitel, für die fünf neuen
/// gibt es also keine Reiseführer-Optik, die man abschreiben könnte. Die
/// Karte hat für alle zwölf Kategorien ein Emoji und zwei Farben, und das
/// ist die einzige vorhandene Vorlage. Übernommen ist sie unverändert;
/// erfunden ist nichts.
///
/// **Damit sehen die fünf anders aus als die sechs**, und das ist eine
/// sichtbare Folge der Entscheidung zu E-78: die sechs tragen die
/// Schriftzeichen des Reiseführers (`§`, `⌂`, `☾`), die fünf ein Emoji
/// (`🍺`, `👤`, `🎭`, `☠️`, `⛪`). Wer das vereinheitlichen will, braucht
/// fünf gestaltete Zeichen und damit eine Entscheidung, keine Codeänderung.
/// Die Kapitelliste zeigt ohnehin die römische Zahl und kein Zeichen.
const Map<String, LibraryChapterLook> libraryExtraChapterLooks =
    <String, LibraryChapterLook>{
      'kul': LibraryChapterLook(
        key: 'kul',
        glyph: '🍺',
        color: Color(0xFFF97316),
        darkColor: Color(0xFFC2410C),
      ),
      'pers': LibraryChapterLook(
        key: 'pers',
        glyph: '👤',
        color: Color(0xFFD946EF),
        darkColor: Color(0xFFA21CAF),
      ),
      'kult': LibraryChapterLook(
        key: 'kult',
        glyph: '🎭',
        color: Color(0xFFF59E0B),
        darkColor: Color(0xFFB45309),
      ),
      'dark': LibraryChapterLook(
        key: 'dark',
        glyph: '☠️',
        color: Color(0xFF64748B),
        darkColor: Color(0xFF1E293B),
      ),
      'kirche': LibraryChapterLook(
        key: 'kirche',
        glyph: '⛪',
        color: Color(0xFF818CF8),
        darkColor: Color(0xFF4338CA),
      ),
    };

/// Die Fassungen aller elf Kapitel, nach Schlüssel.
final Map<String, LibraryChapterLook> libraryChapterLooks =
    <String, LibraryChapterLook>{
      for (final WalletCategoryRecord record in walletCategoryRecords)
        record.key: LibraryChapterLook(
          key: record.key,
          glyph: record.glyph,
          color: _color(record.color),
          darkColor: _color(record.dark),
        ),
      ...libraryExtraChapterLooks,
    };

/// Die Fassung von [key].
///
/// Wirft nicht und gibt nichts Nullfähiges zurück: [key] kommt immer aus
/// `libraryCategoryKeyOf`, und das liefert ausschließlich einen der sechs. Ein
/// `assert` statt einer stillen Vorgabe, damit ein siebter Schlüssel im Test
/// auffällt und nicht als graue Karte durchrutscht.
LibraryChapterLook libraryChapterLookOf(String key) {
  final LibraryChapterLook? look = libraryChapterLooks[key];
  assert(look != null, 'Kein Kapitel mit dem Schlüssel "$key".');
  return look ?? libraryChapterLooks.values.first;
}

/// Die römische Zahl zu [number], `wltToRoman`
/// (`02_Frontend/app/screen-wallet.jsx:176-182`).
///
/// Wörtlich dieselbe Tabelle und dasselbe Verfahren. Sechs Kapitel brauchen
/// nur `I` bis `VI`, die vollständige Tabelle ist trotzdem übernommen: sie
/// steht so in der Quelle, und eine gekürzte Fassung wäre eine stille
/// Entscheidung darüber, dass es nie mehr Kapitel gibt.
///
/// Bei `number <= 0` kommt eine leere Zeichenkette heraus, genau wie in der
/// Quelle. Der Fall tritt nicht auf, weil die Zählung bei eins beginnt.
String libraryRomanNumeral(int number) {
  const List<(int, String)> table = <(int, String)>[
    (1000, 'M'),
    (900, 'CM'),
    (500, 'D'),
    (400, 'CD'),
    (100, 'C'),
    (90, 'XC'),
    (50, 'L'),
    (40, 'XL'),
    (10, 'X'),
    (9, 'IX'),
    (5, 'V'),
    (4, 'IV'),
    (1, 'I'),
  ];
  final StringBuffer result = StringBuffer();
  var rest = number;
  for (final (int value, String symbol) entry in table) {
    while (rest >= entry.$1) {
      result.write(entry.$2);
      rest -= entry.$1;
    }
  }
  return result.toString();
}

Color _color(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
