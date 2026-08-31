import 'package:fact_app/features/progression/domain/value_objects/trophy_tier.dart';
import 'package:flutter/painting.dart';

/// Die drei Stufenfarben, `screen-profil.jsx:218` (`tierC`).
///
/// Sie liegen in `presentation` und nicht bei [TrophyTier] selbst: eine Farbe
/// ist `Color` aus `dart:ui`, und die Domäne darf kein Flutter importieren
/// (Regel 1). Dieselbe Trennung wie bei `FactCategoryLook` gegenüber der
/// rohen Kategorie-Zeichenkette.
///
/// **Bewusst keine Wiederverwendung von `FactColors.gold`,** obwohl der Wert
/// zufällig übereinstimmt (`#F5C518` in beiden). Silber und Bronze haben
/// **keine** Entsprechung im Farb-Token-Satz der App, und derselbe
/// Bildschirm führt für Rangabzeichen einen **anderen** Silberton
/// (`rnkRankColor`, `:26-31`: `#A8A8A8`, nicht `#B0BEC5`). Zwei Silberwerte in
/// derselben Quelle für zwei verschiedene Zwecke; sie hier zusammenzulegen
/// wäre ein Fehler, keine Vereinfachung.
const Map<TrophyTier, Color> trophyTierColors = <TrophyTier, Color>{
  TrophyTier.gold: Color(0xFFF5C518),
  TrophyTier.silver: Color(0xFFB0BEC5),
  TrophyTier.bronze: Color(0xFFCD7F32),
};
