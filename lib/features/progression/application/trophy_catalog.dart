import 'package:fact_app/features/progression/application/generated/wallet_trophies.g.dart';
import 'package:fact_app/features/progression/domain/entities/trophy.dart';

/// Übersetzt die erzeugten Rohdaten in den Domänenvertrag [Trophy].
///
/// Dieselbe Aufgabenteilung wie `puzzles/application/puzzle_from_fact_puzzle.dart`:
/// `application` kennt die generierte Datei, `domain` kennt sie nicht.

/// Die 36 Trophäen als Domänenentitäten, Reihenfolge wie in
/// `wallet-colors.jsx: window.WalletTrophies`.
final List<Trophy> trophyCatalog = <Trophy>[
  for (final WalletTrophyRecord record in walletTrophyRecords)
    Trophy(
      key: record.key,
      category: record.category,
      threshold: record.threshold,
      glyph: record.glyph,
      labelDe: record.labelDe,
      labelEn: record.labelEn,
      descDe: record.descDe,
      descEn: record.descEn,
    ),
];

/// Trophäen in Anzeigereihenfolge, `screen-profil.jsx:216`: offene zuerst,
/// gesperrte danach, innerhalb jeder Gruppe in Definitionsreihenfolge. Der
/// Kommentar der Quelle sagt selbst, warum es nicht feiner sortiert: eine
/// Sortierung nach Freischaltzeitpunkt bräuchte Zeitstempel, die es nicht
/// gibt.
///
/// **Bewusst keine In-Place-Sortierung.** Die Quelle schreibt
/// `mapped.sort((a, b) => Number(a.locked) - Number(b.locked))`, und
/// `Array.prototype.sort` ist seit ES2019 stabil. Darts `List.sort` ist es
/// **nicht** (Introsort): ein `sort()` über denselben Vergleich könnte zwei
/// gesperrte Trophäen gegeneinander vertauschen, ohne dass ein Test es sähe,
/// solange beide gesperrt blieben. Die Aufteilung in zwei Listen unten ist
/// stabil, weil beide Teillisten in der Iterationsreihenfolge von
/// [trophyCatalog] befüllt werden.
List<Trophy> trophiesInDisplayOrder({required Set<String> unlockedKeys}) {
  final List<Trophy> unlocked = <Trophy>[];
  final List<Trophy> locked = <Trophy>[];
  for (final Trophy trophy in trophyCatalog) {
    (unlockedKeys.contains(trophy.key) ? unlocked : locked).add(trophy);
  }
  return <Trophy>[...unlocked, ...locked];
}
