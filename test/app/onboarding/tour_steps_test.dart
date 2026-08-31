import 'package:fact_app/app/onboarding/tour_steps.dart';
import 'package:fact_app/app/shell/shell_tab.dart';
import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die neun Schritte gegen `02_Frontend/app/screen-tour.jsx:140-169`.
///
/// Reine Daten, deshalb ohne Widget-Baum. Der Wert dieser Datei liegt darin,
/// dass ein vertauschter Anker oder eine verrutschte Blasenhöhe hier auffällt
/// und nicht erst, wenn jemand die App ansieht.
void main() {
  group('Die Liste', () {
    test('hat neun Schritte, nicht die acht aus dem Kommentar der Quelle', () {
      // `screen-tour.jsx:2` und `:137` sagen "8 Schritte", `storage.jsx:99`
      // sagt "5-Schritt". Beides ist falsch, siehe Korrektur 12 in
      // `REBUILD_STATUS.md`.
      expect(TourSteps.all, hasLength(9));
      expect(TourSteps.count, 9);
    });

    test('die Nummer eines Schritts entspricht seiner Position', () {
      // Ohne diese Zusicherung könnte ein eingeschobener Schritt die
      // Schrittanzeige und die i18n-Schlüssel gegeneinander verschieben, ohne
      // dass irgendetwas fehlschlägt.
      for (var index = 0; index < TourSteps.all.length; index++) {
        expect(TourSteps.all[index].number, index + 1, reason: 'Index $index');
      }
    });

    test('die Liste ist nicht veränderbar', () {
      expect(
        () => TourSteps.all.add(const TourHeroStep(number: 10)),
        throwsUnsupportedError,
      );
    });

    test('jeder Schritt zeigt auf sein Schlüsselpaar', () {
      expect(TourSteps.all.first.titleKey, 'tour.step1.title');
      expect(TourSteps.all.first.bodyKey, 'tour.step1.body');
      expect(TourSteps.all.last.titleKey, 'tour.step9.title');
      expect(TourSteps.all.last.bodyKey, 'tour.step9.body');
    });
  });

  group('Die zwei Hero-Schritte', () {
    test('sind der erste und der letzte, `screen-tour.jsx:141` und `:168`', () {
      final heroPositions = <int>[
        for (var i = 0; i < TourSteps.all.length; i++)
          if (TourSteps.all[i] is TourHeroStep) i,
      ];

      expect(heroPositions, <int>[0, 8]);
    });

    test('zeigen auf ihr Meta-Schlüsselpaar', () {
      // Der Wortlaut selbst steht seit dem 28.08.2026 als E-39-Ergänzung in
      // `app_strings_supplement.dart`, siehe
      // `app_strings_supplement_test.dart`. Hier wird nur die Verdrahtung
      // geprüft, nicht der Text.
      expect((TourSteps.all.first as TourHeroStep).metaKey, 'tour.step1.meta');
      expect((TourSteps.all.last as TourHeroStep).metaKey, 'tour.step9.meta');
    });
  });

  group('Die sieben Schritte mit Anker', () {
    List<TourAnchoredStep> anchored() =>
        TourSteps.all.whereType<TourAnchoredStep>().toList();

    test('stehen in der Ankerreihenfolge der Quelle', () {
      expect(anchored().map((step) => step.anchorId).toList(), <AnchorId>[
        DiscoveryAnchors.balloon,
        DiscoveryAnchors.userMarker,
        DiscoveryAnchors.coins,
        ShellTab.collection.anchorId,
        DiscoveryAnchors.modeTour,
        ShellTab.challenges.anchorId,
        DiscoveryAnchors.compass,
      ]);
    });

    test('die beiden Tab-Anker heißen wie in der PWA', () {
      // Der Gegencheck zur Zeile darüber: `ShellTab.collection` könnte
      // umbenannt werden, ohne dass der Test oben etwas merkt.
      expect(ShellTab.collection.anchorId, const AnchorId('tab-wallet'));
      expect(ShellTab.challenges.anchorId, const AnchorId('tab-challenge'));
    });

    test('tragen die Blasenhöhen und Krümmungen der Quelle', () {
      expect(anchored().map((step) => step.bubbleTop).toList(), <double>[
        170,
        380,
        380,
        200,
        380,
        200,
        380,
      ]);
      expect(anchored().map((step) => step.curve).toList(), <double>[
        0.4,
        -0.35,
        0.35,
        -0.35,
        0.35,
        0.35,
        0.35,
      ]);
    });

    test('acht Schritte sind voll baubar, einer degradiert', () {
      // Korrektur 13 in `REBUILD_STATUS.md`: die frühere Zahl 6/3 war falsch,
      // richtig waren 4/5. Seit dem Top-Chrome des Kartenbildschirms waren es
      // 7/2, seit `discovery_balloon_anchor.dart` sind es 8/1. Die Bilanz
      // hängt an `DiscoveryAnchors.knownMissing`, schrumpft also von selbst.
      // Bricht dieser Test, ist das kein Defekt, sondern ein gebauter
      // Kartenanker.
      final degrading = anchored()
          .where(
            (step) => DiscoveryAnchors.knownMissing.contains(step.anchorId),
          )
          .map((step) => step.number)
          .toList();

      // Übrig ist der Avatar-Marker, Schritt 18 und E-10.
      expect(degrading, <int>[3]);
      expect(
        anchored()
            .where(
              (step) => !DiscoveryAnchors.knownMissing.contains(step.anchorId),
            )
            .map((step) => step.number)
            .toList(),
        <int>[2, 4, 5, 6, 7, 8],
      );
    });
  });
}
