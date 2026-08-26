/// Erwartete Fehlschläge beim Lesen von Fakten.
///
/// Abgegrenzt gegen `FactImportReport`: **Datenmängel** sind kein Fehlschlag,
/// sie degradieren einzelne Fakten und stehen im Bericht. Hier stehen nur die
/// Fälle, in denen es überhaupt keine Antwort gab.
///
/// Diese Typen tragen bewusst **keine** Vendor-Objekte. Eine
/// `PostgrestException` darf die Datenschicht nicht verlassen
/// (`api-and-domain-design.md`: „Do not expose vendor SDK types outside
/// adapters"). Übrig bleiben ein Diagnosecode und, bei Unerwartetem, der
/// Stacktrace.
///
/// Ebenso bewusst **kein** Oberflächentext. `data-flow.md` §5: „domain failures
/// contain no localized text." Welcher Satz dem Nutzer gezeigt wird, entscheidet
/// die Präsentation über `AppStrings`.
library;

/// Basis aller erwarteten Fehlschläge dieser Domäne.
///
/// `implements Exception`, weil der Vertrag wirft statt einen `Result`-Typ zu
/// liefern. Die Begründung steht in `FactBatch`.
sealed class FactFailure implements Exception {
  /// [code] ist ein technischer Diagnosecode, wenn das Backend einen geliefert
  /// hat, etwa ein SQLSTATE oder ein PostgREST-Code.
  const FactFailure({this.code, this.stackTrace});

  /// Technischer Code, falls vorhanden. Nie ein Oberflächentext.
  final String? code;

  /// Stacktrace der Ursache, wo einer sinnvoll ist.
  final StackTrace? stackTrace;

  /// Kurzname für Diagnose und Tests.
  String get kind;

  @override
  String toString() => 'FactFailure($kind${code == null ? '' : ', $code'})';
}

/// Das Backend hat den Zugriff verweigert.
///
/// Deckt abgelaufene oder fehlende Anmeldung und abgelehnte RLS-Policies. Für
/// `facts` ist das erklärungsbedürftig, denn die Policy „read facts" erlaubt
/// jedem das Lesen freigegebener Fakten. Tritt dieser Fall auf, stimmt etwas an
/// der Sitzung oder an der Policy nicht.
final class FactAccessDenied extends FactFailure {
  /// Siehe [FactFailure].
  const FactAccessDenied({super.code, super.stackTrace});

  @override
  String get kind => 'accessDenied';
}

/// Das Backend hat die Anfrage abgelehnt.
///
/// Falsche Spalte, falscher Filter, verschobenes Schema. Ein Wiederholen hilft
/// nicht, das ist ein Fehler auf der Client-Seite.
final class FactRequestRejected extends FactFailure {
  /// Siehe [FactFailure].
  const FactRequestRejected({super.code, super.stackTrace});

  @override
  String get kind => 'requestRejected';
}

/// Es kam gar keine brauchbare Antwort.
///
/// Deckt kein Netz, Zeitüberschreitung, Fehler auf Serverseite und alles, was
/// die Datenschicht nicht genauer unterscheiden kann.
///
/// Warum nicht feiner: „offline" von „Server kaputt" zu trennen bräuchte ein
/// Konnektivitätssignal, und ein Paket dafür (`connectivity_plus`) ist eine
/// Entscheidung der Stufe 3. Zu raten wäre schlechter als es offen zu lassen,
/// weil die Präsentation daraus eine Handlungsempfehlung ableitet.
final class FactBackendUnreachable extends FactFailure {
  /// Siehe [FactFailure].
  const FactBackendUnreachable({super.code, super.stackTrace});

  @override
  String get kind => 'backendUnreachable';
}
