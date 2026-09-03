/// Die Vorlesefassung eines Fakts. Schritt 25.
///
/// ## Warum in `domain/` und nicht neben `factSourcesOf`
///
/// `features/facts/presentation/fact_sources.dart` macht etwas sehr Ähnliches
/// und liegt in der Presentation. Hier geht das nicht: den Vorlesetext braucht
/// ab Schritt 26 auch `features/discovery`, und Regel 8 verbietet jedem
/// Feature den Import aus dem `presentation` eines anderen. Reines Dart auf
/// einem Wertobjekt, also gehört es in die Domäne.
library;

import 'package:fact_app/features/facts/domain/fact_prose.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';

/// Wie die Textteile im Vortrag getrennt werden, `parts.join('. ')` in
/// `02_Frontend/app/audio-player.jsx:69`.
///
/// Ein Punkt und ein Leerzeichen, und nicht bloß ein Leerzeichen: der Punkt
/// setzt beim Sprecher die Satzpause. Ohne ihn liest die Sprachausgabe die
/// Überschrift in den ersten Satz hinein.
const String spokenFactTextSeparator = '. ';

/// Der Text, den die Sprachausgabe vorliest.
///
/// Die Reihenfolge ist die der Quelle (`buildFullText`,
/// `audio-player.jsx:63-70`): Titel, dann die vier Textfelder in ihrer
/// Nummerierung.
///
/// ## Zwei Abweichungen von der Quelle, beide gemessene Defekte
///
/// **1. Ein fehlender Titel wird nicht mitgesprochen.** Die Quelle legt
/// `fact.titel` **bedingungslos** in die Liste (`const parts = [fact.titel]`,
/// `:64`) und prüft erst die vier Textfelder auf Inhalt. Bei einem Fakt ohne
/// Titel liest die Sprachausgabe deshalb wörtlich „undefined" vor, und weil
/// `join` danach noch einen Punkt setzt, auch noch als eigenen Satz.
/// `FactText.title` ist im Neubau nullfähig, und ein leerer Teil fällt hier
/// heraus wie jeder andere.
///
/// **2. Die Zitat-Hochziffern werden entfernt.** Sie stehen im Text als
/// `[3]` (siehe `cited_text.dart`), und die Quelle schickt den Rohtext an den
/// Sprecher. Was daraus wird, entscheidet die Sprachausgabe des Geräts, und
/// keine der Möglichkeiten ist brauchbar: „Der Turm **drei** wurde" oder „Der
/// Turm **Klammer auf drei Klammer zu** wurde".
///
/// **Das ist kein Schönheitsfehler, sondern trifft den Zweck der Funktion.**
/// Der Audio-Modus ist laut `audio.dialog.body` für blinde und sehbehinderte
/// Nutzer gebaut; für sie ist der Vortrag nicht die Beigabe zum Text, sondern
/// der Text. Eine Quellenangabe, die als Zahl mitten in den Satz fällt, ist
/// dort genau der Unterschied zwischen lesbar und nicht.
///
/// Es braucht dafür keine Wortlaut-Entscheidung: es wird nichts erfunden,
/// sondern etwas weggelassen, das nicht zum Sprechen gedacht war. Aufgenommen
/// als Fund an der Quelle.
///
/// **Das Entfernen selbst liegt seit Schritt 47 in `fact_prose.dart`**, weil
/// der Lesemodus des Reiseführers denselben Text braucht und aus demselben
/// Grund: dort steht die Hochziffer ebenfalls ohne Quellenliste daneben.
String spokenFactText(FactText content) {
  final List<String> parts = <String>[];
  for (final String? part in <String?>[
    content.title,
    content.body,
    content.bodyExtra,
    content.bodyBackground,
    content.bodyToday,
  ]) {
    final String spoken = factTextWithoutReferences(part);
    if (spoken.isNotEmpty) {
      parts.add(spoken);
    }
  }
  return parts.join(spokenFactTextSeparator);
}
