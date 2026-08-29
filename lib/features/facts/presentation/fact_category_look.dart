/// Emoji und Farbe der Kategorie, wie die **Akte** sie auflöst.
///
/// ## Warum es diese Tabelle ein zweites Mal gibt
///
/// `features/discovery/presentation/fact_categories.dart` trägt dieselben
/// Werte für die Ballons. Sie von hier zu lesen ist verboten: Regel 8 der
/// `dependency-rules.md` lässt niemanden außerhalb von `discovery` in dessen
/// `presentation/`. Der naheliegende gemeinsame Ort, `application/`, scheidet
/// ebenfalls aus, und zwar gemessen: `tool/check_architecture.dart:203` verbietet
/// dort `^package:flutter/`, und ohne `Color` ist eine Farbtabelle keine.
/// `core` ist durch Regel 11 gesperrt, Fakt-Kategorien sind ein Fakt-Begriff.
///
/// Die Doppelung ist deshalb kein Versehen. Damit sie nicht auseinanderläuft,
/// nagelt `test/features/facts/presentation/fact_category_look_test.dart` beide
/// Tabellen gegeneinander fest; die Werte hier sind unabhängig aus
/// `02_Frontend/app/screen-map.jsx:195-208` abgeschrieben.
///
/// ## Warum nur acht Kategorien und nicht zwölf
///
/// Weil die Akte in der Quelle eine **eigene, kleinere** Zuordnungstabelle hat
/// (`screen-fact.jsx:245-249`) als die Karte (`KAT_MAP`,
/// `screen-map.jsx:211-256`). Sie kennt `pers`, `kult`, `dark` und `kirche`
/// nicht, ein solcher Fakt fällt hier also auf `hist` zurück, während sein
/// Ballon auf der Karte richtig eingefärbt ist.
///
/// **Das sieht nach einem Fehler aus und ist der einzige gangbare Weg.** Der
/// Anzeigename kommt aus `t('cat.' + catKey)` (`screen-fact.jsx:365`), und für
/// `kult`, `dark` und `kirche` **gibt es keinen i18n-Schlüssel**: die erzeugten
/// Tabellen führen `cat.hist`, `cat.myth`, `cat.fun`, `cat.geo`, `cat.heute`,
/// `cat.arch`, `cat.nat`, `cat.kul`, `cat.mod`, `cat.sci`, `cat.spt`,
/// `cat.chr` und `cat.pers`. Wer hier die große Tabelle einsetzt, bekommt für
/// drei Kategorien den nackten Schlüssel als Beschriftung zu sehen, denselben
/// Fehler wie `audio.dialog.volumeHint` (E-28). Die kleine Tabelle erreicht
/// ausschließlich Schlüssel, die es gibt.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Wie eine Kategorie in der Akte aussieht.
@immutable
final class FactCategoryLook {
  /// Erzeugt eine Kategoriefassung.
  const FactCategoryLook({
    required this.key,
    required this.emoji,
    required this.color,
    required this.darkColor,
  });

  /// Der kurze Schlüssel, etwa `hist`. Zugleich der Stamm des i18n-Schlüssels
  /// `cat.<key>`.
  final String key;

  /// Das Zeichen im Kategorie-Chip, `emoji` in `CAT`.
  final String emoji;

  /// Die Kategoriefarbe, `color` in `CAT`.
  final Color color;

  /// Die dunkle Schwester, `dk` in `CAT`. Trägt allein den harten Schatten
  /// unter dem Chip-Quadrat (`screen-fact.jsx:362`).
  final Color darkColor;

  @override
  bool operator ==(Object other) =>
      other is FactCategoryLook &&
      other.key == key &&
      other.emoji == emoji &&
      other.color == color &&
      other.darkColor == darkColor;

  @override
  int get hashCode => Object.hash(key, emoji, color, darkColor);

  @override
  String toString() => 'FactCategoryLook($key, $emoji)';
}

