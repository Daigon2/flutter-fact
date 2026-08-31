import 'package:fact_app/features/progression/application/trophy_catalog.dart';
import 'package:fact_app/features/progression/domain/entities/trophy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Eine **zweite, unabhängige** Abschrift der 36 Einträge aus
/// `02_Frontend/app/wallet-colors.jsx: window.WalletTrophies`.
///
/// Unabhängig von `tool/generate_curated_data.dart` von Hand aus der Quelle
/// abgetippt, genau wie `fact_category_look_test.dart` es für die doppelte
/// Kategorietabelle tut. Der Grund steht dort: bei den 45 Farbwerten der
/// Gruppen-Layer hat genau diese zweite Abschrift einmal gefehlt, und 17
/// Mutationen haben die Suite trotzdem überlebt. Ein Vergleich des
/// generierten Codes gegen sich selbst hätte hier nichts geprüft; diese Liste
/// ist unabhängig von `wallet_trophies.g.dart` entstanden.
const List<
  ({
    String key,
    String category,
    int? threshold,
    String glyph,
    String labelDe,
    String labelEn,
    String descDe,
    String descEn,
  })
>
_expected =
    <
      ({
        String key,
        String category,
        int? threshold,
        String glyph,
        String labelDe,
        String labelEn,
        String descDe,
        String descEn,
      })
    >[
      (
        key: 'chronist',
        category: 'hist',
        threshold: 10,
        glyph: '§',
        labelDe: 'Chronist',
        labelEn: 'Chronicler',
        descDe: '10 historische Fakten gesammelt',
        descEn: '10 historical facts collected',
      ),
      (
        key: 'steinleser',
        category: 'arch',
        threshold: 10,
        glyph: '⌂',
        labelDe: 'Steinleser',
        labelEn: 'Stone Reader',
        descDe: '10 Architektur-Fakten gesammelt',
        descEn: '10 architecture facts collected',
      ),
      (
        key: 'mythenjaeger',
        category: 'myth',
        threshold: 10,
        glyph: '☾',
        labelDe: 'Mythenjäger',
        labelEn: 'Myth Hunter',
        descDe: '10 Mythos-Fakten gesammelt',
        descEn: '10 myth facts collected',
      ),
      (
        key: 'lacher',
        category: 'fun',
        threshold: 10,
        glyph: '✸',
        labelDe: 'Der Lacher',
        labelEn: 'The Laugher',
        descDe: '10 Fun-Fakten gesammelt',
        descEn: '10 fun facts collected',
      ),
      (
        key: 'flussfischer',
        category: 'geo',
        threshold: 10,
        glyph: '⚓',
        labelDe: 'Flussfischer',
        labelEn: 'River Fisher',
        descDe: '10 Geo-Fakten gesammelt',
        descEn: '10 geography facts collected',
      ),
      (
        key: 'stadtreporter',
        category: 'heute',
        threshold: 10,
        glyph: '📸',
        labelDe: 'Stadtreporter',
        labelEn: 'City Reporter',
        descDe: '10 „Stadt heute"-Fakten gesammelt',
        descEn: '10 "City Today" facts collected',
      ),
      (
        key: 'meister_hist',
        category: 'hist',
        threshold: 25,
        glyph: '§§',
        labelDe: 'Meister-Chronist',
        labelEn: 'Master Chronicler',
        descDe: '25 historische Fakten gesammelt',
        descEn: '25 historical facts collected',
      ),
      (
        key: 'meister_arch',
        category: 'arch',
        threshold: 25,
        glyph: '⌂⌂',
        labelDe: 'Meister-Steinleser',
        labelEn: 'Master Stone Reader',
        descDe: '25 Architektur-Fakten gesammelt',
        descEn: '25 architecture facts collected',
      ),
      (
        key: 'münchen_first',
        category: 'city',
        threshold: null,
        glyph: '🦁',
        labelDe: 'Münchner',
        labelEn: 'Münchner',
        descDe: 'Ersten Fakt in München gesammelt',
        descEn: 'First fact collected in Munich',
      ),
      (
        key: 'rom_first',
        category: 'city',
        threshold: null,
        glyph: '🏛',
        labelDe: 'Römer',
        labelEn: 'Roman',
        descDe: 'Ersten Fakt in Rom gesammelt',
        descEn: 'First fact collected in Rome',
      ),
      (
        key: 'regensburg_first',
        category: 'city',
        threshold: null,
        glyph: '⚓',
        labelDe: 'Regensburger',
        labelEn: 'Regensburger',
        descDe: 'Ersten Fakt in Regensburg gesammelt',
        descEn: 'First fact collected in Regensburg',
      ),
      (
        key: 'passau_first',
        category: 'city',
        threshold: null,
        glyph: '△',
        labelDe: 'Passauer',
        labelEn: 'Passauer',
        descDe: 'Ersten Fakt in Passau gesammelt',
        descEn: 'First fact collected in Passau',
      ),
      (
        key: 'stadtkenner',
        category: 'city',
        threshold: null,
        glyph: '🗺',
        labelDe: 'Stadtkenner',
        labelEn: 'City Expert',
        descDe: '25 Fakten in einer Stadt gesammelt',
        descEn: '25 facts collected in one city',
      ),
      (
        key: 'weltenbummler',
        category: 'city',
        threshold: null,
        glyph: '✈',
        labelDe: 'Weltenbummler',
        labelEn: 'Globetrotter',
        descDe: 'In 3 Städten gesammelt',
        descEn: 'Collected facts in 3 cities',
      ),
      (
        key: 'grand_tour',
        category: 'city',
        threshold: null,
        glyph: '🌍',
        labelDe: 'Grand Tour',
        labelEn: 'Grand Tour',
        descDe: 'In allen 4 Städten gesammelt',
        descEn: 'Collected facts in all 4 cities',
      ),
      (
        key: 'erster',
        category: 'mile',
        threshold: null,
        glyph: '★',
        labelDe: 'Erster Schritt',
        labelEn: 'First Step',
        descDe: '1 Fakt gesammelt',
        descEn: '1 fact collected',
      ),
      (
        key: 'entdecker',
        category: 'mile',
        threshold: null,
        glyph: '★★',
        labelDe: 'Entdecker',
        labelEn: 'Explorer',
        descDe: '10 Fakten gesammelt',
        descEn: '10 facts collected',
      ),
      (
        key: 'sammler',
        category: 'mile',
        threshold: null,
        glyph: '★★★',
        labelDe: 'Sammler',
        labelEn: 'Collector',
        descDe: '25 Fakten gesammelt',
        descEn: '25 facts collected',
      ),
      (
        key: 'kenner',
        category: 'mile',
        threshold: null,
        glyph: '✦',
        labelDe: 'Kenner',
        labelEn: 'Connoisseur',
        descDe: '50 Fakten gesammelt',
        descEn: '50 facts collected',
      ),
      (
        key: 'experte',
        category: 'mile',
        threshold: null,
        glyph: '✦✦',
        labelDe: 'Experte',
        labelEn: 'Expert',
        descDe: '100 Fakten gesammelt',
        descEn: '100 facts collected',
      ),
      (
        key: 'legende',
        category: 'mile',
        threshold: null,
        glyph: '✦✦✦',
        labelDe: 'Stadtlegende',
        labelEn: 'City Legend',
        descDe: '250 Fakten gesammelt',
        descEn: '250 facts collected',
      ),
      (
        key: 'fruehaufsteher',
        category: 'time',
        threshold: null,
        glyph: '🌅',
        labelDe: 'Frühaufsteher',
        labelEn: 'Early Bird',
        descDe: 'Fakt vor 8 Uhr gesammelt',
        descEn: 'Fact collected before 8am',
      ),
      (
        key: 'nachtschwärmer',
        category: 'time',
        threshold: null,
        glyph: '🌙',
        labelDe: 'Nachtschwärmer',
        labelEn: 'Night Owl',
        descDe: 'Fakt nach 22 Uhr gesammelt',
        descEn: 'Fact collected after 10pm',
      ),
      (
        key: 'nachtfalter',
        category: 'time',
        threshold: null,
        glyph: '🦇',
        labelDe: 'Nachtfalter',
        labelEn: 'Night Moth',
        descDe: 'Fakt nach Mitternacht gesammelt',
        descEn: 'Fact collected after midnight',
      ),
      (
        key: 'tagesrekord',
        category: 'time',
        threshold: null,
        glyph: '⚡',
        labelDe: 'Tagesrekord',
        labelEn: 'Day Record',
        descDe: '5 Fakten an einem Tag gesammelt',
        descEn: '5 facts in one day',
      ),
      (
        key: 'wochenend_held',
        category: 'time',
        threshold: null,
        glyph: '🎯',
        labelDe: 'Wochenend-Held',
        labelEn: 'Weekend Hero',
        descDe: '5 Fakten am Wochenende gesammelt',
        descEn: '5 facts on weekends',
      ),
      (
        key: 'autor',
        category: 'create',
        threshold: null,
        glyph: '✏',
        labelDe: 'Autor',
        labelEn: 'Author',
        descDe: 'Ersten eigenen Fakt erstellt',
        descEn: 'Created your first fact',
      ),
      (
        key: 'viel_autor',
        category: 'create',
        threshold: null,
        glyph: '✏✏',
        labelDe: 'Vielschreiber',
        labelEn: 'Prolific',
        descDe: '5 eigene Fakten erstellt',
        descEn: '5 facts created',
      ),
      (
        key: 'kommentator',
        category: 'create',
        threshold: null,
        glyph: '💬',
        labelDe: 'Kommentator',
        labelEn: 'Commenter',
        descDe: 'Ersten Kommentar geschrieben',
        descEn: 'Wrote first comment',
      ),
      (
        key: 'top10_weekly',
        category: 'rank',
        threshold: null,
        glyph: '🥉',
        labelDe: 'Top-10',
        labelEn: 'Top 10',
        descDe: 'Top 10 in einer Wochenwertung',
        descEn: 'Top 10 in a weekly ranking',
      ),
      (
        key: 'top3_weekly',
        category: 'rank',
        threshold: null,
        glyph: '🥈',
        labelDe: 'Podium',
        labelEn: 'Podium',
        descDe: 'Top 3 in einer Wochenwertung',
        descEn: 'Top 3 in a weekly ranking',
      ),
      (
        key: 'wochensieger',
        category: 'rank',
        threshold: null,
        glyph: '🥇',
        labelDe: 'Wochensieger',
        labelEn: 'Weekly Winner',
        descDe: '#1 in einer Wochenwertung',
        descEn: '#1 in a weekly ranking',
      ),
      (
        key: 'koop_first',
        category: 'group',
        threshold: null,
        glyph: '🤝',
        labelDe: 'Koop-Held',
        labelEn: 'Co-op Hero',
        descDe: 'Erste Koop-Session abgeschlossen',
        descEn: 'Finished your first co-op session',
      ),
      (
        key: 'koop_squad',
        category: 'group',
        threshold: null,
        glyph: '👥',
        labelDe: 'Koop-Squad',
        labelEn: 'Co-op Squad',
        descDe: '5 Koop-Sessions abgeschlossen',
        descEn: 'Finished 5 co-op sessions',
      ),
      (
        key: 'geheimtipp',
        category: 'secret',
        threshold: null,
        glyph: '🔍',
        labelDe: 'Geheimtipp',
        labelEn: 'Hidden Gem',
        descDe: 'Fakt gesammelt den weniger als 5 andere kennen',
        descEn: 'Collected a fact fewer than 5 others have',
      ),
      (
        key: 'heimatforscher',
        category: 'secret',
        threshold: null,
        glyph: '🧭',
        labelDe: 'Heimatforscher',
        labelEn: 'Local Expert',
        descDe: 'Werde zum Experten deines Viertels (kommt bald)',
        descEn: 'Become an expert of your neighbourhood (coming soon)',
      ),
    ];

