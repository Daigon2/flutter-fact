/// Die neun Schritte des Tutorials als reine Daten,
/// `02_Frontend/app/screen-tour.jsx:140-169`.
///
/// ## Es sind neun, nicht acht und nicht fünf
///
/// Die Kommentare der Quelle sind an dieser Stelle falsch: `screen-tour.jsx:2`
/// und `:137` sagen "8 Schritte", `storage.jsx:99` sagt "5-Schritt". Gezählt
/// sind es neun, dreifach belegt: neun Einträge im `STEPS`-Array, `tour.step1`
/// bis `tour.step9` in beiden Sprachen, und die Schrittanzeige rechnet mit
/// `STEPS.length`. Korrektur 12 in `REBUILD_STATUS.md`.
///
/// ## Warum die Anker hier nur referenziert und nicht benannt werden
///
/// E-27: die Kennung gehört der Oberfläche, die das Widget zeichnet. Diese
/// Datei ist die Abfragestelle und schreibt deshalb keine einzige Zeichenkette
/// selbst, sondern nimmt `ShellTab.anchorId` und `DiscoveryAnchors`. Ein hier
/// neu getipptes `'tab-wallet'` wäre genau der Fehler, gegen den es sonst keine
/// Absicherung gibt: er sieht aus wie ein noch nicht gebauter Anker.
library;

import 'package:fact_app/app/shell/shell_tab.dart';
import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:flutter/foundation.dart' show immutable;

/// Ein Schritt des Tutorials.
///
/// Zwei Ausprägungen, weil die Quelle zwei getrennte Renderpfade hat: ein
/// Hero-Schritt (`screen-tour.jsx:342-395`) füllt den Bildschirm und hat keinen
/// Anker, ein regulärer Schritt (`:435-505`) hat eine Blase, einen Anker und
/// eine Pfeilkrümmung. `sealed`, damit ein `switch` über beide vollständig sein
/// muss und ein dritter Fall nicht still durchrutscht.
@immutable
sealed class TourStep {
  const TourStep({required this.number});

  /// Die Nummer des Schritts, beginnend bei 1.
  ///
  /// Sie steht am Schritt und wird nicht aus dem Listenindex abgeleitet, weil
  /// sie zwei Dinge trägt: die i18n-Schlüssel und die sichtbare Schrittanzeige.
  /// Dass Nummer und Position übereinstimmen, sichert ein Test zu.
  final int number;

  /// Schlüssel der Überschrift, `screen-tour.jsx:277`.
  String get titleKey => 'tour.step$number.title';

  /// Schlüssel des Fließtextes, `screen-tour.jsx:278`.
  String get bodyKey => 'tour.step$number.body';
}

/// Ein Vollbild-Schritt ohne Anker, `screen-tour.jsx:342-395`.
@immutable
final class TourHeroStep extends TourStep {
  /// Erzeugt einen Hero-Schritt.
  const TourHeroStep({required super.number});

  /// Schlüssel der goldenen Zeile unter dem Text, `screen-tour.jsx:388`.
  ///
  /// Die Quelle schreibt beide Werte hart in das `STEPS`-Array (`:141` und
  /// `:168`) und führt dafür keinen i18n-Schlüssel. Freigegeben am 28.08.2026
  /// als E-39-Ergänzung: `tour.step1.meta` und `tour.step9.meta` in
  /// `app_strings_supplement.dart`, wortwörtlich aus der Quelle übernommen,
  /// nicht erfunden. `onboarding.quoteAuthor` existiert ebenfalls, trägt aber
  /// einen anderen Text ("— Goethe (vermutlich)") und ist hier nicht gemeint.
  ///
  /// Belegte Eigenart, die mit übernommen ist: `PUSH AUS DER HOSENTASCHE`
  /// steht in der Quelle **auch im englischen Modus deutsch**, weil das
  /// `STEPS`-Array nicht pro Sprache existiert. Die Ergänzung trägt deshalb in
  /// beiden Sprachkarten denselben Wert, keine Übersetzung.
  String get metaKey => 'tour.step$number.meta';
}

