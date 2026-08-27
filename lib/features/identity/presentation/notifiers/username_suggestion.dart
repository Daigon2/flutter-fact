/// Der Vorschlag für einen Username, `screen-auth.jsx:585-590`
/// (`rnkSuggestUsername`).
///
/// Aus einem zufälligen Wort der Liste, dem festen Mittelteil `fuchs_` und dem
/// ersten Buchstaben der Stadt in Kleinschreibung: `goldfuchs_m`.
library;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die Wortliste der Quelle, **hartcodiert deutsch**.
///
/// Es gibt dafür keinen i18n-Schlüssel, und dieser Schritt legt keinen an. Auf
/// Englisch entstehen deshalb dieselben deutschen Vorschläge, genau wie in der
/// PWA. Ein Test sichert das zu, damit niemand die Liste beim nächsten
/// Übersetzungsdurchgang "verbessert": `username.placeholder` zeigt auf Englisch
/// `cityfox_m`, der Vorschlag lautet trotzdem `stadtfuchs_m`. Das ist der
/// Zustand der Quelle, keine Portierlücke.
const List<String> usernameSuggestionWords = <String>[
  'stadt',
  'nacht',
  'fluss',
  'stein',
  'turm',
  'markt',
  'gold',
];

/// Der feste Mittelteil, ebenfalls hartcodiert.
const String usernameSuggestionInfix = 'fuchs_';

/// Der Buchstabe, den die Quelle nimmt, wenn kein Stadtname da ist:
/// `(cityVal || 'x')[0]`.
const String usernameSuggestionFallbackInitial = 'x';

/// Zieht eine Zahl von `0` bis `max - 1`, wie `Math.floor(Math.random() * max)`.
///
/// Ein Funktionstyp und nicht [Random]: so kann ein Test einen festen Index
/// einsetzen, ohne sich auf die Implementierung von [Random] zu verlassen. Ein
/// `Random(0)` wäre reproduzierbar, aber nur solange die Dart-Version ihren
/// Generator nicht ändert, und ein Test, der an so etwas hängt, bricht ohne
/// eigene Schuld.
typedef RandomIndex = int Function(int max);

/// Woher der Zufall kommt.
///
/// Überschreibbar, damit der Vorschlag prüfbar ist. Kein globaler Zustand und
/// kein `Random` in der Seite: beides wäre aus einem Test nur über einen
/// Seitenkanal erreichbar.
final randomIndexProvider = Provider<RandomIndex>((ref) {
  final random = Random();
  return random.nextInt;
});

/// Der Vorschlag für [cityName].
///
/// [randomIndex] wählt das Wort. Die Reihenfolge der Bestandteile ist die der
/// Quelle: Wort, [usernameSuggestionInfix], Anfangsbuchstabe.
///
/// Ein leerer [cityName] ergibt `…fuchs_x`, weil die Quelle bei einem leeren
/// Wert auf `'x'` ausweicht. Der Fall ist über die Oberfläche nicht erreichbar,
/// die Stadtliste hat keine leeren Namen; er steht hier, weil die Quelle ihn
/// hat.
String suggestUsername(String cityName, {required RandomIndex randomIndex}) {
  final word =
      usernameSuggestionWords[randomIndex(usernameSuggestionWords.length)];
  final initial = cityName.isEmpty
      ? usernameSuggestionFallbackInitial
      : cityName.substring(0, 1).toLowerCase();
  return '$word$usernameSuggestionInfix$initial';
}
