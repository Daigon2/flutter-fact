/// Erwartete Fehlschläge der Anmeldung.
///
/// Aufgebaut wie `FactFailure` in `features/facts`, aus denselben Gründen:
///
/// * **Keine Vendor-Objekte.** Eine `AuthException` verlässt die Datenschicht
///   nicht (`api-and-domain-design.md`: "Do not expose vendor SDK types outside
///   adapters").
/// * **Kein Oberflächentext.** `data-flow.md` §5: "domain failures contain no
///   localized text." Welcher Satz erscheint, entscheidet
///   `presentation/formatting/auth_failure_text.dart`.
/// * **Nicht die Meldung des Backends.** `cross-cutting-concerns.md`:
///   "Sensitive backend details are never shown to users." Übrig bleiben ein
///   technischer [AuthFailure.code] und die Stapelspur.
///
/// ## Geworfen, nicht als `Result` geliefert
///
/// `implements Exception` und ein `throw` im Vertrag, genau wie bei
/// `FactFailure`. Ein `Result`-Typ wäre die andere vertretbare Wahl, aber die
/// Auswahl einer Result-Bibliothek ist eine offene Entscheidung, und dieser
/// Schritt nimmt sie nicht vorweg.
///
/// **Folge, die man kennen muss:** "Zugangsdaten falsch" ist ein *erwarteter*
/// Ausgang der Anmeldung und landet trotzdem in `AsyncError`. Ein `AsyncError`
/// heißt hier also nicht "etwas ist kaputt", sondern "die Anmeldung ist nicht
/// zustande gekommen". Wer diese Zustände auswertet, darf daraus keine
/// Absturzmeldung machen.
library;

/// Basis aller erwarteten Fehlschläge der Anmeldung.
sealed class AuthFailure implements Exception {
  /// [code] ist ein technischer Diagnosecode, wenn das Backend einen geliefert
  /// hat, etwa `invalid_credentials` oder ein HTTP-Status.
  const AuthFailure({this.code, this.stackTrace});

  /// Technischer Code, falls vorhanden. Nie ein Oberflächentext.
  final String? code;

  /// Stapelspur der Ursache, wo eine sinnvoll ist.
  final StackTrace? stackTrace;

  /// Kurzname für Diagnose und Tests.
  String get kind;

  @override
  String toString() => 'AuthFailure($kind${code == null ? '' : ', $code'})';
}

/// E-Mail-Adresse oder Passwort passen nicht.
///
/// Absichtlich **nicht** getrennt in "Konto existiert nicht" und "Passwort
/// falsch". Supabase trennt das ebenfalls nicht, und das ist richtig: die
/// Unterscheidung wäre eine Auskunft darüber, welche Adressen ein Konto haben.
final class AuthInvalidCredentials extends AuthFailure {
  /// Siehe [AuthFailure].
  const AuthInvalidCredentials({super.code, super.stackTrace});

  @override
  String get kind => 'invalidCredentials';
}

/// Das Konto existiert, die E-Mail-Adresse ist aber noch nicht bestätigt.
final class AuthEmailNotConfirmed extends AuthFailure {
  /// Siehe [AuthFailure].
  const AuthEmailNotConfirmed({super.code, super.stackTrace});

  @override
  String get kind => 'emailNotConfirmed';
}

/// Das Backend hat geantwortet und die Anfrage abgelehnt.
///
/// Deckt alles, was eine Antwort hatte, aber keiner der beiden Fälle oben ist:
/// Ratenbegrenzung, abgeschaltete Anmeldeart, fehlgeschlagene Captcha-Prüfung,
/// Validierungsfehler des Servers. Ein Wiederholen hilft meistens nicht.
final class AuthRequestRejected extends AuthFailure {
  /// Siehe [AuthFailure].
  const AuthRequestRejected({super.code, super.stackTrace});

  @override
  String get kind => 'requestRejected';
}

/// Es kam gar keine brauchbare Antwort.
///
/// Kein Netz, Zeitüberschreitung, Serverfehler, und der Fall "es gibt hier
/// überhaupt keine Anmeldung", siehe `unavailableAuthRepository` in
/// `domain/repositories/auth_repository.dart`.
///
/// Warum nicht feiner: "offline" von "Server kaputt" zu trennen bräuchte ein
/// Konnektivitätssignal, und ein Paket dafür ist eine Entscheidung der Stufe 3.
/// Dieselbe Begründung wie bei `FactBackendUnreachable`.
final class AuthBackendUnavailable extends AuthFailure {
  /// Siehe [AuthFailure].
  const AuthBackendUnavailable({super.code, super.stackTrace});

  @override
  String get kind => 'backendUnavailable';
}
