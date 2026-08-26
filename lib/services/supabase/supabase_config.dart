/// Umgebungskonfiguration des Supabase-Zugangs.
///
/// Beide Werte kommen von außen über `--dart-define` und stehen **nie** im
/// Quelltext. `docs/engineering/security.md` §2 verbietet zwar nur Secrets im
/// Repository, und der publizierbare Schlüssel ist laut §2 ausdrücklich keine
/// Autorisierung. Trotzdem ist er Umgebungskonfiguration: er unterscheidet
/// Projekt, Stage und Produktion. Ein einbetonierter Wert wäre also nicht nur
/// eine Sicherheitsfrage, sondern ein Deploy-Fehler mit Ansage.
///
/// Setzen (beide Werte, sonst bricht der Start mit einer klaren Meldung ab):
///
/// ```text
/// C:\flutter-fresh\bin\flutter run ^
///   --dart-define=SUPABASE_URL=https://<projekt>.supabase.co ^
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_<rest>
/// ```
///
/// Dieselben beiden Argumente gelten für `flutter build apk`,
/// `flutter build ipa` und `flutter test`. Wer viele Ziele baut, legt die
/// Werte in eine JSON-Datei und nutzt `--dart-define-from-file=env.json`.
/// Diese Datei gehört nicht ins Repository.
library;

/// URL und publizierbarer Schlüssel des Supabase-Projekts.
class SupabaseConfig {
  /// Direkte Angabe, hauptsächlich für Tests.
  const SupabaseConfig({required this.url, required this.publishableKey});

  /// Name der `--dart-define`-Variable für die Projekt-URL.
  static const String urlVariable = 'SUPABASE_URL';

  /// Name der `--dart-define`-Variable für den publizierbaren Schlüssel.
  static const String publishableKeyVariable = 'SUPABASE_PUBLISHABLE_KEY';

  /// Erkennbarer Platzhalter, wenn `--dart-define` fehlt.
  ///
  /// Absichtlich kein leerer String: eine leere Zeichenkette sieht in einem
  /// Log wie ein Tippfehler aus, dieser Wert wie eine Diagnose.
  static const String missingValue = 'NICHT_GESETZT';

  /// Konfiguration aus den `--dart-define`-Werten des Builds.
  static const SupabaseConfig fromEnvironment = SupabaseConfig(
    url: String.fromEnvironment(urlVariable, defaultValue: missingValue),
    publishableKey: String.fromEnvironment(
      publishableKeyVariable,
      defaultValue: missingValue,
    ),
  );

  /// Basis-URL des Projekts, etwa `https://abcdefgh.supabase.co`.
  final String url;

  /// Publizierbarer Schlüssel (`sb_publishable_…`).
  ///
  /// Kein Geheimnis im Sinne von `security.md` §2, aber auch kein Wert, der in
  /// eine Log-Zeile gehört. Siehe [toString].
  final String publishableKey;

  /// Ist die Konfiguration brauchbar?
  ///
  /// Geprüft wird nur, was ohne Netz prüfbar ist: beide Werte gesetzt, die URL
  /// absolut und über HTTPS erreichbar. Ob das Projekt existiert, weiß erst
  /// der erste Aufruf.
  bool get isUsable => missingRequirements.isEmpty;

  /// Was an der Konfiguration fehlt, als lesbare Liste.
  ///
  /// Leer heißt brauchbar. Die Texte sind technische Diagnosen für Entwickler
  /// und keine Oberflächentexte, deshalb stehen sie hier und nicht in `i18n`.
  List<String> get missingRequirements {
    final problems = <String>[];
    if (url.isEmpty || url == missingValue) {
      problems.add('$urlVariable ist nicht gesetzt');
    } else {
      final parsed = Uri.tryParse(url);
      if (parsed == null || !parsed.isAbsolute || parsed.scheme != 'https') {
        problems.add('$urlVariable ist keine absolute https-URL');
      }
    }
    if (publishableKey.isEmpty || publishableKey == missingValue) {
      problems.add('$publishableKeyVariable ist nicht gesetzt');
    }
    return List<String>.unmodifiable(problems);
  }

  /// Wirft [SupabaseConfigurationError], wenn die Konfiguration unbrauchbar ist.
  ///
  /// Gedacht für den Start: lieber sofort mit einer verständlichen Meldung
  /// abbrechen als später mit einem Netzwerkfehler, dessen Ursache niemand
  /// sieht.
  void ensureUsable() {
    final problems = missingRequirements;
    if (problems.isNotEmpty) {
      throw SupabaseConfigurationError(problems);
    }
  }

  /// Redigiert den Schlüssel.
  ///
  /// Absichtlich keine Ausgabe des Schlüssels, auch nicht gekürzt.
  /// `cross-cutting-concerns.md` verlangt, dass Zugangsdaten nicht in Logs
  /// landen, und `toString()` landet erfahrungsgemäß überall.
  @override
  String toString() =>
      'SupabaseConfig(url: $url, '
      '$publishableKeyVariable: '
      '${publishableKey.isEmpty || publishableKey == missingValue ? 'fehlt' : 'gesetzt'})';

  @override
  bool operator ==(Object other) =>
      other is SupabaseConfig &&
      other.url == url &&
      other.publishableKey == publishableKey;

  @override
  int get hashCode => Object.hash(url, publishableKey);
}

/// Der Start hat keine brauchbare Supabase-Konfiguration bekommen.
class SupabaseConfigurationError extends Error {
  /// [problems] listet auf, was fehlt.
  SupabaseConfigurationError(List<String> problems)
    : problems = List<String>.unmodifiable(problems);

  /// Die einzelnen Mängel, in Lesereihenfolge.
  final List<String> problems;

  @override
  String toString() =>
      'Supabase ist nicht konfiguriert: ${problems.join(', ')}. '
      'Beide Werte über --dart-define setzen, zum Beispiel: '
      'flutter run '
      '--dart-define=${SupabaseConfig.urlVariable}=https://<projekt>.supabase.co '
      '--dart-define=${SupabaseConfig.publishableKeyVariable}=sb_publishable_<rest>';
}
