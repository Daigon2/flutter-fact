import 'package:fact_app/features/challenges/presentation/challenge_genre.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die acht Themen des Assistenten, `screen-challenge.jsx:1518-1536`.
void main() {
  test('die acht Werte stehen in der Reihenfolge der Quelle', () {
    expect(ChallengeGenre.values, hasLength(8));
    expect(
      ChallengeGenre.values.map((ChallengeGenre genre) => genre.name),
      <String>[
        'history',
        'people',
        'architecture',
        'myth',
        'curious',
        'nature',
        'science',
        'arts',
      ],
    );
  });

  test('jeder Code steht wörtlich so in der Spalte facts.genre', () {
    // **Der einzige datenwirksame Wert dieser Klasse.** Der Generator
    // vergleicht ihn gegen `Fact.genre` (`hunt-generator.jsx:172`), und die
    // erlaubten Werte stehen als `CHECK`-Bedingung `facts_genre_check` im
    // geteilten Backend. Ein Tippfehler fällt nirgends auf: der Filter findet
    // nichts, der Generator lockert ihn weich (`:171-175`), und der Nutzer
    // bekommt eine Jagd ohne sein Thema.
    //
    // Die Werte stehen hier als Literale und nicht als Ausdruck über die
    // Aufzählung: eine Zusicherung gegen die Konstante, die sie festnageln
    // soll, ist immer wahr.
    expect(ChallengeGenre.history.code, 'Geschichte');
    expect(ChallengeGenre.people.code, 'Persönlichkeit');
    expect(ChallengeGenre.architecture.code, 'Architektur');
    expect(ChallengeGenre.myth.code, 'Mythos');
    expect(ChallengeGenre.curious.code, 'Kurioses');
    expect(ChallengeGenre.nature.code, 'Natur');
    expect(ChallengeGenre.science.code, 'Wissenschaft');
    expect(ChallengeGenre.arts.code, 'Kunst');
  });

  test('kein Code kommt zweimal vor', () {
    expect(
      ChallengeGenre.values.map((ChallengeGenre genre) => genre.code).toSet(),
      hasLength(ChallengeGenre.values.length),
    );
  });

  test('die Sinnbilder sind die der Quelle', () {
    // `:1528-1535`. Dieselbe Spalte wie im Tour-Planer
    // (`screen-map.jsx:770-777`), deshalb fällt eine Abweichung sonst
    // nirgends auf.
    expect(
      ChallengeGenre.values.map((ChallengeGenre genre) => genre.emoji),
      <String>['📜', '👤', '🏛', '🐉', '🎯', '🌳', '🔬', '🎨'],
    );
  });

  test('die Beschriftungen kommen aus dem Tour-Wörterbuch', () {
    // Der Challenge-Filter schreibt seine Beschriftungen als Literal ins JSX
    // (`:1518-1536`), der Tour-Planer holt dieselben acht über
    // `tour.genre.<stamm>.label`. Weil beide dasselbe meinen, gewinnt hier
    // die Fassung mit Schlüssel; die Begründung steht an der Aufzählung.
    expect(
      ChallengeGenre.values.map((ChallengeGenre genre) => genre.labelKey),
      <String>[
        'tour.genre.history.label',
        'tour.genre.people.label',
        'tour.genre.arch.label',
        'tour.genre.myth.label',
        'tour.genre.curious.label',
        'tour.genre.nature.label',
        'tour.genre.science.label',
        'tour.genre.arts.label',
      ],
    );
  });
}
