import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:fact_app/features/identity/presentation/formatting/auth_failure_text.dart';
import 'package:fact_app/features/identity/presentation/notifiers/login_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die dritte Station der Fehlerübersetzung: Fehlschlag zu i18n-Schlüssel.
void main() {
  group('Zuordnung', () {
    test('unvollständige Eingabe', () {
      expect(
        authFailureTextKey(const LoginInputIncomplete()),
        'onboarding.errRequired',
      );
    });

    test('falsche Zugangsdaten', () {
      expect(
        authFailureTextKey(const AuthInvalidCredentials()),
        'onboarding.errInvalidLogin',
      );
    });

    test('unbestätigte E-Mail-Adresse', () {
      expect(
        authFailureTextKey(const AuthEmailNotConfirmed()),
        'login.errEmailNotConfirmed',
      );
    });

    test('abgelehnt und nicht verfügbar teilen den Sammeltext', () {
      // Die PWA unterscheidet hier ebenfalls nicht.
      expect(
        authFailureTextKey(const AuthRequestRejected()),
        'onboarding.errGeneric',
      );
      expect(
        authFailureTextKey(const AuthBackendUnavailable()),
        'onboarding.errGeneric',
      );
    });

    test('ein unerwarteter Fehler bekommt auch einen Text', () {
      // Der Fehlerkanal kann alles tragen. Ohne diesen Zweig stünde die
      // Fehlerbox leer, und der Nutzer sähe einen Bildschirm, der nichts sagt.
      expect(
        authFailureTextKey(const FormatException('kaputt')),
        'onboarding.errGeneric',
      );
    });
  });

  group('Die Schlüssel existieren in beiden Sprachen', () {
    // Ohne das wäre eine Zuordnung auf einen Tippfehler grün: `AppStrings.text`
    // gibt bei einem unbekannten Schlüssel den Schlüssel zurück.
    for (final language in AppLanguage.values) {
      test(language.code, () {
        final strings = AppStrings.of(language);
        for (final key in <String>[
          authRequiredKey,
          authInvalidLoginKey,
          authEmailNotConfirmedKey,
          authGenericKey,
        ]) {
          expect(strings.hasText(key), isTrue, reason: key);
          expect(strings.text(key), isNot(key), reason: key);
        }
      });
    }
  });

  group('Nichts vom Backend erreicht die Oberfläche', () {
    test('die Textwahl hängt nur am Typ, nicht an einer Meldung', () {
      // Bewusste Abweichung von der PWA: `screen-auth.jsx:478` zeigt im
      // Restfall die **rohe englische Meldung** des Backends. Hier gibt es dafür
      // keinen Kanal, weil `AuthFailure` keine Meldung trägt und diese Funktion
      // nur den Typ ansieht.
      const withInternals = AuthRequestRejected(
        code: 'relation_does_not_exist',
      );

      expect(authFailureTextKey(withInternals), 'onboarding.errGeneric');
      expect(
        AppStrings.of(AppLanguage.de).text(authFailureTextKey(withInternals)),
        'Fehler beim Anmelden.',
      );
    });
  });
}
