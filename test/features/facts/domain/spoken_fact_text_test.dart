import 'package:fact_app/features/facts/domain/spoken_fact_text.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Vorlesefassung eines Fakts, `buildFullText` in
/// `02_Frontend/app/audio-player.jsx:63-70`.
void main() {
  FactText content({
    String? title,
    String? body,
    String? bodyExtra,
    String? bodyBackground,
    String? bodyToday,
  }) => FactText(
    title: title,
    body: body,
    bodyExtra: bodyExtra,
    bodyBackground: bodyBackground,
    bodyToday: bodyToday,
  );

  group('die Reihenfolge und die Trennung', () {
    test('Titel, dann die vier Textfelder in ihrer Nummerierung', () {
      expect(
        spokenFactText(
          content(
            title: 'Die Glyptothek',
            body: 'Eins',
            bodyExtra: 'Zwei',
            bodyBackground: 'Drei',
            bodyToday: 'Vier',
          ),
        ),
        'Die Glyptothek. Eins. Zwei. Drei. Vier',
      );
    });

    test('getrennt wird mit Punkt und Leerzeichen', () {
      // `parts.join('. ')`. Der Punkt setzt beim Sprecher die Satzpause; ohne
      // ihn liest die Sprachausgabe die Überschrift in den ersten Satz.
      expect(spokenFactTextSeparator, '. ');
      expect(
        spokenFactText(content(title: 'Titel', body: 'Text')),
        'Titel. Text',
      );
    });

    test('leere Felder fallen heraus', () {
      expect(
        spokenFactText(content(title: 'Titel', bodyBackground: 'Hintergrund')),
        'Titel. Hintergrund',
      );
    });

    test('eine leere Zeichenkette zählt wie ein fehlendes Feld', () {
      expect(spokenFactText(content(title: 'Titel', body: '')), 'Titel');
    });

    test('ein Fakt ohne jeden Text ergibt nichts', () {
      expect(spokenFactText(content()), isEmpty);
    });
  });

  group('Abweichung 1: ein fehlender Titel wird nicht mitgesprochen', () {
    test('ohne Titel beginnt der Vortrag beim ersten Text', () {
      // Die Quelle legt `fact.titel` **bedingungslos** in die Liste
      // (`const parts = [fact.titel]`), und bei einem Fakt ohne Titel liest
      // die Sprachausgabe dort wörtlich „undefined" vor, danach einen Punkt.
      expect(spokenFactText(content(body: 'Nur Text')), 'Nur Text');
    });

    test('und es steht kein führender Punkt davor', () {
      // Die andere Hälfte desselben Defekts: mit einem leeren ersten Teil in
      // der Liste würde `join` einen Punkt an den Anfang setzen.
      expect(spokenFactText(content(body: 'Nur Text')), isNot(startsWith('.')));
    });
  });

  group('Abweichung 2: die Zitat-Hochziffern fallen weg', () {
    test('eine Hochziffer mitten im Satz verschwindet mit ihrer Lücke', () {
      // Sonst spricht das Gerät „Der Turm drei wurde" oder „Der Turm Klammer
      // auf drei Klammer zu wurde". Für blinde Nutzer ist der Vortrag nicht
      // die Beigabe zum Text, sondern der Text.
      expect(
        spokenFactText(content(body: 'Der Turm [3] wurde gebaut.')),
        'Der Turm wurde gebaut.',
      );
    });

    test('mehrere Hochziffern in einem Satz', () {
      expect(
        spokenFactText(content(body: 'Erst [1] dann [12] und [3] Schluss.')),
        'Erst dann und Schluss.',
      );
    });

    test('eine Hochziffer am Satzende lässt kein Leerzeichen zurück', () {
      expect(spokenFactText(content(body: 'Ein Satz.[1]')), 'Ein Satz.');
    });

    test('eine Hochziffer als ganzer Text zählt wie kein Text', () {
      expect(spokenFactText(content(title: 'Titel', body: '[1]')), 'Titel');
    });

    test('eine zweistellige Ziffer wird auch getroffen', () {
      expect(spokenFactText(content(body: 'Text [42].')), 'Text.');
    });

    test('eine Klammer ohne Ziffer bleibt stehen', () {
      // Die Form ist `[3]`, dieselbe wie in `cited_text.dart`. Eine eckige
      // Klammer im Prosatext ist keine Quellenangabe und gehört vorgelesen.
      expect(
        spokenFactText(content(body: 'Ein [Einschub] im Satz.')),
        'Ein [Einschub] im Satz.',
      );
    });

    test('auch im Titel und in den hinteren Feldern', () {
      // Der Bestand trägt sie laut `highestSourceReference` in allen vier
      // Textfeldern.
      expect(
        spokenFactText(
          content(
            title: 'Titel [1]',
            body: 'Eins [2]',
            bodyExtra: 'Zwei [3]',
            bodyBackground: 'Drei [4]',
            bodyToday: 'Vier [5]',
          ),
        ),
        'Titel. Eins. Zwei. Drei. Vier',
      );
    });
  });
}
