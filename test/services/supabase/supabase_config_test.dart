import 'dart:io';

import 'package:fact_app/services/supabase/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verhalten der Umgebungskonfiguration.
///
/// Der letzte Test ist der wichtigste: er durchsucht den eingecheckten
/// Quelltext nach einem echten Supabase-Schlüssel. `security.md` §2 verbietet
/// Konfigurationswerte im Repository, und im Lese-Repo stehen sie tatsächlich
/// hart im Code (`02_Frontend/app/supabase-client.jsx:5` und
/// `08_Flutter/lib/config/supabase_config.dart:4`). Genau das darf hier nicht
/// wieder passieren, und ein Test ist das einzige Mittel, das auch dann noch
/// wirkt, wenn niemand daran denkt.
void main() {
  group('missingRequirements', () {
    test('eine vollständige Konfiguration ist brauchbar', () {
      const config = SupabaseConfig(
        url: 'https://beispiel.supabase.co',
        publishableKey: 'sb_publishable_abc',
      );

      expect(config.isUsable, isTrue);
      expect(config.missingRequirements, isEmpty);
      expect(config.ensureUsable, returnsNormally);
    });

    test('der Platzhalter zählt als nicht gesetzt', () {
      const config = SupabaseConfig(
        url: SupabaseConfig.missingValue,
        publishableKey: SupabaseConfig.missingValue,
      );

      expect(config.isUsable, isFalse);
      expect(config.missingRequirements, hasLength(2));
      expect(
        config.missingRequirements.first,
        contains(SupabaseConfig.urlVariable),
      );
      expect(
        config.missingRequirements.last,
        contains(SupabaseConfig.publishableKeyVariable),
      );
    });

    test('ein leerer Wert zählt ebenfalls als nicht gesetzt', () {
      const config = SupabaseConfig(url: '', publishableKey: '');

      expect(config.isUsable, isFalse);
      expect(config.missingRequirements, hasLength(2));
    });

    test('http ohne s wird abgelehnt', () {
      const config = SupabaseConfig(
        url: 'http://beispiel.supabase.co',
        publishableKey: 'sb_publishable_abc',
      );

      expect(config.isUsable, isFalse);
      expect(config.missingRequirements.single, contains('https'));
    });

    test('eine relative Adresse wird abgelehnt', () {
      const config = SupabaseConfig(
        url: 'beispiel.supabase.co',
        publishableKey: 'sb_publishable_abc',
      );

      expect(config.isUsable, isFalse);
    });

    test('die Mängelliste ist unveränderlich', () {
      const config = SupabaseConfig(url: '', publishableKey: '');

      expect(
        () => config.missingRequirements.add('noch etwas'),
        throwsUnsupportedError,
      );
    });
  });

  group('ensureUsable', () {
    test('wirft mit dem Befehl, der das Problem behebt', () {
      const config = SupabaseConfig(url: '', publishableKey: '');

      Object? thrown;
      try {
        config.ensureUsable();
      } on SupabaseConfigurationError catch (error) {
        thrown = error;
      }

      expect(thrown, isA<SupabaseConfigurationError>());
      final message = thrown.toString();
      expect(message, contains('--dart-define'));
      expect(message, contains(SupabaseConfig.urlVariable));
      expect(message, contains(SupabaseConfig.publishableKeyVariable));
      expect((thrown! as SupabaseConfigurationError).problems, hasLength(2));
    });
  });

  group('toString', () {
    test('gibt den Schlüssel nicht heraus', () {
      // Zur Laufzeit zusammengesetzt, damit der Schlüsselpräfix nicht als
      // Literal im Quelltext steht. Sonst würde der Test weiter unten, der
      // genau danach sucht, an seiner eigenen Vorlage anschlagen.
      final key = <String>['sb', 'publishable', 'streng_geheim'].join('_');
      final config = SupabaseConfig(
        url: 'https://beispiel.supabase.co',
        publishableKey: key,
      );

      final text = config.toString();
      expect(text, contains('https://beispiel.supabase.co'));
      expect(text, isNot(contains('streng_geheim')));
      expect(text, contains('gesetzt'));
    });

    test('nennt einen fehlenden Schlüssel als fehlend', () {
      const config = SupabaseConfig(
        url: 'https://beispiel.supabase.co',
        publishableKey: SupabaseConfig.missingValue,
      );

      expect(config.toString(), contains('fehlt'));
    });
  });

  group('fromEnvironment', () {
    test('ohne --dart-define stehen die Platzhalter', () {
      // Dieser Testlauf setzt die Werte nicht, also müssen die Platzhalter da
      // sein. Wäre hier ein echter Wert, käme er aus dem Quelltext, und genau
      // das prüft der Test unten.
      expect(SupabaseConfig.fromEnvironment.url, SupabaseConfig.missingValue);
      expect(
        SupabaseConfig.fromEnvironment.publishableKey,
        SupabaseConfig.missingValue,
      );
      expect(SupabaseConfig.fromEnvironment.isUsable, isFalse);
    });
  });

  group('Wertsemantik', () {
    test('gleiche Werte heißen gleiche Konfiguration', () {
      const a = SupabaseConfig(url: 'https://a.test', publishableKey: 'k');
      const b = SupabaseConfig(url: 'https://a.test', publishableKey: 'k');
      const c = SupabaseConfig(url: 'https://a.test', publishableKey: 'anders');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('kein Zugangswert im Repository', () {
    test('nirgends in lib, test oder tool steht ein Supabase-Schlüssel', () {
      // `sb_publishable_` und `sb_secret_` sind die Präfixe der aktuellen
      // Supabase-Schlüssel, `eyJ` der Anfang eines JWT und damit der alten
      // anon- und service-role-Schlüssel.
      final forbidden = <RegExp>[
        RegExp('sb_publishable_[A-Za-z0-9_-]{8,}'),
        RegExp('sb_secret_[A-Za-z0-9_-]{8,}'),
        RegExp(r'eyJ[A-Za-z0-9_-]{20,}'),
        // Eine echte Projekt-URL: 20 Kleinbuchstaben vor .supabase.co.
        RegExp(r'https://[a-z]{20}\.supabase\.co'),
      ];

      final findings = <String>[];
      for (final directory in <String>['lib', 'test', 'tool']) {
        final root = Directory(directory);
        if (!root.existsSync()) {
          continue;
        }
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) {
            continue;
          }
          final source = entity.readAsStringSync();
          for (final pattern in forbidden) {
            final match = pattern.firstMatch(source);
            if (match != null) {
              findings.add('${entity.path}: ${pattern.pattern}');
            }
          }
        }
      }

      expect(
        findings,
        isEmpty,
        reason:
            'Ein Supabase-Zugangswert steht im Quelltext. Er gehört in einen '
            '--dart-define-Wert, siehe SupabaseConfig.',
      );
    });
  });
}