/// Ein Schritt mit Blase, Anker und Pfeil, `screen-tour.jsx:435-505`.
@immutable
final class TourAnchoredStep extends TourStep {
  /// Erzeugt einen regulären Schritt.
  const TourAnchoredStep({
    required super.number,
    required this.bubbleTop,
    required this.anchorId,
    required this.curve,
  });

  /// Abstand der Blasenoberkante von der Oberkante der Bezugsfläche.
  ///
  /// Absoluter Wert aus der Quelle (`bubble: { top: ... }`), gedacht für den
  /// 844 Pixel hohen Rahmen der PWA. Bewusst nicht in einen Anteil der Höhe
  /// umgerechnet: die Blase weicht dem Ziel aus, und welcher Wert wozu passt,
  /// ist an den Anker gebunden, nicht an die Bildschirmhöhe.
  final double bubbleTop;

  /// Das Ziel, auf das Pfeil und Leuchtring zeigen.
  final AnchorId anchorId;

  /// Krümmung des Pfeils, `arrow: { curve: ... }`.
  ///
  /// Das Vorzeichen entscheidet, auf welcher Seite der Bogen ausschlägt.
  final double curve;
}

/// Die neun Schritte in ihrer Reihenfolge.
abstract final class TourSteps {
  /// Alle Schritte, `screen-tour.jsx:140-169`.
  ///
  /// Vier davon sind heute voll baubar (1, 5, 7, 9), fünf degradieren, weil
  /// ihre Anker auf dem Kartenbildschirm liegen und der ein Platzhalter ist.
  /// Ein fehlender Anker überspringt den Schritt **nicht**, er zeichnet ihn
  /// ohne Pfeil und ohne Ring (`screen-tour.jsx:254`, `:447`, `:450`).
  /// Korrektur 13 in `REBUILD_STATUS.md`.
  static final List<TourStep> all = List<TourStep>.unmodifiable(<TourStep>[
    // 1: Goethe-Zitat, Hero. `screen-tour.jsx:141`.
    const TourHeroStep(number: 1),
    // 2: Ballons und Sammeln. `:145`.
    TourAnchoredStep(
      number: 2,
      bubbleTop: 170,
      anchorId: DiscoveryAnchors.balloon,
      curve: 0.4,
    ),
    // 3: der eigene Avatar. `:149`.
    TourAnchoredStep(
      number: 3,
      bubbleTop: 380,
      anchorId: DiscoveryAnchors.userMarker,
      curve: -0.35,
    ),
    // 4: Coins. `:152`.
    TourAnchoredStep(
      number: 4,
      bubbleTop: 380,
      anchorId: DiscoveryAnchors.coins,
      curve: 0.35,
    ),
    // 5: der Fakten-Tab. `:155`. Die Quelle nennt den Anker `tab-wallet`,
    // ShellTab.collection trägt genau diese Kennung.
    TourAnchoredStep(
      number: 5,
      bubbleTop: 200,
      anchorId: ShellTab.collection.anchorId,
      curve: -0.35,
    ),
    // 6: der Tour-Modus im Modus-Umschalter. `:158`.
    TourAnchoredStep(
      number: 6,
      bubbleTop: 380,
      anchorId: DiscoveryAnchors.modeTour,
      curve: 0.35,
    ),
    // 7: der Challenge-Tab. `:161`.
    TourAnchoredStep(
      number: 7,
      bubbleTop: 200,
      anchorId: ShellTab.challenges.anchorId,
      curve: 0.35,
    ),
    // 8: der Kompass. `:164`.
    TourAnchoredStep(
      number: 8,
      bubbleTop: 380,
      anchorId: DiscoveryAnchors.compass,
      curve: 0.35,
    ),
    // 9: Handy einstecken, Hero. `:168`.
    const TourHeroStep(number: 9),
  ]);

  /// Anzahl der Schritte, also das `{total}` der Schrittanzeige.
  static int get count => all.length;
}
