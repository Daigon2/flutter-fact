import 'dart:io';

import 'package:fact_app/map/presentation/avatar/avatar_bridge.dart';
import 'package:fact_app/map/presentation/avatar/avatar_motion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die JavaScript-Aufrufe an die Figur, und der Vertrag zur HTML-Datei.
///
/// **Der zweite Teil ist der wertvollere.** `runJavaScript` meldet keinen
/// Fehler des Skripts: wer die Funktion in `index.html` umbenennt, bekommt
/// eine stehende Figur und keine Meldung. Diese Datei liest deshalb das Asset
/// und prüft, dass es hält, was die Dart-Seite aufruft.
void main() {
  group('Aufrufe', () {
    test('setAnim bekommt den JS-Namen der Animation', () {
      expect(
        avatarSetAnimationScript(AvatarAnimation.walk),
        "window.FactAvatar && FactAvatar.setAnim('walk');",
      );
    });

    test('idle und wave genauso', () {
      expect(
        avatarSetAnimationScript(AvatarAnimation.idle),
        "window.FactAvatar && FactAvatar.setAnim('idle');",
      );
      expect(
        avatarSetAnimationScript(AvatarAnimation.wave),
        "window.FactAvatar && FactAvatar.setAnim('wave');",
      );
    });

    test('setGender bekommt den JS-Namen der Fassung', () {
      expect(
        avatarSetGenderScript(AvatarGender.female),
        "window.FactAvatar && FactAvatar.setGender('female');",
      );
    });

    test('jeder Aufruf trägt die Wache davor', () {
      // Ohne sie wirft ein Aufruf im Fenster zwischen `onPageFinished` und
      // dem `load`-Ereignis der Seite, und die Ausnahme kommt auf der
      // Flutter-Seite nirgends an.
      for (final String script in <String>[
        avatarSetAnimationScript(AvatarAnimation.idle),
        avatarSetGenderScript(AvatarGender.male),
        avatarIsReadyScript,
      ]) {
        expect(script, startsWith('window.FactAvatar'), reason: script);
      }
    });

    test('die Frage nach der Bereitschaft ist ein Ausdruck ohne Semikolon', () {
      // `runJavaScriptReturningResult` wertet einen Ausdruck aus. Mit einem
      // Semikolon wäre es eine Anweisung, und die gibt `null` zurück.
      expect(avatarIsReadyScript, isNot(endsWith(';')));
      expect(avatarIsReadyScript, contains('isReady()'));
    });
  });

  group('avatarScriptsToSend', () {
    test('vor dem Laden geht nichts hinaus', () {
      // Und zwar gar nichts. Würde hier gesendet, müsste der Aufrufer den
      // Wert als „geschickt" merken, obwohl er nirgends ankam, und der erste
      // echte Aufruf nach dem Laden fiele als „unverändert" heraus.
      expect(
        avatarScriptsToSend(
          isReady: false,
          animation: AvatarAnimation.walk,
          gender: AvatarGender.male,
        ),
        isEmpty,
      );
    });

    test('das erste Mal gehen beide hinaus, Fassung zuerst', () {
      expect(
        avatarScriptsToSend(
          isReady: true,
          animation: AvatarAnimation.idle,
          gender: AvatarGender.male,
        ),
        <String>[
          "window.FactAvatar && FactAvatar.setGender('male');",
          "window.FactAvatar && FactAvatar.setAnim('idle');",
        ],
      );
    });

    test('eine geänderte Animation schickt nur die Animation', () {
      // **Der Kern dieser Datei.** `setGender` setzt die Szene neu auf; wer es
      // mitschickt, baut die Figur bei jedem Schritt neu.
      expect(
        avatarScriptsToSend(
          isReady: true,
          animation: AvatarAnimation.walk,
          gender: AvatarGender.male,
          sentAnimation: AvatarAnimation.idle,
          sentGender: AvatarGender.male,
        ),
        <String>["window.FactAvatar && FactAvatar.setAnim('walk');"],
      );
    });

    test('eine geänderte Fassung schickt nur die Fassung', () {
      expect(
        avatarScriptsToSend(
          isReady: true,
          animation: AvatarAnimation.walk,
          gender: AvatarGender.female,
          sentAnimation: AvatarAnimation.walk,
          sentGender: AvatarGender.male,
        ),
        <String>["window.FactAvatar && FactAvatar.setGender('female');"],
      );
    });

    test('unverändert geht nichts hinaus', () {
      expect(
        avatarScriptsToSend(
          isReady: true,
          animation: AvatarAnimation.walk,
          gender: AvatarGender.male,
          sentAnimation: AvatarAnimation.walk,
          sentGender: AvatarGender.male,
        ),
        isEmpty,
      );
    });

    test('beides geändert schickt beides, und die Fassung steht vorn', () {
      // Die Reihenfolge ist heute ohne Wirkung und trotzdem festgenagelt: wer
      // `index.html` einmal anders schreibt, hätte sonst eine Figur, die nach
      // dem Fassungswechsel steht, obwohl sie laufen soll.
      final List<String> scripts = avatarScriptsToSend(
        isReady: true,
        animation: AvatarAnimation.walk,
        gender: AvatarGender.female,
        sentAnimation: AvatarAnimation.idle,
        sentGender: AvatarGender.male,
      );

      expect(scripts, hasLength(2));
      expect(scripts.first, contains('setGender'));
      expect(scripts.last, contains('setAnim'));
    });
  });

  group('Vertrag zur HTML-Datei', () {
    // Gelesen und nicht nachgebaut: der Test soll fallen, wenn das Asset sich
    // ändert, nicht wenn eine Kopie davon sich ändert.
    final String html = File('assets/avatar/index.html').readAsStringSync();

    test('die Datei legt genau die Schnittstelle an, die Dart aufruft', () {
      expect(html, contains('window.$avatarBridgeName = {'));
    });

    test('sie hat die drei Funktionen, die Dart benutzt', () {
      expect(html, contains('setAnim: function'));
      expect(html, contains('setGender: function'));
      expect(html, contains('isReady: function'));
    });

    test('sie kennt dieselben Animationsnamen wie der Wertebereich', () {
      for (final AvatarAnimation animation in AvatarAnimation.values) {
        expect(
          html,
          contains("'${animation.jsName}'"),
          reason: animation.jsName,
        );
      }
    });

    test('sie lädt die beiden Skripte aus demselben Verzeichnis', () {
      // Relative Pfade, weil `loadFlutterAsset` das Verzeichnis als
      // Wurzel setzt. Ein absoluter Pfad ginge auf dem Gerät ins Leere.
      expect(html, contains('src="three.min.js"'));
      expect(html, contains('src="tourist-character.js"'));
      expect(html, isNot(contains('src="/')));
      expect(html, isNot(contains('http://')));
      expect(
        html,
        isNot(contains('https://')),
        reason:
            'Die Figur lädt nichts aus dem Netz. Ein WebView, der das täte, '
            'wäre ein Weg nach draußen, den niemand bemerkt.',
      );
    });

    test('nichts in der Seite nimmt Gesten an', () {
      // Der WebView ist ein eigener Empfänger. `IgnorePointer` auf der
      // Flutter-Seite allein genügt nicht.
      expect(html, contains('pointer-events: none'));
    });

    test('der Hintergrund ist durchsichtig', () {
      // Ein weißer Kasten über der Karte wäre der auffälligste Fehler dieses
      // Schritts.
      expect(html, contains('background: transparent'));
      expect(html, contains("background: 'transparent'"));
    });
  });

  group('Die Assets liegen da und sind die der Quelle', () {
    test('drei Dateien, und three.min.js ist die große', () {
      // Die Größen sind ausgeschrieben, damit ein versehentliches Ersetzen
      // auffällt. `REBUILD_STATUS.md` nannte 270 KB; gemessen sind es 704.
      expect(File('assets/avatar/index.html').existsSync(), isTrue);
      expect(
        File('assets/avatar/three.min.js').lengthSync(),
        669884,
        reason: 'three.js r160, UMD, unverändert aus der Verhaltensquelle.',
      );
      expect(File('assets/avatar/tourist-character.js').lengthSync(), 30893);
    });

    test('die Lizenz liegt daneben', () {
      // Dieselbe Ablage wie bei den Schriften: die Lizenz liegt neben dem
      // Gegenstand, den sie deckt.
      final File license = File('assets/avatar/LICENSE-three.js.txt');
      expect(license.existsSync(), isTrue);
      expect(license.readAsStringSync(), contains('MIT'));
    });
  });
}
