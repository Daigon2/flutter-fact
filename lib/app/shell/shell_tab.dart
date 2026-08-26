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

/// Ein Eintrag der schwebenden Tab-Leiste.
enum ShellTab {
  /// `modus` in der PWA, Karte. Besitzende Domäne: Discovery.
  map('tab.map'),

  /// `wallet` in der PWA, gesammelte Fakten. Besitzende Domäne: Collection.
  collection('tab.facts'),

  /// `challenge` in der PWA. Besitzende Domäne: Challenges.
  challenges('tab.challenge'),

  /// `profil` in der PWA. Besitzende Domäne: Profile.
  profile('tab.profil');

  const ShellTab(this.labelKey);

  /// Schlüssel der Beschriftung in `AppStrings`, identisch mit dem der PWA.
  ///
  /// Absichtlich der Schlüssel und nicht der fertige Text: die Leiste muss
  /// einem Sprachwechsel folgen, und ein hier eingefrorener deutscher oder
  /// englischer String täte das nicht.
  final String labelKey;
}
