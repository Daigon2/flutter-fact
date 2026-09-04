/// Die JavaScript-Aufrufe, mit denen Flutter die Figur im WebView stellt.
///
/// ## Warum das Zeichenketten baut und nicht selbst aufruft
///
/// Weil hier die Fehler wohnen, die man einer laufenden App nicht ansieht. Ein
/// Aufruf an eine Funktion, die es nicht gibt, wirft im WebView eine Ausnahme,
/// die auf der Flutter-Seite **nirgends** ankommt: `runJavaScript` gibt kein
/// Ergebnis zurück und meldet keinen Fehler des Skripts. Die Figur bleibt dann
/// stehen, und niemand erfährt, warum.
///
/// Getrennt gebaut ist der Aufruf eine Zeichenkette, und eine Zeichenkette
/// kann ein Test lesen. Geprüft wird damit genau das, was sonst nur ein Gerät
/// beantwortet: heißt die Funktion so, wie `index.html` sie anlegt, steht die
/// Wache davor, und kommt der richtige Wert an.
///
/// ## Die Wache `window.FactAvatar &&` ist nicht Vorsicht, sondern Zeitpunkt
///
/// `onPageFinished` kommt, wenn das Dokument geladen ist. `FactAvatar` entsteht
/// aber im `load`-Ereignis der Seite, und `three.min.js` sind 670 Kilobyte, die
/// erst geparst werden müssen. Zwischen beiden liegt ein Fenster, in dem ein
/// Aufruf ins Leere geht. Die Wache macht daraus ein stilles Nichts statt einer
/// Ausnahme, und der nächste Aufruf trifft.
///
/// Dieselbe Bauform wie im eingefrorenen Port
/// (`08_Flutter/lib/widgets/tourist_3d.dart:53-58`), dort ohne Erklärung.
///
/// ## Kein Wert kommt von außen
///
/// Beide Funktionen nehmen einen `enum` und keine Zeichenkette. Damit kann
/// nichts eingeschleust werden, und die Frage nach dem Maskieren stellt sich
/// nicht: es gibt keinen Aufrufer, der einen freien Text übergeben könnte. Wer
/// das ändert, muss hier maskieren, und dieser Satz ist der Grund, aus dem er
/// es merkt.
library;

import 'package:fact_app/map/presentation/avatar/avatar_motion.dart';

/// Der Name der Schnittstelle, die `assets/avatar/index.html` anlegt.
///
/// Steht als Konstante hier, damit ein Umbenennen in der HTML-Datei diese
/// Datei bricht und nicht die Figur.
const String avatarBridgeName = 'FactAvatar';

/// Setzt die Animation auf [animation].
String avatarSetAnimationScript(AvatarAnimation animation) =>
    'window.$avatarBridgeName && '
    "$avatarBridgeName.setAnim('${animation.jsName}');";

/// Setzt die Figur auf [gender].
///
/// Das setzt die Szene neu auf, weil die Figur zwei getrennte Modelle hat.
/// Deshalb nicht je Bild aufrufen, sondern nur bei einer Änderung.
String avatarSetGenderScript(AvatarGender gender) =>
    'window.$avatarBridgeName && '
    "$avatarBridgeName.setGender('${gender.jsName}');";

/// Fragt, ob die Szene steht.
///
/// Gibt `false` zurück, solange es die Schnittstelle noch nicht gibt, und
/// nicht `undefined`: der Aufrufer soll eine Antwort bekommen und keine
/// Fallunterscheidung über JavaScript-Typen führen.
const String avatarIsReadyScript =
    'window.$avatarBridgeName ? '
    '$avatarBridgeName.isReady() : false';

/// Welche Aufrufe hinausgehen müssen, damit die Figur [animation] und [gender]
/// zeigt.
///
/// [sentAnimation] und [sentGender] sind, was zuletzt geschickt wurde, `null`,
/// wenn noch nichts. [isReady] ist `false`, solange die Seite nicht geladen
/// ist.
///
/// ## Warum das eine Funktion ist und keine drei `if` im Widget
///
/// Weil hier der teure Fehler wohnt. `setGender` **setzt die Szene neu auf**:
/// die Figur hat zwei getrennte Modelle, und ein Wechsel wirft das alte weg
/// und baut das neue. Ein Widget, das den Aufruf je Bildaufbau schickt, baut
/// die Figur sechzigmal je Sekunde neu. Das sieht man als Flackern, es kostet
/// Akku, und es fällt in keinem Test auf, der nur prüft, dass die Figur da
/// ist.
///
/// Als Funktion über zwei Paare von Werten ist es eine Zusicherung: **nur was
/// sich geändert hat, geht hinaus.**
///
/// ## Die Reihenfolge: erst die Fassung, dann die Animation
///
/// Sie ist heute ohne Wirkung und steht trotzdem fest. `setGender` in
/// `index.html` baut mit der gemerkten Animation neu auf, die Animation
/// überlebt den Wechsel also. Wer die HTML-Datei einmal anders schreibt, hätte
/// bei umgekehrter Reihenfolge eine Figur, die nach dem Fassungswechsel steht,
/// obwohl sie laufen soll. Eine festgelegte Reihenfolge kostet nichts und
/// nimmt diesen Fall vorweg.
///
/// ## Nichts geht hinaus, solange die Seite nicht geladen ist
///
/// Und zwar **gar nichts**, nicht einmal mit der Wache davor. Der Grund ist
/// nicht Sicherheit, sondern Buchführung: würde hier gesendet, müsste der
/// Aufrufer den Wert als „geschickt" merken, obwohl er nirgends angekommen
/// ist, und der erste echte Aufruf nach dem Laden fiele als „unverändert"
/// heraus. Die Figur bliebe stehen.
List<String> avatarScriptsToSend({
  required bool isReady,
  required AvatarAnimation animation,
  required AvatarGender gender,
  AvatarAnimation? sentAnimation,
  AvatarGender? sentGender,
}) {
  if (!isReady) {
    return const <String>[];
  }
  return <String>[
    if (gender != sentGender) avatarSetGenderScript(gender),
    if (animation != sentAnimation) avatarSetAnimationScript(animation),
  ];
}
