import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:fact_app/features/identity/domain/repositories/auth_repository.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fake_auth_repository.dart';

/// Der Sitzungszustand als Riverpod-Komposition.
void main() {
  late FakeAuthRepository repository;
  late RecordingDiagnosticSink diagnostics;

  setUp(() {
    repository = FakeAuthRepository();
    diagnostics = RecordingDiagnosticSink();
  });

  tearDown(() async {
    await repository.close();
  });

  /// Baut eine **nicht konstante** Sitzung, siehe die Begründung in
  /// `auth_session_test.dart`: mit `const` wäre der Gleichheitstest unten auch
  /// grün, wenn `AuthSession ==` nur `identical` prüfte.
  AuthSession sessionFor(String id) => AuthSession.signedIn(userId: id);

  ProviderContainer containerWith({AuthSession? initial}) {
    if (initial != null) {
      repository = FakeAuthRepository(initial: initial);
    }
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        diagnosticSinkProvider.overrideWithValue(diagnostics),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Der Standard ohne Override', () {
    test('ist der untätige Standard, nicht eine zweite Instanz', () {
      // `same` und nicht `isA`: der Standard ist eine Konstante, damit ein Test
      // ihn identifizieren kann. Wäre er eine Klasse zum Instanziieren, würde
      // Regel 7 die Presentation daran hindern, ihn zu benutzen.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(authRepositoryProvider),
        same(unavailableAuthRepository),
      );
      expect(container.read(authSessionProvider).isSignedIn, isFalse);
    });
  });

  group('Startwert', () {
    test('kommt synchron aus dem Repository', () {
      // Kein Ladezustand, kein `await`: die Weiche im Router muss beim ersten
      // Redirect antworten. Ein `AsyncNotifier` hier hätte jede Route in einen
      // Ladezustand gezwungen.
      final container = containerWith(initial: sessionFor('u1'));

      // Verglichen wird gegen eine **andere** Instanz mit derselben Kennung,
      // damit hier Wertgleichheit geprüft wird und nicht Identität.
      expect(container.read(authSessionProvider), sessionFor('u1'));
    });
  });

  group('Änderungen vom Strom', () {
    test('eine Anmeldung von außen kommt an', () async {
      final container = containerWith();
      container.read(authSessionProvider);

      repository.emit(sessionFor('u1'));
      await pumpEventQueue();

      expect(container.read(authSessionProvider).isSignedIn, isTrue);
    });

    test('gleiche Kennung benachrichtigt keinen Listener', () async {
      // Das ist die Zusicherung gegen das Erneuerungs-Gewitter. Der Router
      // hängt mit genau diesem Mechanismus (`ref.listen`) an diesem Provider:
      // was hier nicht benachrichtigt, löst dort kein `router.refresh()` aus.
      final container = containerWith();
      container.read(authSessionProvider);
      var notifications = 0;
      container.listen(authSessionProvider, (_, _) => notifications++);

      repository.emit(sessionFor('u1'));
      await pumpEventQueue();
      expect(notifications, 1);

      // `tokenRefreshed` und `userUpdated` liefern dieselbe Kennung erneut.
      repository.emit(sessionFor('u1'));
      repository.emit(sessionFor('u1'));
      await pumpEventQueue();
      expect(notifications, 1);

      repository.emit(sessionFor('u2'));
      await pumpEventQueue();
      expect(notifications, 2);
    });

    test('ein Fehler auf dem Strom nimmt die Sitzung nicht zurück', () async {
      // Eine fehlgeschlagene Token-Erneuerung ohne Netz kommt als Fehler. Wer
      // daraus "abgemeldet" macht, wirft den Nutzer bei jedem Funkloch aus der
      // App.
      final container = containerWith();
      container.read(authSessionProvider);
      repository.emit(sessionFor('u1'));
      await pumpEventQueue();

      repository.emitError(StateError('kein Netz'));
      await pumpEventQueue();

      expect(container.read(authSessionProvider).isSignedIn, isTrue);
      final event = diagnostics.events.single;
      expect(event.name, AuthSessionNotifier.streamErrorEvent);
      // Nur der Typname, nicht die Meldung: sie könnte Backend-Interna tragen.
      expect(event.attributes['type'], 'StateError');
      expect(event.attributes.values.join(), isNot(contains('kein Netz')));
    });
  });

  group('Entsorgen', () {
    test('eine Ausgabe während des Entsorgens wirft nicht', () async {
      // Der Strom kommt von außen, das Entsorgen von innen. Zwischen einer
      // zugestellten Ausgabe und dem `subscription.cancel` liegt eine
      // Mikrotask, und ein `state =` auf einem entsorgten Notifier wirft. Ohne
      // die `ref.mounted`-Prüfung im Notifier scheitert dieser Test mit einem
      // unbehandelten Fehler aus der Zone.
      final container = containerWith();
      container.read(authSessionProvider);

      repository.emit(sessionFor('u1'));
      container.dispose();
      await pumpEventQueue();

      // Die eigentliche Zusicherung ist, dass dieser Test überhaupt
      // durchläuft: ein `state =` nach dem Entsorgen landet als unbehandelter
      // Fehler in der Zone und macht ihn rot. Dazu die Kontrolle, dass das
      // Abonnement wirklich abgeräumt wurde.
      expect(repository.hasSessionListeners, isFalse);
    });
  });
}

/// Sammelt gemeldete Ereignisse, statt sie zu verwerfen.
class RecordingDiagnosticSink implements DiagnosticSink {
  /// Alles, was gemeldet wurde.
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);
}
