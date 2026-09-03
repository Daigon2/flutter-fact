/// Der Reiseführer, `02_Frontend/app/screen-wallet.jsx`.
///
/// ## Warum dieser Bildschirm `collection` gehört und nicht `library`
///
/// `lib/features/README.md` hat `library` am 31.08.2026 gestrichen: „alles
/// kommt in den Wallet, also das Bücherregal mit den gesammelten Fakten, und
/// `collection` besitzt diesen Bildschirm". Die Münzen gehen ins Profil, sie
/// gehören `progression`. Siehe ADR-006.
///
/// ## Drei Zustände, eine Route
///
/// Der Kopf von `screen-wallet.jsx` nennt drei Zustände: Bibliothek,
/// Stadt-Band und Lesemodus. Gebaut sind das Regal (Schritt 45), der
/// Buchdeckel (Schritt 46) und das Inhaltsverzeichnis (Schritt 47). Der
/// Lesemodus ist der Rest von Schritt 47, und deshalb bleibt eine
/// Kapitelkarte heute ohne Ziel.
///
/// **Der Wechsel ist Zustand und keine zweite Route.** `WalletScreen` hält
/// `view` und `cityKey` als React-State (`:1834-1835`), und E-25 hat die
/// öffentliche Routenfläche auf sieben Pfade festgelegt. Dieselbe Bauform wie
/// `ChallengesPage`, die den Assistenten und den Startpunkt-Picker ebenfalls
/// als zwei Zustände eines Reiters trägt.
///
/// Die Quelle merkt sich `cityKey` **über den Wechsel hinaus** und belegt ihn
/// mit der ersten Stadt des Regals vor. Hier ist `null` der Zustand
/// „Bibliothek", weil es dafür heute keinen Verbraucher gibt: den einzigen
/// Fall, in dem die Stadt von außen gesetzt werden muss, bringt der Lesemodus
/// mit (`openFact` schaltet auf die Stadt des geöffneten Fakts,
/// `:1848-1852`), und der ist noch nicht gebaut.
///
/// ## Drei Teile fehlen aus je eigenem Grund, und keiner ist Bequemlichkeit
///
/// * Die **Rang-Pille** zeigt die Quelle nur bei `{myRank && …}` (`:851`). Es
///   gibt keine Rangliste, das ist Schritt 48.
/// * Die **Weiterlesen-Pille** (`:899-912`) hängt an `Storage.getLastRead()`,
///   also an einem Leseverlauf mit Zeitstempeln. Den gibt es nicht:
///   `CollectedFactsStore` speichert Kennungen in Sammelreihenfolge, ohne
///   Zeit. Auch hier zeigt die Quelle die Pille nur bei `{lastFact && …}`.
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
/// Die Quelle setzt `paddingTop: 52` (`:803`), und das ist dort die Höhe ihrer
/// festen Kopfleiste. Dieser Reiter hat keine, die Zahl wäre also eine leere
/// Fläche. Genommen wird das Sicherheitsgebiet des Geräts; der Innenabstand
/// der Kopfkarte steht an ihr selbst.
library;

import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/features/collection/application/library_categories.dart';
import 'package:fact_app/features/collection/application/library_providers.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_chapters_view.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_cover_view.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_header_card.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_shelf_view.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_trophy_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Reiter mit den gesammelten Fakten.
class CollectionPage extends ConsumerStatefulWidget {
  /// Erzeugt den Reiseführer.
  const CollectionPage({super.key});

  /// Die Kennung des Ladekreises, für Tests.
  static const Key loadingKey = Key('library-loading');

  /// Die Kennung der Bildlaufliste, für Tests.
  static const Key scrollKey = Key('library-scroll');

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

/// Welcher der drei Zustände sichtbar ist, `view` in der Quelle (`:1834`).
enum _LibraryView {
  /// Das Regal.
  library,

  /// Der Buchdeckel einer Stadt.
  cover,

