import 'package:fact_app/app/bootstrap.dart';
import 'package:fact_app/features/identity/domain/repositories/auth_repository.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/services/location/geolocator_location_service.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:fact_app/services/supabase/supabase_config.dart';
import 'package:fact_app/services/supabase/supabase_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Overrides des Betriebs.
///
/// Dieser Test ist das Netz unter dem stillen Standard. `authRepositoryProvider`
/// liefert ohne Override [unavailableAuthRepository], also einen Zustand, in dem
/// sich niemand anmelden kann und **nichts** danach aussieht: keine Ausnahme,
/// kein Log, ein Bildschirm, der einfach "Fehler beim Anmelden" sagt. Fehlt der
/// Override in `bootstrap.dart`, fällt genau das erst auf einem Gerät auf.
void main() {
  group('productionProviderScope', () {
    test('bindet authRepositoryProvider an die Supabase-Umsetzung', () {
      // Nachgewiesen über die Wirkung statt über die Identität des
      // `Override`-Objekts: mit dem Override braucht das Repository die
      // Supabase-Konfiguration, ohne ihn nicht. Genau daran ist zu erkennen,
      // dass nicht mehr der untätige Standard antwortet.
      final scope = productionProviderScope(child: const SizedBox.shrink());
      final container = ProviderContainer(
        overrides: [
          ...scope.overrides,
          // Erzwingt die fehlende Konfiguration, damit der Test nicht davon
          // abhängt, ob jemand `--dart-define` gesetzt hat.
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: '', publishableKey: ''),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Geprüft wird der Text und nicht der Typ: Riverpod 3 verpackt einen
      // Fehler aus einem Provider in `ProviderException`, und dieser Typ ist
      // aus `flutter_riverpod 3.4.2` nicht exportiert. Die Meldung von
      // `SupabaseConfigurationError` steht darin.
      expect(
        () => container.read(authRepositoryProvider),
        throwsA(
          isA<Object>().having(
            (error) => error.toString(),
            'toString',
            allOf(
              contains('Supabase ist nicht konfiguriert'),
              contains(SupabaseConfig.urlVariable),
            ),
          ),
        ),
      );
    });

    test('ohne die Overrides bleibt der untätige Standard', () {
      // Die Gegenprobe. Ohne sie könnte der Test oben auch grün sein, wenn der
      // Standard selbst Supabase anfassen würde.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(authRepositoryProvider),
        same(unavailableAuthRepository),
      );
    });

    test('bindet locationServiceProvider an die geolocator-Umsetzung', () {
      // Derselbe stille Ausfall wie bei der Anmeldung, nur eine Ebene weiter:
      // ohne diesen Override liefert der Standard nie eine Position, die Karte
      // bliebe für immer auf der Rückfallstadt stehen, und es gäbe weder einen
      // Fehler noch ein Log. Auffallen würde es erst auf einem Gerät.
      final scope = productionProviderScope(child: const SizedBox.shrink());
      final container = ProviderContainer(overrides: scope.overrides);
      addTearDown(container.dispose);

      expect(
        container.read(locationServiceProvider),
        isA<GeolocatorLocationService>(),
      );
    });

    test('ohne die Overrides liefert der Ortungsdienst nichts', () {
      // Die Gegenprobe, wie oben. `same` und nicht `isA`: der Standard ist eine
      // Konstante, damit ein Test ihn identifizieren kann.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(locationServiceProvider),
        same(unavailableLocationService),
      );
    });

    test('wertet Supabase beim Aufbau noch nicht aus', () {
      // `overrideWith` und nicht `overrideWithValue`: Letzteres bräuchte die
      // Instanz sofort, und die braucht `supabaseClientProvider`, der
      // `Supabase.instance.client` liest. Der Aufbau der Scope allein darf
      // deshalb nichts auswerten, sonst scheitert der Start, bevor
      // `bootstrap()` seine eigene Fehlermeldung zeigen kann.
      expect(
        () => productionProviderScope(child: const SizedBox.shrink()),
        returnsNormally,
      );
    });

    test('reicht das Kind unverändert durch', () {
      const child = SizedBox.shrink();

      expect(productionProviderScope(child: child).child, same(child));
    });
  });
}
