/// Ein Buchrücken im Bücherregal, `02_Frontend/app/screen-wallet.jsx:958-1010`.
///
/// ## Nicht `WltBookSpine`, und das ist der Punkt
///
/// Dieselbe Datei enthält eine Funktion `WltBookSpine` (`:381-459`), die
/// genau das zu sein scheint: ein Buchrücken als eigene Komponente, mit
/// Papierkorn, einem eingeprägten `FACT`-Stempel und der Bandnummer über
/// `t('wallet.bandLabel')`. **Sie wird nirgends aufgerufen.** Gemessen am
/// 03.09.2026 über alle `*.jsx` der PWA: die einzige Fundstelle ist ihre
/// eigene Definition. `WltLibraryView` zeichnet den Rücken direkt im Gitter,
/// mit anderen Maßen (165 bis 215 statt 178 bis 250), anderem Goldband
/// (6 statt 8 Pixel), weißem statt cremefarbenem Titel und ohne Korn und
/// Stempel.
///
/// Nachgebaut ist die **lebende** Fassung. Registriert als E-76, samt der
/// zweiten Leiche derselben Datei (`WltCityVolumeView_REMOVED`, 330 Zeilen).
///
/// ## Was der ausgebaute Zwilling verrät
///
/// Er hätte die Bandnummer so gebaut:
/// `t('wallet.bandLabel', lang).replace('{n}', …).replace('Band', '№').replace('Vol.', '№')`.
/// Der Schlüssel wird geholt, gefüllt, und dann wird sein einziges Wort durch
/// ein Zeichen ersetzt. Übrig bleibt in jeder Sprache „№ 3". Die lebende
/// Fassung schreibt gleich `№ {volNo}` hin und braucht den Schlüssel nicht;
/// das ist die ehrlichere von beiden, und sie ist die, die hier steht.
library;

import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/library_geometry.dart';
import 'package:fact_app/features/collection/presentation/library_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ein Band auf dem Regal.
class LibraryBookSpine extends ConsumerWidget {
  /// Erzeugt einen Buchrücken für [volume].
  const LibraryBookSpine({
    required this.volume,
    required this.volumeNumber,
    this.onTap,
    super.key,
  });

  /// Die Kennung eines Buchrückens, für Tests und für das Tutorial.
  static Key spineKey(String cityKey) => Key('library-spine-$cityKey');

  /// Der Band, der hier steht.
  final LibraryVolume volume;

  /// Die Nummer auf dem Rücken, siehe [libraryVolumeNumber].
  final int volumeNumber;

  /// Was beim Antippen passiert.
  ///
  /// `null` ist erlaubt und heißt „noch kein Ziel": das Stadt-Cover ist
  /// Schritt 46, die Kapitelliste Schritt 47. Ein Rücken ohne Ziel bleibt
  /// tippbar aussehend, tut aber nichts, statt in einen halben Bildschirm zu
  /// führen.
  final VoidCallback? onTap;

  /// Der Innenabstand, `10px 0 8px` (`screen-wallet.jsx:971`).
  static const EdgeInsets padding = EdgeInsets.only(top: 10, bottom: 8);

  /// Der Abstand um den Titel, `6px 0 10px` (`screen-wallet.jsx:988`).
  static const EdgeInsets titleMargin = EdgeInsets.only(top: 6, bottom: 10);

  /// Der Innenabstand der Zählerplatte, `3px 0` (`screen-wallet.jsx:994`).
  static const EdgeInsets counterPadding = EdgeInsets.symmetric(vertical: 3);

  /// Der Abstand über der Bandnummer (`screen-wallet.jsx:1004`).
  static const double volumeNumberSpacing = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double height = libraryBookHeight(
      collected: volume.collected,
      total: volume.total,
    );
    final String label = ref
        .watch(appStringsProvider)
        .text(
          'wallet.shelfVolumeLabel',
          params: <String, String>{
            'city': volume.name,
            'collected': '${volume.collected}',
            'total': '${volume.total}',
          },
        );

    return Semantics(
      button: true,
      label: label,
      // **`excludeSemantics` ist die Entsprechung von `aria-label`.** In HTML
      // *ersetzt* das Attribut den Inhalt für Hilfstechnik, es ergänzt ihn
      // nicht. Ohne diese Zeile lägen Titel, Zähler und Bandnummer als eigene
      // Knoten darunter, und ein Screenreader läse den Satz und danach die
      // Bruchteile noch einmal einzeln vor.
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: spineKey(volume.cityKey),
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: libraryBookRadius,
            boxShadow: const <BoxShadow>[libraryBookShadow],
            gradient: LinearGradient(
              // `90deg` in CSS zeigt nach rechts.
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: libraryBookGradientStops,
              colors: <Color>[
                _color(volume.palette.colorDk),
                _color(volume.palette.color),
                _color(volume.palette.color),
                _color(volume.palette.colorLt),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _ribbon(),
              Expanded(child: _title()),
              _counterPlate(),
              const SizedBox(height: volumeNumberSpacing),
              _volumeNumber(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ribbon() => Container(
    height: libraryBookRibbonHeight,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: libraryBookRibbonStops,
        colors: libraryBookRibbonColors,
      ),
    ),
  );

  Widget _title() => Padding(
    padding: titleMargin,
    child: Center(
      // `writing-mode: vertical-rl` plus `rotate(180deg)`
      // (`screen-wallet.jsx:984-985`) liest von unten nach oben. Drei
      // Vierteldrehungen sind genau das; `quarterTurns: 1` liefe von oben
      // nach unten und wäre auf einem Buchrücken die andere Leserichtung.
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(
          volume.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: FactFont.display,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1,
            color: libraryBookTitleColor,
            shadows: <Shadow>[libraryBookTitleShadow],
          ),
        ),
      ),
    ),
  );

  Widget _counterPlate() => FractionallySizedBox(
    widthFactor: libraryCounterPlateWidthFactor,
    child: Container(
      padding: counterPadding,
      decoration: const BoxDecoration(
        color: libraryCounterPlateColor,
        border: Border.symmetric(
          horizontal: BorderSide(color: libraryCounterPlateLineColor),
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: '${volume.collected}'),
            TextSpan(
              text: '/${volume.total}',
              style: TextStyle(
                color: libraryBookTitleColor.withValues(
                  alpha: libraryCounterTotalOpacity,
                ),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: FactFont.mono,
          fontWeight: FontWeight.w600,
          fontSize: 9,
          letterSpacing: 0.5,
          height: 1,
          color: libraryBookTitleColor,
        ),
      ),
    ),
  );

  Widget _volumeNumber() => Text(
    '№ $volumeNumber',
    style: const TextStyle(
      fontFamily: FactFont.mono,
      fontWeight: FontWeight.w600,
      fontSize: 7.5,
      letterSpacing: 0.2,
      color: libraryVolumeNumberColor,
    ),
  );

  /// Wandelt ein `#RRGGBB` aus der erzeugten Palette in eine Farbe.
  ///
  /// Die Palette hält die Werte als Zeichenkette, weil sie eine wörtliche
  /// Abschrift der Quelle ist und `dart:ui` in `application` nichts zu suchen
  /// hätte. Die Umwandlung gehört deshalb hierher.
  static Color _color(String hex) =>
      Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
