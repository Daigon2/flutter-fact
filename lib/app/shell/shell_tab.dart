/// Die vier Tabs der App-Shell, in der Reihenfolge der PWA.
///
/// Quelle ist `02_Frontend/app/chrome.jsx:55-60`:
///
/// ```jsx
/// const tabs = [
///   { id: 'modus',     label: t('tab.map',       lang), icon: Icon.tabModus },
///   { id: 'wallet',    label: t('tab.facts',     lang), icon: Icon.tabWallet },
///   { id: 'challenge', label: t('tab.challenge', lang), icon: Icon.tabChallenge, badge: showBadge },
///   { id: 'profil',    label: t('tab.profil',    lang), icon: Icon.tabProfil },
/// ];
/// ```
///
/// Es sind genau vier. `ModeBar` in derselben Datei (`chrome.jsx:150-207`) ist
/// **keine** fünfte Tab-Leiste, sondern der Modus-Umschalter innerhalb des
/// Karten-Bildschirms zwischen "Entdecken" und "Challenge". Deshalb steht
/// `tab.entdecken` hier nicht.
///
/// ## Reihenfolge ist ein Vertrag
///
/// `AppShell` bildet `StatefulNavigationShell.currentIndex` direkt auf
/// `values` ab. Die Zweige in `app/routing/app_routes.dart` stehen in genau
/// dieser Reihenfolge. Wer hier etwas einschiebt, muss dort mitziehen;
/// `AppShell` prüft die Länge zur Laufzeit per `assert`.
library;

import 'package:fact_app/core/anchors/anchor_id.dart';

/// Ein Eintrag der schwebenden Tab-Leiste.
enum ShellTab {
  /// `modus` in der PWA, Karte. Besitzende Domäne: Discovery.
  map('tab.map', AnchorId('tab-modus')),

  /// `wallet` in der PWA, gesammelte Fakten. Besitzende Domäne: Collection.
  collection('tab.facts', AnchorId('tab-wallet')),

  /// `challenge` in der PWA. Besitzende Domäne: Challenges.
  challenges('tab.challenge', AnchorId('tab-challenge')),

  /// `profil` in der PWA. Besitzende Domäne: Profile.
  profile('tab.profil', AnchorId('tab-profil'));

  const ShellTab(this.labelKey, this.anchorId);

  /// Schlüssel der Beschriftung in `AppStrings`, identisch mit dem der PWA.
  ///
  /// Absichtlich der Schlüssel und nicht der fertige Text: die Leiste muss
  /// einem Sprachwechsel folgen, und ein hier eingefrorener deutscher oder
  /// englischer String täte das nicht.
  final String labelKey;

  /// Kennung dieses Tabs als Anker, für Overlays, die auf ihn zeigen.
  ///
  /// **Der Name folgt der PWA, nicht unserem Enum.** `chrome.jsx:88` setzt
  /// `data-tour-anchor={'tab-' + t.id}`, und die Tab-Kennungen dort sind
  /// `modus`, `wallet`, `challenge` und `profil`. Die Anker heißen deshalb
  /// `tab-modus` und `tab-wallet`, **nicht** `tab-map` und `tab-collection`.
  ///
  /// Das ist bewusst die eine Stelle, an der die PWA-Bezeichner überleben. Die
  /// Routen gehen den anderen Weg und tragen die Domänennamen (E-25:
  /// `/map`, `/collection`, `/challenges`, `/profile`). Der Grund für den
  /// Unterschied: ein Pfad ist ein Vertrag mit dem Nutzer und mit Deep Links,
  /// eine Ankerkennung ist ein Vertrag mit der Quelle, gegen die die Parität
  /// geprüft wird. Wer sie hier umbenennt, muss beim nächsten Abgleich mit
  /// `screen-tour.jsx` raten.
  ///
  /// Von den vieren fragt das Tutorial heute genau zwei ab, `tab-wallet` in
  /// Schritt 5 und `tab-challenge` in Schritt 7 (`screen-tour.jsx:156` und
  /// `:162`). Angemeldet werden trotzdem alle vier: die Leiste zeichnet sie
  /// ohnehin alle gleich, und eine Ausnahme für zwei davon wäre eine
  /// Sonderregel ohne Nutzen.
  final AnchorId anchorId;
}
