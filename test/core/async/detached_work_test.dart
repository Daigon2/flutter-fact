import 'dart:async';

import 'package:fact_app/core/async/detached_work.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Helfer für abgekoppelte Arbeit.
///
/// Der Kern ist der zweite Test: ein Fehler aus einem nicht abgewarteten
/// `Future` muss gemeldet werden. Ohne diese Zusicherung erfüllt
/// `reportDetached` nur die halbe Regel aus `docs/engineering/flutter.md:151`
/// und wäre ein umbenanntes `unawaited`.
void main() {
  /// Fängt Meldungen ab, statt sie den Testlauf abbrechen zu lassen.
  ///
  /// `FlutterError.onError` ist in `flutter_test` so gesetzt, dass eine Meldung
  /// den laufenden Test als fehlgeschlagen markiert. Genau das ist im Betrieb
  /// gewollt und hier im Weg, deshalb wird der Kanal für die Dauer des Tests
  /// umgehängt und danach zurückgesetzt.
  List<FlutterErrorDetails> captureErrors() {
    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;
    addTearDown(() => FlutterError.onError = previous);
    return captured;
  }

  test('erfolgreiche Arbeit meldet nichts', () async {
    final captured = captureErrors();
    final completer = Completer<void>();

    reportDetached(completer.future, origin: 'test.ok');
    completer.complete();
    await completer.future;
    // Ein Mikrotask-Durchlauf, damit die angehängte Fortsetzung dran war.
    await Future<void>.delayed(Duration.zero);

    expect(captured, isEmpty);
  });

  test(
    'ein Fehler wird mit Ursache, Stapelspur und Herkunft gemeldet',
    () async {
      final captured = captureErrors();
      final failure = StateError('Speichern fehlgeschlagen');

      reportDetached(
        Future<void>.error(failure, StackTrace.current),
        origin: 'settings.audio_mode.enable',
      );
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(1));
      expect(captured.single.exception, same(failure));
      expect(captured.single.stack, isNotNull);
      // Die Herkunft ist das einzige, woran später erkennbar ist, welcher der
      // abgekoppelten Vorgänge gescheitert ist.
      expect(
        captured.single.context.toString(),
        contains('settings.audio_mode.enable'),
      );
    },
  );

  test('der Aufrufer wartet nicht, der Fehler kommt trotzdem an', () async {
    // Belegt den Unterschied zu `await`: `reportDetached` gibt sofort zurück,
    // die Meldung folgt später. Ohne den Helfer wäre der Fehler eine
    // unbehandelte Ausnahme in der Zone.
    final captured = captureErrors();
    final completer = Completer<void>();

    reportDetached(completer.future, origin: 'test.late');

    expect(captured, isEmpty, reason: 'noch nicht gescheitert');

    completer.completeError(ArgumentError('zu spät'));
    await Future<void>.delayed(Duration.zero);

    expect(captured, hasLength(1));
    expect(captured.single.exception, isArgumentError);
  });
}