  /// Das Inhaltsverzeichnis einer Stadt.
  chapters,
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  /// Der offene Band, oder `null` für die Bibliothek.
  String? _openCityKey;

  /// Der sichtbare Zustand.
  ///
  /// Zwei Felder statt einem: die Quelle hält `view` und `cityKey` ebenfalls
  /// getrennt (`:1834-1835`), und der Weg vom Inhaltsverzeichnis zurück führt
  /// auf den Deckel **derselben** Stadt. Ein einziges Feld müsste die Stadt
  /// dabei mitschleppen.
  _LibraryView _view = _LibraryView.library;

  @override
  Widget build(BuildContext context) {
    final FactColors colors = context.factColors;
    final AsyncValue<List<LibraryVolume>> shelf = ref.watch(
      libraryShelfProvider,
    );
    final List<LibraryVolume>? volumes = shelf.value;

    if (volumes == null && shelf.isLoading) {
      return ColoredBox(
        color: colors.bg,
        child: const Center(
          child: CircularProgressIndicator(key: CollectionPage.loadingKey),
        ),
      );
    }

    final String? openKey = _openCityKey;
    if (openKey != null) {
      // Der Band kann verschwinden, während er offen ist: ein Neuladen ohne
      // seine Fakten lässt ihn aus dem Regal fallen. Dann führt der Weg
      // zurück in die Bibliothek, statt ein Cover ohne Band zu zeichnen.
      final LibraryVolume? open = volumes
          ?.where((LibraryVolume v) => v.cityKey == openKey)
          .firstOrNull;
      if (open != null) {
        return _view == _LibraryView.chapters ? _chapters(open) : _cover(open);
      }
    }

    return _library(colors, volumes);
  }

  Widget _library(FactColors colors, List<LibraryVolume>? volumes) =>
      ColoredBox(
        color: colors.bg,
        child: SafeArea(
          child: SingleChildScrollView(
            key: CollectionPage.scrollKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LibraryHeaderCard(
                  collectedCount: ref.watch(collectedFactCountProvider),
                  cityCount: volumes?.length ?? 0,
                ),
                LibraryShelfView(
                  volumes: volumes ?? const <LibraryVolume>[],
                  onOpenVolume: (LibraryVolume volume) => setState(() {
                    _openCityKey = volume.cityKey;
                    _view = _LibraryView.cover;
                  }),
                ),
                const LibraryTrophyRow(),
              ],
            ),
          ),
        ),
      );

  Widget _cover(LibraryVolume volume) {
    // Die Kapitelzahl ist eine zweite Abfrage über dieselben Fakten. Solange
    // sie lädt, steht auf der Kachel eine Null; das Cover wartet **nicht**,
    // weil sonst der ganze Deckel für eine von drei Zahlen flackerte.
    final List<LibraryChapter> chapters =
        ref.watch(libraryChaptersProvider(volume.cityKey)).value ??
        const <LibraryChapter>[];

    return SafeArea(
      child: LibraryCoverView(
        volume: volume,
        startedChapters: chapters
            .where((LibraryChapter chapter) => chapter.isStarted)
            .length,
        onBack: () => setState(() {
          _openCityKey = null;
          _view = _LibraryView.library;
        }),
        onOpenChapters: () => setState(() => _view = _LibraryView.chapters),
      ),
    );
  }

  Widget _chapters(LibraryVolume volume) => SafeArea(
    child: LibraryChaptersView(
      volume: volume,
      // Auch hier ohne Warten, und mit demselben Grund wie beim Cover: die
      // Fakten liegen schon geladen da, `libraryChaptersProvider` rechnet nur
      // eine Schleife darüber. Ein Ladekreis für eine Rechnung im
      // Mikrosekundenbereich wäre ein Flackern und keine Rückmeldung.
      chapters:
          ref.watch(libraryChaptersProvider(volume.cityKey)).value ??
          const <LibraryChapter>[],
      onBack: () => setState(() => _view = _LibraryView.cover),
    ),
  );
}