void main() {
  test('trophyCatalog trägt genau 36 Einträge', () {
    expect(trophyCatalog, hasLength(36));
    expect(_expected, hasLength(36));
  });

  test('jeder Eintrag trifft die unabhängige Abschrift, Feld für Feld', () {
    for (var i = 0; i < _expected.length; i++) {
      final Trophy trophy = trophyCatalog[i];
      final expected = _expected[i];
      expect(trophy.key, expected.key, reason: 'Index $i: key');
      expect(trophy.category, expected.category, reason: 'Index $i: category');
      expect(
        trophy.threshold,
        expected.threshold,
        reason: 'Index $i: threshold',
      );
      expect(trophy.glyph, expected.glyph, reason: 'Index $i: glyph');
      expect(trophy.labelDe, expected.labelDe, reason: 'Index $i: labelDe');
      expect(trophy.labelEn, expected.labelEn, reason: 'Index $i: labelEn');
      expect(trophy.descDe, expected.descDe, reason: 'Index $i: descDe');
      expect(trophy.descEn, expected.descEn, reason: 'Index $i: descEn');
    }
  });

  test('alle 36 Schlüssel sind eindeutig', () {
    final Set<String> keys = trophyCatalog.map((t) => t.key).toSet();
    expect(keys, hasLength(36));
  });

  group('trophiesInDisplayOrder', () {
    test('offene zuerst, gesperrte danach, je in Definitionsreihenfolge', () {
      // Drei nicht benachbarte Schlüssel als „offen" markiert.
      final Set<String> unlocked = <String>{'lacher', 'grand_tour', 'legende'};

      final List<Trophy> ordered = trophiesInDisplayOrder(
        unlockedKeys: unlocked,
      );

      expect(ordered, hasLength(36));
      // Die ersten drei sind die offenen, in Katalogreihenfolge (nicht in
      // der Reihenfolge, in der sie im Set stehen).
      expect(ordered.take(3).map((t) => t.key).toList(), <String>[
        'lacher',
        'grand_tour',
        'legende',
      ]);
      // Der Rest ist gesperrt, ebenfalls in Katalogreihenfolge.
      final List<Trophy> lockedTail = ordered.skip(3).toList();
      expect(lockedTail, hasLength(33));
      final List<Trophy> expectedLockedTail = trophyCatalog
          .where((t) => !unlocked.contains(t.key))
          .toList();
      expect(
        lockedTail.map((t) => t.key).toList(),
        expectedLockedTail.map((t) => t.key).toList(),
      );
    });

    test('leere Menge zeigt alle 36 gesperrt, in Katalogreihenfolge', () {
      final List<Trophy> ordered = trophiesInDisplayOrder(
        unlockedKeys: const <String>{},
      );
      expect(
        ordered.map((t) => t.key).toList(),
        trophyCatalog.map((t) => t.key).toList(),
      );
    });

    test('alle Schlüssel offen zeigt dieselbe Reihenfolge wieder', () {
      final Set<String> allKeys = trophyCatalog.map((t) => t.key).toSet();
      final List<Trophy> ordered = trophiesInDisplayOrder(
        unlockedKeys: allKeys,
      );
      expect(
        ordered.map((t) => t.key).toList(),
        trophyCatalog.map((t) => t.key).toList(),
      );
    });
  });
}
