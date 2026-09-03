// ERZEUGT von tool/generate_curated_data.dart aus
// 02_Frontend/app/wallet-colors.jsx. Nicht von Hand bearbeiten.
//
// Drift prüfen: dart run tool/generate_curated_data.dart --check
// Neu erzeugen: dart run tool/generate_curated_data.dart

/// Ein Kapitel eines Reiseführer-Bands, wörtlich wie in der Quelle.
///
/// `category` ist der **deutsche Anzeigename der Quelle** (`kategorie`) und
/// kein Oberflächentext: die Kapitelliste holt ihren Namen über
/// `t('cat.<key>')`. Das Feld steht hier, weil die Quelle es als Rückfall
/// hinschreibt, und `library_chapter_look.dart` sagt, warum dieser Rückfall
/// nicht erreichbar ist.
typedef WalletCategoryRecord = ({
  String key,
  String short,
  String glyph,
  String color,
  String dark,
  String category,
});

/// Alle Kapitel, Reihenfolge wie im Quellobjekt.
///
/// Für die Anzeige gilt [walletCategoryOrder]; beide sind hier gleich, und der
/// Prüflauf des Werkzeugs bricht ab, wenn eines der beiden Löcher bekommt.
const List<WalletCategoryRecord> walletCategoryRecords = <WalletCategoryRecord>[
  (
    key: 'hist',
    short: 'Hist.',
    glyph: '§',
    color: '#E8380D',
    dark: '#A82508',
    category: 'Historisch',
  ),
  (
    key: 'arch',
    short: 'Arch.',
    glyph: '⌂',
    color: '#3B82F6',
    dark: '#1E5DC4',
    category: 'Architektur',
  ),
  (
    key: 'myth',
    short: 'Mythos',
    glyph: '☾',
    color: '#A855F7',
    dark: '#7C3AC0',
    category: 'Mythos',
  ),
  (
    key: 'fun',
    short: 'Fun',
    glyph: '✸',
    color: '#F5C518',
    dark: '#C49A0A',
    category: 'Fun-Fact',
  ),
  (
    key: 'geo',
    short: 'Geo.',
    glyph: '△',
    color: '#00C2A8',
    dark: '#008A78',
    category: 'Geographie',
  ),
  (
    key: 'heute',
    short: 'Heute',
    glyph: '◉',
    color: '#EC4899',
    dark: '#BE185D',
    category: 'Stadt heute',
  ),
];

/// Die Reihenfolge der Kapitel, `window.WalletCatOrder`.
const List<String> walletCategoryOrder = <String>[
  'hist',
  'arch',
  'myth',
  'fun',
  'geo',
  'heute',
];
