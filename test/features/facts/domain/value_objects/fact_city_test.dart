import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nagelt die Slug-Bildung auf `public._slugify` fest.
///
/// Die Funktion steht in
/// `03_Backend/migrations/2026-06-07_city_backfill_and_slug_match.sql:19`:
///
/// ```sql
/// select regexp_replace(
///   replace(replace(replace(replace(lower(coalesce(p, '')),
///     'ü','ue'),'ö','oe'),'ä','ae'),'ß','ss'),
///   '[^a-z]', '', 'g');
/// ```
///
/// Warum dieser Test ernst zu nehmen ist: derselbe Bruch hat schon einmal
/// `create_team_session` mit `not_enough_facts_in_city` scheitern lassen,
/// obwohl München rund 600 Fakten hat. `lower('München')` ergibt `münchen`
/// und passt nicht zum Frontend-Slug `muenchen`. Wer die Umsetzung hier
/// ändert, muss die SQL-Funktion mitändern, und die liegt in einem anderen
/// Repository. Das ist die offene Entscheidung E-11.
void main() {
  group('slug, Gleichlauf mit _slugify', () {
    test('Umlaute werden ausgeschrieben, nicht entfernt', () {
      expect(const FactCity('München').slug, 'muenchen');
      expect(const FactCity('Nürnberg').slug, 'nuernberg');
      expect(const FactCity('Köln').slug, 'koeln');
      expect(const FactCity('Gäufelden').slug, 'gaeufelden');
      expect(const FactCity('Weißenburg').slug, 'weissenburg');
    });

    test('Großschreibung fällt vor der Ersetzung weg', () {
      expect(const FactCity('MÜNCHEN').slug, 'muenchen');
      expect(const FactCity('MüNcHeN').slug, 'muenchen');
    });

    test('die Städte des Bestands ergeben die erwarteten Slugs', () {
      // Die zehn Präfixe aus dem Backfill der Migration vom 2026-06-07.
      const expected = <String, String>{
        'München': 'muenchen',
        'Rome': 'rome',
        'Regensburg': 'regensburg',
        'Passau': 'passau',
        'Nürnberg': 'nuernberg',
        'Weimar': 'weimar',
        'Bologna': 'bologna',
        'Piran': 'piran',
        'Salzburg': 'salzburg',
        'Heidelberg': 'heidelberg',
      };

      expected.forEach((displayName, slug) {
        expect(FactCity(displayName).slug, slug, reason: displayName);
      });
    });

    test('alles außer a bis z fällt weg, auch Ziffern und Akzente', () {
      // Nicht schön, aber genau das tut `[^a-z]` in der SQL-Funktion. Der Test
      // hält das Verhalten fest, damit niemand es unbemerkt „verbessert".
      expect(const FactCity('Sant Angelo 2').slug, 'santangelo');
      expect(
        const FactCity('Bad Tölz-Wolfratshausen').slug,
        'badtoelzwolfratshausen',
      );
      // Belegt und gewollt: `_slugify` ersetzt nur ü, ö, ä und ß. Jeder andere
      // Akzent fällt ersatzlos weg, aus `Málaga` wird also `mlaga`. Das ist
      // eine Falle für die erste Stadt außerhalb des deutschen Sprachraums und
      // steht im Bericht unter Risks. Nachgebaut wird hier trotzdem das echte
      // Verhalten des Backends, nicht das gewünschte.
      expect(const FactCity('Málaga').slug, 'mlaga');
      expect(const FactCity('  Passau  ').slug, 'passau');
      expect(const FactCity('').slug, '');
    });
  });

  group('matchesSlug', () {
    test('vergleicht Anzeigename gegen Slug', () {
      expect(const FactCity('München').matchesSlug('muenchen'), isTrue);
      expect(const FactCity('München').matchesSlug('München'), isTrue);
      expect(const FactCity('München').matchesSlug('MÜNCHEN'), isTrue);
      expect(const FactCity('München').matchesSlug('passau'), isFalse);
    });

    test('der schon einmal aufgetretene Bruch bleibt gefangen', () {
      // `lower('München')` = 'münchen' ist genau der Vergleich, der im Backend
      // fehlgeschlagen ist. Der Anzeigename allein darf nicht als Slug gelten.
      expect(const FactCity('München').slug, isNot('münchen'));
      expect(
        const FactCity('München').matchesSlug('münchen'),
        isTrue,
        reason: 'der Vergleichswert wird selbst normalisiert',
      );
    });
  });

  group('Wertsemantik', () {
    test('gleicher Anzeigename heißt gleiche Stadt', () {
      // Zur Laufzeit gebaut und mit `identical` gegengeprüft, wie in
      // `auth_city_test.dart`. Zwei gleich geschriebene
      // `const FactCity('München')` sind in Dart **dasselbe Objekt**; ein
      // Gleichheitstest darauf prüfte nichts. Nachgemessen: `==` auf
      // `identical(this, other)` zu reduzieren überlebte damit die Suite.
      // Städte, die aus Supabase kommen, sind nicht kanonisiert, und ein
      // solcher Regress bräche jeden Vergleich nach Stadt.
      final left = FactCity(<String>['Mün', 'chen'].join());
      final right = FactCity(String.fromCharCodes('München'.runes));

      expect(identical(left, right), isFalse);
      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });

    test('zwei Anzeigenamen mit gleichem Slug bleiben verschieden', () {
      // Absichtlich: die Identität ist der Anzeigename aus der Spalte. Der Slug
      // ist nur ein Vergleichsschlüssel und keine Identität. Wer sie
      // gleichsetzen will, entscheidet damit E-11, und das passiert nicht hier.
      expect(const FactCity('München'), isNot(const FactCity('MÜNCHEN')));
      expect(const FactCity('München').slug, const FactCity('MÜNCHEN').slug);
    });

    test('toString nennt beide Formen', () {
      expect(const FactCity('München').toString(), contains('München'));
      expect(const FactCity('München').toString(), contains('muenchen'));
    });
  });
}
