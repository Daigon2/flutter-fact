/// Symbol und Beschriftung eines Rätseltyps, wie die Kopfzeile des Sheets sie
/// auflöst.
///
/// Abschrift von `PSZ_TYPE_META` aus `02_Frontend/app/puzzle-sheet.jsx:36-48`,
/// Reihenfolge wie dort. Bauform und Kopfkommentar folgen
/// `features/facts/presentation/fact_category_look.dart`.
///
/// ## Der Rückfall ist der Normalfall, nicht die Ausnahme
///
/// `puzzle-sheet.jsx:67-68`:
///
/// ```js
/// const metaRaw = PSZ_TYPE_META[puzzle.type] || { icon: '❓', labelKey: null };
/// const meta = { icon: metaRaw.icon,
///                label: metaRaw.labelKey ? t(metaRaw.labelKey, lang) : puzzle.type };
/// ```
///
/// Die Beschriftung eines unbekannten Typs ist also **der rohe `type`-String**
/// und kein Ersatztext. Das sieht nach einem Notnagel aus und ist der häufige
/// Weg: in den Live-Daten stehen elf Werte in `type`, und sechs davon kennt
/// diese Tabelle nicht (`vor-ort` 761, `inschrift` 277, `mcq` 246,
/// `perspektive` 95, `zaehlen` 82, `sinne` 8, zusammen 1469; Beleg in
/// `features/facts/domain/entities/fact_puzzle.dart:90-93`). Wer hier einen
/// freundlicheren Ersatztext einsetzt, ändert das Verhalten für die Mehrheit
/// der Rätsel.
///
/// ## Warum die Tabelle in `presentation` liegt
///
/// Sie trägt Anzeigedaten: ein Emoji und einen i18n-Schlüssel. Die Form eines
/// Rätsels hängt nicht daran, die entscheidet der Übersetzer in
/// `puzzles/application/`. Ein Typ ohne Eintrag hier bleibt spielbar, er
/// bekommt nur ein Fragezeichen in die Kopfzeile.
///
/// Alle elf Schlüssel `puzzle.type.*` stehen in den erzeugten Sprachdateien,
/// `lib/app/localization/generated/app_strings_de.g.dart:637-647` und die
/// englische Schwester. Ein Test nagelt das fest, damit ein umbenannter
/// Schlüssel nicht als nackter Schlüsseltext auf dem Bildschirm landet, wie es
/// bei `audio.dialog.volumeHint` (E-28) passiert.
library;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:flutter/foundation.dart';

/// Wie ein Rätseltyp in der Kopfzeile aussieht.
@immutable
final class PuzzleTypeLook {
  /// Erzeugt einen Eintrag der Typtabelle.
  const PuzzleTypeLook({
    required this.type,
    required this.icon,
    required this.labelKey,
  });

  /// Der Wert, wie er in `puzzle_fit[].type` steht.
  final String type;

  /// Das Zeichen rechts in der Kopfzeile, `icon` in `PSZ_TYPE_META`.
  final String icon;

  /// Der i18n-Schlüssel der Beschriftung, `labelKey` in `PSZ_TYPE_META`.
  final String labelKey;

  @override
  bool operator ==(Object other) =>
      other is PuzzleTypeLook &&
      other.type == type &&
      other.icon == icon &&
      other.labelKey == labelKey;

  @override
  int get hashCode => Object.hash(type, icon, labelKey);

  @override
  String toString() => 'PuzzleTypeLook($type, $icon)';
}

/// Das Zeichen für einen Typ, den die Tabelle nicht kennt,
/// `puzzle-sheet.jsx:67`.
const String unknownPuzzleTypeIcon = '❓';

/// Die elf Einträge aus `puzzle-sheet.jsx:37-47`, Reihenfolge wie dort.
const List<PuzzleTypeLook> puzzleTypeLooks = <PuzzleTypeLook>[
  PuzzleTypeLook(
    type: 'detektiv-zaehlen',
    icon: '🔍',
    labelKey: 'puzzle.type.detektiv',
  ),
  PuzzleTypeLook(
    type: 'inschrift-decoder',
    icon: '📜',
    labelKey: 'puzzle.type.inschrift',
  ),
  PuzzleTypeLook(type: 'foto-beweis', icon: '📷', labelKey: 'puzzle.type.foto'),
  PuzzleTypeLook(
    type: 'local-fragen',
    icon: '💬',
    labelKey: 'puzzle.type.local',
  ),
  PuzzleTypeLook(
    type: 'perspektiven',
    icon: '👁',
    labelKey: 'puzzle.type.perspektive',
  ),
  PuzzleTypeLook(type: 'kombi', icon: '🧮', labelKey: 'puzzle.type.kombi'),
  PuzzleTypeLook(type: 'kompass', icon: '🧭', labelKey: 'puzzle.type.kompass'),
  PuzzleTypeLook(
    type: 'verstecktes-detail',
    icon: '🔎',
    labelKey: 'puzzle.type.detail',
  ),
  PuzzleTypeLook(
    type: 'klang-sinnes-check',
    icon: '👂',
    labelKey: 'puzzle.type.sinnes',
  ),
  PuzzleTypeLook(type: 'tap-counter', icon: '👆', labelKey: 'puzzle.type.tap'),
  PuzzleTypeLook(
    type: 'zeitreise',
    icon: '🕰',
    labelKey: 'puzzle.type.zeitreise',
  ),
];

/// Die Einträge nach ihrem Typ-Wert.
final Map<String, PuzzleTypeLook> puzzleTypeLooksByType =
    Map<String, PuzzleTypeLook>.unmodifiable(<String, PuzzleTypeLook>{
      for (final PuzzleTypeLook look in puzzleTypeLooks) look.type: look,
    });

/// Symbol und Beschriftung für [type], mit dem Rückfall der Quelle.
///
/// Genau `puzzle-sheet.jsx:67-68`, einschließlich der beiden Eigenheiten:
///
///  * Ein unbekannter Typ bekommt [unknownPuzzleTypeIcon] und **den rohen
///    Typ-String** als Beschriftung.
///  * Fehlt der Typ ganz, ist die Beschriftung **leer**. In JavaScript
///    liefert der Ausdruck dann `undefined`, und React zeichnet nichts. Ein
///    Ersatztext an dieser Stelle wäre erfunden; `FactPuzzle.type` ist
///    nullbar, der Fall kann also vorkommen.
///
/// Der Vergleich ist genau und nicht geglättet, wie bei `KAT_MAP` in der
/// Fakt-Akte: die Quelle greift mit dem Rohtext in ihr Objekt.
({String icon, String label}) puzzleTypeMetaOf(
  String? type,
  AppStrings strings,
) {
  final PuzzleTypeLook? look = type == null
      ? null
      : puzzleTypeLooksByType[type];
  if (look == null) {
    return (icon: unknownPuzzleTypeIcon, label: type ?? '');
  }
  return (icon: look.icon, label: strings.text(look.labelKey));
}
