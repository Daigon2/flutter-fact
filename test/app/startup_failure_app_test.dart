import 'package:fact_app/app/startup_failure_app.dart';
import 'package:fact_app/services/supabase/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Startabbruch muss dem Entwickler sagen, was zu tun ist.
///
/// `bootstrap()` fängt [SupabaseConfigurationError] ab und zeigt statt der App
/// diesen Bildschirm. Das ist nur dann besser als ein Absturz, wenn der
/// `--dart-define`-Befehl auch wirklich darauf steht.
void main() {
  testWidgets('nennt die fehlenden Werte und den --dart-define-Befehl', (
    tester,
  ) async {
    const config = SupabaseConfig(url: '', publishableKey: '');
    final error = SupabaseConfigurationError(config.missingRequirements);

    await tester.pumpWidget(StartupFailureApp(problem: error.toString()));
    await tester.pumpAndSettle();

    expect(find.text('FACT konnte nicht starten'), findsOneWidget);

    final shown = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((widget) => widget.data ?? '')
        .join('\n');

    expect(shown, contains('--dart-define'));
    expect(shown, contains(SupabaseConfig.urlVariable));
    expect(shown, contains(SupabaseConfig.publishableKeyVariable));
  });
}
