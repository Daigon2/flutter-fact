/// Der Vertrag für kurze Klänge. Schritt 26.
///
/// ## Warum das nicht der Sprachdienst ist
///
/// Weil es ein anderes Vendor-Paket ist und eine andere Aufgabe. `flutter_tts`
/// spricht Text, `audioplayers` spielt eine Datei. Beides in einen Vertrag zu
/// legen hieße, zwei Heimatverzeichnisse in eines zu ziehen und einer
/// künftigen Cloud-Sprachausgabe die Tonwiedergabe mitzugeben, die sie nicht
/// hat. Der Sprachdienst begründet an seinem Vertrag ausführlich, warum er
/// anbieterneutral bleibt; dasselbe gilt hier.
///
/// ## Was er kann, und was ausdrücklich nicht
///
/// **Einen kurzen Klang abspielen, mit Stereo-Verteilung.** Das ist alles, was
/// die Quelle tut: `AudioPlayer.playBeacon` lädt `assets/beacon.mp3` einmal,
/// hängt bei eingeschaltetem Kopfhörer-Modus einen `StereoPanner` davor und
/// startet ihn (`02_Frontend/app/audio-player.jsx:104-135`, `:330-340`).
///
/// **Kein Anhalten, kein Fortsetzen, kein Zustand.** Ein Hinweiston ist nach
/// einem Augenblick vorbei; die Quelle hält für ihn keinen Zustand und bietet
/// keine Bedienung. Wer später Musik oder einen vorproduzierten Fakt-Ton
/// abspielen will, braucht mehr, und dann ist das ein zweiter Vertrag oder
/// eine begründete Erweiterung dieses. **Auf Vorrat gebaut wird hier nichts**
/// (ADR-002).
///
/// **Keine Warteschlange.** Zwei Töne kurz hintereinander gibt es nicht: der
/// Auslöser in Schritt 26 lässt höchstens einen Ton je fünf Sekunden durch.
library;

/// Woher die App kurze Klänge bekommt.
///
/// `abstract interface class`, wie die drei Gerätedienste davor: ein
/// versehentliches `extends` geht damit nicht durch, und jeder Doppelgänger
/// im Test schreibt sichtbar `implements ToneService`.
abstract interface class ToneService {
  /// Spielt den Klang unter [assetPath] ab.
  ///
  /// [assetPath] ist ein Pfad in `pubspec.yaml` unter `assets:`, ohne
  /// führendes `assets/`, weil `audioplayers` seinen eigenen Präfix davor
  /// setzt. Der Adapter dokumentiert das an seiner Umsetzung.
  ///
  /// [balance] verteilt zwischen den Kanälen: `-1` ganz links, `0` mittig,
  /// `1` ganz rechts. Der Standard ist mittig, und **das ist auch der
  /// Normalfall**: die Quelle verteilt nur bei eingeschaltetem
  /// Kopfhörer-Modus, und den gibt es im Neubau noch nicht (E-71).
  ///
  /// **Wirft nicht.** Ein Klang, der nicht kommt, darf den Bildschirm nicht
  /// mitnehmen; dieselbe Zusage wie beim Sprachdienst und dieselbe
  /// Begründung. Die Quelle macht es genauso, mit `console.warn` und weiter
  /// (`audio-player.jsx:114-116`).
  Future<void> playTone(String assetPath, {double balance});
}

/// Der untätige Standard: eine Wiedergabe, die still bleibt.
///
/// Dasselbe Muster wie `unavailableSpeechService` und
/// `unavailableLocationService`, und aus demselben Grund: der Standard eines
/// Providers muss ohne Plattformkanal auskommen, sonst fällt jeder
/// Widget-Test über eine `MissingPluginException`. Die echte Fassung setzt
/// `lib/app/bootstrap.dart` per Override ein.
const ToneService unavailableToneService = _UnavailableToneService();

final class _UnavailableToneService implements ToneService {
  const _UnavailableToneService();

  @override
  Future<void> playTone(String assetPath, {double balance = 0}) async {}
}
