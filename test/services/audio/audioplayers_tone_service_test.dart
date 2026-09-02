import 'package:audioplayers/audioplayers.dart';
import 'package:fact_app/services/audio/audioplayers_tone_service.dart';
import 'package:fact_app/services/audio/tone_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Adapter auf `audioplayers`.
///
/// **Der Doppelgänger `implements` statt `extends`, und das ist keine
/// Vorliebe.** Der Konstruktor von `AudioPlayer` ruft `_create()` und greift
/// damit auf den Plattformkanal zu (`audioplayer.dart:150-174`); ein
/// `extends` liefe durch genau diesen Konstruktor. Mit `implements` und
/// `noSuchMethod` entsteht keine Zeile davon. Der Preis ist, dass jeder
/// Aufruf außer den zweien unten in eine `NoSuchMethodError` läuft, und das
/// ist der richtige Preis: er zeigt sofort, wenn der Adapter mehr benutzt,
/// als hier geprüft ist.
void main() {
  late _FakeAudioPlayer player;
  late AudioplayersToneService service;

  setUp(() {
    player = _FakeAudioPlayer();
    service = AudioplayersToneService(player: player);
  });

  group('abspielen', () {
    test('gibt den Pfad ohne führendes assets/ weiter', () async {
      // `AssetSource('audio/beacon.mp3')` landet bei
      // `assets/audio/beacon.mp3`, weil `AudioCache` einen Präfix davorsetzt,
      // dessen Standard `'assets/'` ist. Wer den Präfix mitschreibt, sucht
      // unter `assets/assets/...` und findet nichts.
      await service.playTone('audio/beacon.mp3');

      expect(player.playedPaths, <String>['audio/beacon.mp3']);
    });

    test('reicht die Stereo-Verteilung durch', () async {
      await service.playTone('audio/beacon.mp3', balance: -0.5);

      expect(player.balances, <double?>[-0.5]);
    });

    test('ohne Angabe klingt es mittig', () async {
      // Der Normalfall: der Kopfhörer-Modus der Quelle fehlt im Neubau
      // (E-71), und ohne ihn verteilt auch sie nicht.
      await service.playTone('audio/beacon.mp3');

      expect(player.balances, <double?>[0]);
    });
  });

  group('ein Plattformkanal, der scheitert', () {
    test('nimmt den Aufrufer nicht mit', () async {
      // Der Vertrag verspricht, dass nichts wirft. Ein Hinweiston, der nicht
      // kommt, ist kein Grund, den Bildschirm abzubrechen.
      player.failWith = Exception('kein Kanal');

      await expectLater(service.playTone('audio/beacon.mp3'), completes);
    });

    test('auch ein Error und nicht nur eine Exception', () async {
      // Dieselbe Begründung wie im Sprachdienst: eine fehlende Datei kommt
      // als `Exception`, ein Plattformfehler auf Android als beliebiger
      // `Error`. Deshalb fängt der Adapter `Object`.
      player.failWith = StateError('kaputt');

      await expectLater(service.playTone('audio/beacon.mp3'), completes);
    });
  });

  group('aufräumen', () {
    test('gibt den Spieler frei', () async {
      await service.dispose();

      expect(player.disposed, isTrue);
    });

    test('ohne einen einzigen Ton legt es keinen Spieler an', () async {
      // **Der Spieler entsteht erst beim ersten Ton**, siehe den Kopf
      // des Adapters: sein Konstruktor greift sofort auf den
      // Plattformkanal zu. Ein Adapter, der ihn beim Aufräumen erst
      // anlegte, hätte die schlechteste Reihenfolge von allen.
      final AudioplayersToneService frisch = AudioplayersToneService();

      // Ohne die faule Anlage wäre schon diese Zeile ein Zugriff auf den
      // Plattformkanal, und der Test liefe ohne Meldung ins Leere.
      await expectLater(frisch.dispose(), completes);
    });
  });

  group('der untätige Standard', () {
    test('bleibt still und wirft nicht', () async {
      await expectLater(
        unavailableToneService.playTone('audio/beacon.mp3', balance: 1),
        completes,
      );
    });

    test('ist eine Konstante und damit überall dieselbe Instanz', () {
      expect(unavailableToneService, same(unavailableToneService));
    });
  });
}

/// Ein `AudioPlayer`, der nichts abspielt und alles mitschreibt.
class _FakeAudioPlayer implements AudioPlayer {
  final List<String> playedPaths = <String>[];
  final List<double?> balances = <double?>[];

  /// Ob [dispose] gerufen wurde.
  bool disposed = false;

  /// Wenn gesetzt, wirft [play].
  Object? failWith;

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    final Object? failure = failWith;
    if (failure != null) {
      throw failure;
    }
    playedPaths.add((source as AssetSource).path);
    balances.add(balance);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  /// Alles andere ist in diesem Adapter nicht benutzt und soll auffallen,
  /// wenn es doch einmal benutzt wird.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
