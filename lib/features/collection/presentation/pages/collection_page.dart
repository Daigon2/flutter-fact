/// Der Reiseführer, `02_Frontend/app/screen-wallet.jsx:806-1078`
/// (`WltLibraryView`).
///
/// ## Warum dieser Bildschirm `collection` gehört und nicht `library`
///
/// `lib/features/README.md` hat `library` am 31.08.2026 gestrichen: „alles
/// kommt in den Wallet, also das Bücherregal mit den gesammelten Fakten, und
/// `collection` besitzt diesen Bildschirm". Die Münzen gehen ins Profil, sie
/// gehören `progression`. Siehe ADR-006.
///
/// ## Was hier steht und was noch nicht
///
/// Gebaut ist der erste der drei Zustände, die der Kopf von
/// `screen-wallet.jsx` aufzählt: **Bibliothek**. Kopfkarte, Bücherregal,
/// Trophäenzeile. Die beiden anderen sind eigene Schritte: das Stadt-Band mit
/// Cover ist Schritt 46, Kapitelliste und Lesemodus sind Schritt 47.
///
/// Ein Buchrücken ist deshalb **noch ohne Ziel**. Er sieht tippbar aus und tut
/// nichts, statt in einen halben Bildschirm zu führen; sobald das Cover steht,
/// bekommt [LibraryShelfView.onOpenVolume] hier einen Wert. Dieselbe Bauform
/// wie die Fakt-Akte in Schritt 21 und das Rätsel-Sheet in Schritt 27.
///
/// **Drei weitere Teile fehlen aus je eigenem Grund, und keiner davon ist
/// Bequemlichkeit:**
///
/// * Die **Rang-Pille** zeigt die Quelle nur bei `{myRank && …}` (`:851`). Es
///   gibt keine Rangliste, das ist Schritt 48. Weglassen ist hier das
///   Verhalten der Quelle und keine Auslassung.
/// * Die **Weiterlesen-Pille** (`:899-912`) hängt an `Storage.getLastRead()`,
///   also an einem Leseverlauf mit Zeitstempeln. Den gibt es nicht:
///   `CollectedFactsStore` speichert Kennungen in Sammelreihenfolge, ohne
///   Zeit. Auch hier zeigt die Quelle die Pille nur bei `{lastFact && …}`.
///   Sie kommt mit dem Lesemodus, der sie füllt (Schritt 47).
/// * Der **Freischaltstand der Trophäen** kommt nach E-49 vom Server, und
///   `progression` hat keine Datenschicht dafür. 36 gesperrte Trophäen sind
///   für einen neuen Nutzer richtig.
///
/// ## Der Fehlschlag zeigt dasselbe wie ein leeres Regal, und das ist Parität
///
/// Scheitert das Laden der Fakten, bleibt in der PWA `window.FACTS` leer
/// (`app.jsx:227` fängt den Fehler ab), und das Regal zeigt zwei Reihen
/// Leerplätze. Genau dasselbe passiert hier. Derselbe Gedanke wie bei
/// `fact_page.dart`, wo Fehlschlag und „nicht gefunden" ebenfalls in einem
/// Zustand zusammenfallen, weil die Quelle sie nicht unterscheidet.
///
/// ## Die 52 Pixel oben fehlen mit Grund
///
/// Die Quelle setzt `paddingTop: 52` (`screen-wallet.jsx:803`), und das ist
/// dort die Höhe ihrer festen Kopfleiste. Dieser Reiter hat keine, die Zahl
/// wäre also eine leere Fläche. Genommen wird das Sicherheitsgebiet des
/// Geräts; der Innenabstand der Kopfkarte steht an ihr selbst.
library;

import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/features/collection/application/library_providers.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_header_card.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_shelf_view.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_trophy_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Reiter mit den gesammelten Fakten.
class CollectionPage extends ConsumerWidget {
  /// Erzeugt den Reiseführer.
  const CollectionPage({super.key});

  /// Die Kennung des Ladekreises, für Tests.
  static const Key loadingKey = Key('library-loading');

  /// Die Kennung der Bildlaufliste, für Tests.
  static const Key scrollKey = Key('library-scroll');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FactColors colors = context.factColors;
    final AsyncValue<List<LibraryVolume>> shelf = ref.watch(
      libraryShelfProvider,
    );
    final int collectedCount = ref.watch(collectedFactCountProvider);
    final List<LibraryVolume>? volumes = shelf.value;

    if (volumes == null && shelf.isLoading) {
      return ColoredBox(
        color: colors.bg,
        child: const Center(child: CircularProgressIndicator(key: loadingKey)),
      );
    }

    return ColoredBox(
      color: colors.bg,
      child: SafeArea(
        child: SingleChildScrollView(
          key: scrollKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LibraryHeaderCard(
                collectedCount: collectedCount,
                cityCount: volumes?.length ?? 0,
              ),
              LibraryShelfView(volumes: volumes ?? const <LibraryVolume>[]),
              const LibraryTrophyRow(),
            ],
          ),
        ),
      ),
    );
  }
}