/// Der Schlüssel, auf den ein unbekannter Kategorietext fällt.
///
/// `screen-fact.jsx:249-250`: `[...][fact.kategorie] || 'hist'`, und der
/// Ersatzwert daneben ist buchstäblich `CAT.hist`.
const String fallbackFactCategoryLookKey = 'hist';

/// Die acht Kategorien, die die Akte erreichen kann.
///
/// Werte aus `screen-map.jsx:196-207`, Reihenfolge wie dort. Die vier
/// übersprungenen (`pers`, `kult`, `dark`, `kirche`) fehlen absichtlich, siehe
/// den Kopf dieser Datei.
const List<FactCategoryLook> factCategoryLooks = <FactCategoryLook>[
  FactCategoryLook(
    key: 'hist',
    emoji: '🏛',
    color: Color(0xFFE8380D),
    darkColor: Color(0xFFA82508),
  ),
  FactCategoryLook(
    key: 'myth',
    emoji: '⚡',
    color: Color(0xFFA855F7),
    darkColor: Color(0xFF7C3AC0),
  ),
  FactCategoryLook(
    key: 'fun',
    emoji: '😄',
    color: Color(0xFFF5C518),
    darkColor: Color(0xFFC49A0A),
  ),
  FactCategoryLook(
    key: 'geo',
    emoji: '🗺',
    color: Color(0xFF00C2A8),
    darkColor: Color(0xFF007A6B),
  ),
  FactCategoryLook(
    key: 'arch',
    emoji: '🗼',
    color: Color(0xFF3B82F6),
    darkColor: Color(0xFF1D4ED8),
  ),
  FactCategoryLook(
    key: 'nat',
    emoji: '🌿',
    color: Color(0xFF22C55E),
    darkColor: Color(0xFF15803D),
  ),
  FactCategoryLook(
    key: 'kul',
    emoji: '🍺',
    color: Color(0xFFF97316),
    darkColor: Color(0xFFC2410C),
  ),
  FactCategoryLook(
    key: 'heute',
    emoji: '📸',
    color: Color(0xFFEC4899),
    darkColor: Color(0xFFBE185D),
  ),
];

/// Die Kategoriefassungen nach ihrem Schlüssel.
final Map<String, FactCategoryLook> factCategoryLooksByKey =
    Map<String, FactCategoryLook>.unmodifiable(<String, FactCategoryLook>{
      for (final FactCategoryLook look in factCategoryLooks) look.key: look,
    });

/// Die Zuordnungstabelle der Akte, wörtlich `screen-fact.jsx:245-249`.
///
/// Neun Einträge auf acht Schlüssel: `Geographie` und `Geografie` zeigen beide
/// auf `geo`. Der Vergleich ist genau, nicht ungefähr, aus demselben Grund wie
/// bei `KAT_MAP`: die Quelle greift mit dem Rohtext in ihr Objekt.
const Map<String, String> factCategoryLookAliases = <String, String>{
  'Historisch': 'hist',
  'Architektur': 'arch',
  'Fun-Fact': 'fun',
  'Geographie': 'geo',
  'Geografie': 'geo',
  'Mythos': 'myth',
  'Natur': 'nat',
  'Kulinarik': 'kul',
  'Stadt heute': 'heute',
};

/// Die Kategoriefassung zu einem Kategorietext, mit Rückfall auf `hist`.
///
/// Anders als `factCategoryKeyOrNull` in `discovery` **mit** Rückfall: dort
/// wird ein unbekannter Text gemeldet, weil eine neue Kategorie in den Daten
/// nicht stumm rot werden soll. Hier ist der Rückfall nicht die Ausnahme,
/// sondern der Normalfall für vier bekannte Kategorien, und eine Meldung je
/// geöffneter Akte wäre Lärm ohne Erkenntnis.
FactCategoryLook factCategoryLookOf(String category) =>
    factCategoryLooksByKey[factCategoryLookAliases[category]] ??
    factCategoryLooksByKey[fallbackFactCategoryLookKey]!;
