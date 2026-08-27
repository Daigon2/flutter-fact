/// Wer gerade angemeldet ist, als Wertobjekt.
///
/// ## Was hier bewusst **nicht** drinsteht: das Token
///
/// Kein Access-Token, kein Refresh-Token, kein Ablaufzeitpunkt. Zwei Gründe,
/// beide tragend:
///
/// 1. **Zustand wird ausgegeben.** Ein Provider-Observer, ein Fehlerbericht
///    oder ein `toString()` in einer Log-Zeile macht aus jedem Feld im
///    Riverpod-Zustand eine potenzielle Ausgabe.
///    `docs/architecture/cross-cutting-concerns.md` verbietet Tokens in Logs,
///    und die einzige Fassung dieser Regel, die man nicht versehentlich brechen
///    kann, ist: das Token kommt nie in den Zustand.
/// 2. **Niemand hier braucht es.** Das Token gehört dem Supabase-Client, der es
///    selbst hält und erneuert. Die Oberfläche braucht nur die Antwort auf
///    "ist jemand angemeldet, und wer".
///
/// ## Warum Wertgleichheit, und warum das mehr ist als Bequemlichkeit
///
/// `onAuthStateChange` feuert nicht nur bei An- und Abmeldung, sondern auch bei
/// `initialSession`, `tokenRefreshed` und `userUpdated`, jedes Mal mit
/// derselben Kennung. Der Router hängt über `ref.listen` an diesem Zustand und
/// ruft bei jeder Änderung `router.refresh()`. Ohne `==` wäre jede
/// Token-Erneuerung eine Neuauswertung der Weiche, also im Stundenrhythmus
/// dauerhaft und ohne Anlass. Riverpod vergleicht mit `==`, bevor es Listener
/// benachrichtigt; deshalb ist dieses `==` die Stelle, an der das Gewitter
/// aufhört.
///
/// Ein Test sichert genau das zu, weil der Fehler sonst unsichtbar wäre: eine
/// überflüssige `refresh()` verändert nichts Sichtbares.
final class AuthSession {
  const AuthSession._(this.userId);

  /// Niemand ist angemeldet. Auch der Ausgangszustand.
  const AuthSession.signedOut() : this._(null);

  /// [userId] ist die Supabase-Nutzerkennung (`auth.users.id`), eine UUID.
  const AuthSession.signedIn({required String userId}) : this._(userId);

  /// Kennung des angemeldeten Nutzers, oder `null`, wenn niemand angemeldet
  /// ist.
  ///
  /// Eine UUID, kein Anzeigename und keine E-Mail-Adresse. Wer Profildaten
  /// braucht, lädt sie über das Profil-Feature, sobald es existiert.
  final String? userId;

  /// Ob jemand angemeldet ist.
  ///
  /// Genau `userId != null`. Kein zweites Feld, das dazu im Widerspruch stehen
  /// könnte.
  bool get isSignedIn => userId != null;

  /// Enthält bewusst kein Token, weil dieser Typ keines trägt.
  ///
  /// Die Kennung steht drin: sie ist pseudonym, für die Diagnose nötig und
  /// nach `cross-cutting-concerns.md` kein verbotener Inhalt.
  @override
  String toString() =>
      'AuthSession(${isSignedIn ? 'signedIn, $userId' : 'signedOut'})';

  @override
  bool operator ==(Object other) =>
      other is AuthSession && other.userId == userId;

  @override
  int get hashCode => userId.hashCode;
}
