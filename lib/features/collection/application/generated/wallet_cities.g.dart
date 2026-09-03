// ERZEUGT von tool/generate_curated_data.dart aus
// 02_Frontend/app/wallet-colors.jsx. Nicht von Hand bearbeiten.
//
// Drift prüfen: dart run tool/generate_curated_data.dart --check
// Neu erzeugen: dart run tool/generate_curated_data.dart

/// Die Ausstattung eines Bandes im Bücherregal, wörtlich wie in der Quelle.
///
/// `key` ist der Quellschlüssel, kleingeschrieben und **mit** Umlaut
/// (`münchen`). Er ist hier absichtlich nicht auf die Vergleichsform gebracht:
/// diese Datei schreibt ab, sie normalisiert nicht. Wer einen Fakt einem Band
/// zuordnet, geht über `collection/domain/library_city_key.dart`, und dort
/// steht auch, warum die Zuordnung nicht so läuft wie in der Quelle.
typedef WalletCityRecord = ({
  String key,
  String name,
  String initial,
  int bandNo,
  String region,
  String color,
  String colorDk,
  String colorLt,
  String accent,
});

/// Alle Städte mit eigener Palette, Reihenfolge wie im Quellobjekt.
///
/// Das ist **nicht** die Reihenfolge im Regal, die steht in
/// [walletCityOrder] und weicht ab.
const List<WalletCityRecord> walletCityRecords = <WalletCityRecord>[
  (
    key: 'münchen',
    name: 'München',
    initial: 'M',
    bandNo: 1,
    region: 'Bayern · Hauptstadt',
    color: '#1E5FAD',
    colorDk: '#0D3A6B',
    colorLt: '#3B82F6',
    accent: '#3B82F6',
  ),
  (
    key: 'regensburg',
    name: 'Regensburg',
    initial: 'R',
    bandNo: 3,
    region: 'Bayern · Oberpfalz',
    color: '#B03018',
    colorDk: '#7A1E0E',
    colorLt: '#E8380D',
    accent: '#E8380D',
  ),
  (
    key: 'weimar',
    name: 'Weimar',
    initial: 'W',
    bandNo: 5,
    region: 'Thüringen · Klassik',
    color: '#9A7C10',
    colorDk: '#6A5500',
    colorLt: '#F5C518',
    accent: '#F5C518',
  ),
  (
    key: 'passau',
    name: 'Passau',
    initial: 'P',
    bandNo: 4,
    region: 'Bayern · Dreiflüsseeck',
    color: '#1A7C6A',
    colorDk: '#0F4A40',
    colorLt: '#00C2A8',
    accent: '#00C2A8',
  ),
  (
    key: 'rom',
    name: 'Rom',
    initial: 'R',
    bandNo: 2,
    region: 'Italien · Latium',
    color: '#B04A18',
    colorDk: '#7A2E0A',
    colorLt: '#F97316',
    accent: '#F97316',
  ),
];

/// Die Ausstattung einer Stadt ohne eigenen Eintrag,
/// `window.WalletCityDefault`.
///
/// `bandNo` ist dort `0`, und die Quelle behandelt das als „keine Nummer":
/// `city.bandNo || (4 * ri + ci + 1)` (`screen-wallet.jsx:966`) fällt bei `0`
/// auf die Gitterposition zurück, weil `0` in JavaScript unwahr ist.
const WalletCityRecord walletCityDefault = (
  key: '',
  name: '–',
  initial: '?',
  bandNo: 0,
  region: '',
  color: '#5C4A30',
  colorDk: '#3D3020',
  colorLt: '#A08860',
  accent: '#A08860',
);

/// Die Reihenfolge der Bände im Regal, `window.WalletCityOrder`.
///
/// Städte, die hier fehlen, hängt die Quelle hinten an
/// (`screen-wallet.jsx:1826-1832`). Die Nummern auf den Buchrücken folgen
/// dieser Reihenfolge **nicht**: sie stehen als `bandNo` an der Stadt, und
/// die Regalfolge münchen, regensburg, weimar, passau, rom zeigt damit die
/// Bände 1, 3, 5, 4, 2 von links nach rechts.
const List<String> walletCityOrder = <String>[
  'münchen',
  'regensburg',
  'weimar',
  'passau',
  'rom',
];
