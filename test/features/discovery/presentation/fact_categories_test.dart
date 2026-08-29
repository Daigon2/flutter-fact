import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Kategorientabelle gegen ihre Quelle.
///
/// **Jede der zwölf Kategorien wird einzeln geprüft, und das ist Absicht.** Ein
/// Test, der nur `factCategoryStyles.length` zählt, ist grün, wenn zwei Farben
/// vertauscht sind; einer, der über die Liste läuft und sie mit sich selbst
/// vergleicht, ist immer grün. Hier stehen die Werte deshalb ausgeschrieben,
/// abgetippt aus `02_Frontend/app/screen-map.jsx:195-208`. Diese Datei ist
/// bewusst langweilig: sie ist eine zweite Abschrift derselben Tabelle, und
/// genau dadurch fällt ein Tippfehler in der ersten auf.
void main() {
  FactCategoryStyle styleOf(String key) {
    final FactCategoryStyle? style = factCategoryStylesByKey[key];
    expect(style, isNotNull, reason: 'Kategorie $key fehlt');
    return style!;
  }

  void expectCategory(String key, String emoji, int color, int darkColor) {
    final FactCategoryStyle style = styleOf(key);
    expect(style.emoji, emoji, reason: 'Emoji von $key');
    expect(style.color, Color(color), reason: 'Farbe von $key');
    expect(style.darkColor, Color(darkColor), reason: 'Dunkelfarbe von $key');
  }

  group('CAT', () {
    test('es sind genau zwölf, ohne doppelten Schlüssel', () {
      expect(factCategoryStyles, hasLength(12));
      expect(factCategoryStylesByKey, hasLength(12));
    });

    test('hist ist rot mit dem Tempel', () {
      expectCategory('hist', '🏛', 0xFFE8380D, 0xFFA82508);
    });

    test('myth ist violett mit dem Blitz', () {
      expectCategory('myth', '⚡', 0xFFA855F7, 0xFF7C3AC0);
    });

    test('fun ist gelb mit dem Lachen', () {
      expectCategory('fun', '😄', 0xFFF5C518, 0xFFC49A0A);
    });

    test('geo ist türkis mit der Landkarte', () {
      expectCategory('geo', '🗺', 0xFF00C2A8, 0xFF007A6B);
    });

    test('arch ist blau mit dem Turm', () {
      expectCategory('arch', '🗼', 0xFF3B82F6, 0xFF1D4ED8);
    });

    test('nat ist grün mit dem Zweig', () {
      expectCategory('nat', '🌿', 0xFF22C55E, 0xFF15803D);
    });

    test('kul ist orange mit dem Bier', () {
      expectCategory('kul', '🍺', 0xFFF97316, 0xFFC2410C);
    });

    test('pers ist magenta mit der Silhouette', () {
      expectCategory('pers', '👤', 0xFFD946EF, 0xFFA21CAF);
    });

    test('kult ist bernstein mit den Masken', () {
      expectCategory('kult', '🎭', 0xFFF59E0B, 0xFFB45309);
    });

    test('dark ist schiefergrau mit dem Totenkopf', () {
      expectCategory('dark', '☠️', 0xFF64748B, 0xFF1E293B);
    });

    test('kirche ist indigo mit der Kirche', () {
      expectCategory('kirche', '⛪', 0xFF818CF8, 0xFF4338CA);
    });

    test('heute ist pink mit der Kamera', () {
      expectCategory('heute', '📸', 0xFFEC4899, 0xFFBE185D);
    });
  });

  group('KAT_MAP', () {
    test('es sind genau 32 Einträge, wie in der Quelle', () {
      // **Ohne diese Zeile überlebt ein zusätzlicher, erfundener Eintrag.**
      // Die beiden Richtungsprüfungen unten decken fehlende Einträge
      // vollständig ab: jeder Text zeigt auf eine Kategorie, jede Kategorie ist
      // erreichbar. Einer zu viel fällt keiner von beiden auf, und er wäre eine
      // stille Paritätsabweichung, denn `KAT_MAP[label]` in der Quelle kennt
      // ihn nicht.
      //
      // 32 ist nachgezählt in `screen-map.jsx:211-256` und nicht geschätzt.
      expect(factCategoryAliases, hasLength(32));
    });

    test('die deutschen Schreibweisen treffen ihre Kategorie', () {
      expect(factCategoryKeyOrNull('Historisch'), 'hist');
      expect(factCategoryKeyOrNull('Architektur'), 'arch');
      expect(factCategoryKeyOrNull('Fun-Fact'), 'fun');
      expect(factCategoryKeyOrNull('Geografie'), 'geo');
      expect(factCategoryKeyOrNull('Geographie'), 'geo');
      expect(factCategoryKeyOrNull('Mythos'), 'myth');
      expect(factCategoryKeyOrNull('Mythen'), 'myth');
      expect(factCategoryKeyOrNull('Natur'), 'nat');
      expect(factCategoryKeyOrNull('Kulinarik'), 'kul');
      expect(factCategoryKeyOrNull('Kulinarisch'), 'kul');
      expect(factCategoryKeyOrNull('Persönlichkeiten'), 'pers');
      expect(factCategoryKeyOrNull('Kultur'), 'kult');
      expect(factCategoryKeyOrNull('Kunst & Kultur'), 'kult');
      expect(factCategoryKeyOrNull('Dunkel & Kriminell'), 'dark');
      expect(factCategoryKeyOrNull('Kirche & Glaube'), 'kirche');
      expect(factCategoryKeyOrNull('Stadt heute'), 'heute');
      expect(factCategoryKeyOrNull('Stadt Heute'), 'heute');
      expect(factCategoryKeyOrNull('Aktuell'), 'heute');
    });

    test('die englischen Schreibweisen ebenso', () {
      expect(factCategoryKeyOrNull('Historical'), 'hist');
      expect(factCategoryKeyOrNull('Architecture'), 'arch');
      expect(factCategoryKeyOrNull('Fun Fact'), 'fun');
      expect(factCategoryKeyOrNull('Myth & Legend'), 'myth');
      expect(factCategoryKeyOrNull('Nature'), 'nat');
      expect(factCategoryKeyOrNull('Food & Drink'), 'kul');
      expect(factCategoryKeyOrNull('Personalities'), 'pers');
      expect(factCategoryKeyOrNull('Art & Culture'), 'kult');
      expect(factCategoryKeyOrNull('Dark & Criminal'), 'dark');
      expect(factCategoryKeyOrNull('Church & Faith'), 'kirche');
      expect(factCategoryKeyOrNull('City Today'), 'heute');
      expect(factCategoryKeyOrNull('Today'), 'heute');
    });

    test('die beiden Einträge, die aus der Reihe fallen', () {
      // Sie sehen nach Tippfehlern aus und sind keine: `screen-map.jsx:215`
      // und `:246`. Wer die Tabelle „aufräumt", bricht die Parität.
      expect(factCategoryKeyOrNull('Historical Figures'), 'pers');
      expect(factCategoryKeyOrNull('Dark History'), 'dark');
    });

    test('jeder Eintrag zeigt auf eine Kategorie, die es gibt', () {
      for (final MapEntry<String, String> entry
          in factCategoryAliases.entries) {
        expect(
          factCategoryStylesByKey.containsKey(entry.value),
          isTrue,
          reason: '${entry.key} zeigt auf ${entry.value}, das es nicht gibt',
        );
      }
    });

    test('jede Kategorie ist über mindestens einen Text erreichbar', () {
      // Die Gegenrichtung. Ohne sie könnte eine Kategorie in der Tabelle
      // stehen und trotzdem nie vorkommen.
      final Set<String> reachable = factCategoryAliases.values.toSet();
      for (final FactCategoryStyle style in factCategoryStyles) {
        expect(
          reachable,
          contains(style.key),
          reason: '${style.key} ist über keinen Kategorietext erreichbar',
        );
      }
    });

    test('unbekannt heißt null und nicht hist', () {
      // Der Rückfall gehört dem Aufrufer, nicht dieser Funktion: nur wer
      // `null` sieht, kann es melden.
      expect(factCategoryKeyOrNull('Raumfahrt'), isNull);
      expect(factCategoryKeyOrNull(''), isNull);
    });

    test('der Vergleich ist genau, wie in der Quelle', () {
      // `KAT_MAP[label]` greift mit dem Rohtext. Kleinschreibung und ein
      // nachlaufendes Leerzeichen führen dort ebenso in den Rückfall.
      expect(factCategoryKeyOrNull('historisch'), isNull);
      expect(factCategoryKeyOrNull('Historisch '), isNull);
    });

    test('der Rückfall ist hist', () {
      expect(fallbackFactCategoryKey, 'hist');
      expect(factCategoryStylesByKey, contains(fallbackFactCategoryKey));
    });
  });
}
