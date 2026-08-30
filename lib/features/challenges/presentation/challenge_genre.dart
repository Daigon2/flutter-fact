/// Die acht Themen, nach denen der Assistent den Faktenpool filtern kann.
///
/// Quelle ist `CHAL_GENRES` in `02_Frontend/app/screen-challenge.jsx:1518-1536`.
///
/// ## [code] ist ein Datenwert, kein Anzeigetext
///
/// Er steht genau so in der Spalte `facts.genre` und wird vom Generator
/// verglichen (`hunt-generator.jsx:172`: `genres.includes(f.genre)`). Deshalb
/// bleibt er deutsch und wird nie übersetzt, wie `Fact.genre` es an seinem
/// Feld begründet. Die erlaubten Werte stehen als `CHECK`-Bedingung im
/// geteilten Backend.
///
/// ## Warum die Beschriftung aus `tour.genre.*` kommt
///
/// `screen-challenge.jsx:1517` sagt über diesen Filter selbst: „compact
/// multi-select grid, **same domains as Tour**". Der Tour-Planer rendert
/// dieselben acht Werte mit denselben Emojis und holt die Beschriftung über
/// `t('tour.genre.<stamm>.label')` (`screen-map.jsx:770-777`). Der
/// Challenge-Filter schreibt sie stattdessen als Literal ins JSX. Beide Listen
/// sagen dasselbe, also gewinnt hier die, die einen Schlüssel hat: eine
/// zwölffache Abschrift in `app_strings_supplement.dart` wäre eine zweite
/// Textquelle für Text, den die PWA übersetzt führt.
///
/// **Eine Beschriftung weicht dabei ab.** `Kunst` heißt im JSX „Kunst"
/// beziehungsweise „Arts", unter `tour.genre.arts.label` dagegen „Kunst &
/// Kultur" beziehungsweise „Arts & Culture". Das ist die einzige der acht, und
/// es ist eine bewusste Entscheidung gegen die Abschrift, keine Unachtsamkeit.
///
/// ## Warum diese Tabelle in `presentation` liegt
///
/// Sie trägt ein Emoji und einen Sprachschlüssel, also zwei
/// Oberflächen-Angaben. Was der Generator davon braucht, ist allein [code],
/// und er nimmt ihn als `String` entgegen, wie die Quelle.
enum ChallengeGenre {
  /// `📜 Geschichte`, `:1528`.
  history(
    code: 'Geschichte',
    emoji: '📜',
    labelKey: 'tour.genre.history.label',
  ),

  /// `👤 Persönlichkeit`, `:1529`.
  people(
    code: 'Persönlichkeit',
    emoji: '👤',
    labelKey: 'tour.genre.people.label',
  ),

  /// `🏛 Architektur`, `:1530`.
  architecture(
    code: 'Architektur',
    emoji: '🏛',
    labelKey: 'tour.genre.arch.label',
  ),

  /// `🐉 Mythos`, `:1531`.
  myth(code: 'Mythos', emoji: '🐉', labelKey: 'tour.genre.myth.label'),

  /// `🎯 Kurioses`, `:1532`.
  curious(code: 'Kurioses', emoji: '🎯', labelKey: 'tour.genre.curious.label'),

  /// `🌳 Natur`, `:1533`.
  nature(code: 'Natur', emoji: '🌳', labelKey: 'tour.genre.nature.label'),

  /// `🔬 Wissenschaft`, `:1534`.
  science(
    code: 'Wissenschaft',
    emoji: '🔬',
    labelKey: 'tour.genre.science.label',
  ),

  /// `🎨 Kunst`, `:1535`.
  arts(code: 'Kunst', emoji: '🎨', labelKey: 'tour.genre.arts.label');

  const ChallengeGenre({
    required this.code,
    required this.emoji,
    required this.labelKey,
  });

  /// Der Wert, wie er in `facts.genre` steht.
  final String code;

  /// Das Sinnbild auf der Kachel.
  final String emoji;

  /// Der i18n-Schlüssel der Beschriftung.
  final String labelKey;
}
