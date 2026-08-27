import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/identity/presentation/state/auth_city.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_field.dart';
import 'package:fact_app/features/identity/presentation/widgets/css_gradient_geometry.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pressable.dart';
import 'package:flutter/material.dart';

/// Der Stadt-Picker der Registrierung,
/// `02_Frontend/app/screen-auth.jsx:738-777`.
///
/// Suchfeld plus Liste. Die Auswahl gehört dem Aufrufer, dieses Widget hält
/// nichts außer dem Text im Suchfeld, und den auch nur über den mitgegebenen
/// [searchController].
///
/// ## "Optional" ist eine Falschaussage der Quelle
///
/// Das Label sagt `signup.homeCity · signup.optional`, und die Auswahl ist
/// **nicht** leerbar: sie startet auf `authCities.first`, jeder Tap setzt eine
/// neue Stadt, und es gibt keinen Weg zurück auf "keine". Die Heimatstadt geht
/// damit immer an die Registrierung, auch wenn der Nutzer den Picker nie
/// angefasst hat. Nachgebaut wie die Quelle, weil ein leerbarer Zustand neues
/// Verhalten wäre: der Nachbau müsste entscheiden, was dann in
/// `raw_user_meta_data.hometown` steht, und das ist eine Datenfrage, keine
/// Oberflächenfrage.
///
/// Deshalb ist [selected] auch nicht nullbar. Ein `AuthCity?` hätte einen
/// Zustand zugelassen, den es nicht gibt.
///
/// ## Leeres Suchergebnis rendert eine leere Liste
///
/// Kein Hinweistext, keine Grafik. `onboarding.noCityFound` ("Keine Stadt
/// gefunden") **existiert** als i18n-Schlüssel und wird in der ganzen PWA
/// **nirgends** benutzt. Der Schlüssel bleibt hier ungenutzt, damit der
/// Bildschirm der Quelle entspricht; wer ihn einsetzt, ändert Verhalten.
class CityPicker extends StatelessWidget {
  /// [cities] ist die Liste, aus der gewählt wird, [selected] der aktuelle
  /// Eintrag.
  const CityPicker({
    required this.cities,
    required this.selected,
    required this.searchController,
    required this.onSelected,
    required this.label,
    required this.optionalSuffix,
    required this.searchPlaceholder,
    required this.activeBonusLabel,
    required this.factsCountLabel,
    super.key,
  });

  /// `marginBottom: 16` am Wrapper.
  static const double bottomSpacing = 16;

  /// `padding: '10px 14px'` der Suchbox.
  static const EdgeInsets searchPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 10,
  );

  /// `borderRadius: 14` der Suchbox.
  static const double searchRadius = 14;

  /// `border: 1.5px solid` der Suchbox.
  static const double searchBorderWidth = 1.5;

  /// `gap: 10` in der Suchbox.
  static const double searchGap = 10;

  /// `marginBottom: 8` unter der Suchbox.
  static const double searchBottomSpacing = 8;

  /// `fontSize: 14` der Sucheingabe. **Nicht** die 15 der Formularfelder.
  static const double searchFontSize = 14;

  /// `fontSize: 14` der Lupe.
  static const double magnifierFontSize = 14;

  /// `opacity: 0.7` der Lupe.
  static const double magnifierOpacity = 0.7;

  /// `fontSize: 16` des Löschen-Zeichens.
  static const double clearFontSize = 16;

  /// `gap: 6` zwischen den Karten.
  static const double cardGap = 6;

  /// `padding: '10px 12px'` einer Karte.
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  );

  /// `borderRadius: 12` einer Karte.
  static const double cardRadius = 12;

  /// `gap: 12` in einer Karte.
  static const double cardGapInner = 12;

  /// Kantenlänge des Stadt-Symbols, `width/height: 32`.
  static const double markSize = 32;

  /// `borderRadius: 10` am Symbol.
  static const double markRadius = 10;

  /// `fontSize: 14` der Symbol-Glyphe.
  static const double markFontSize = 14;

  /// Kantenlänge der Auswahlmarke, `width/height: 20`.
  static const double badgeSize = 20;

  /// `fontSize: 11` in der Auswahlmarke.
  static const double badgeFontSize = 11;

  /// `fontSize: 14` des Stadtnamens.
  static const double nameFontSize = 14;

  /// `fontSize: 10` des Ländercodes.
  static const double countryFontSize = 10;

  /// `fontSize: 9` der Unterzeile.
  static const double detailFontSize = 9;

  /// `marginTop: 2` über der Unterzeile.
  static const double detailTopSpacing = 2;

  /// Die Lupe, in der Quelle als Zeichen hingeschrieben.
  static const String magnifierGlyph = '🔍';

  /// Das Löschen-Zeichen, ebenfalls ein Zeichen und kein Symbol.
  static const String clearGlyph = '×';

  /// Die Glyphe im Stadt-Symbol.
  static const String markGlyph = '🏛';

  /// Das Häkchen der Auswahlmarke.
  static const String badgeGlyph = '✓';

  /// `linear-gradient(145deg,#E8380Dcc,#E8380D)` am ausgewählten Symbol.
  ///
  /// Literale und keine Tokens, wie in der Quelle. `#E8380Dcc` ist `--red` mit
  /// 80 Prozent Deckkraft, es gibt dafür kein Token.
  static const Color markGradientStart = Color(0xCCE8380D);

  /// Zweiter Halt des Verlaufs, `#E8380D`.
  static const Color markGradientEnd = Color(0xFFE8380D);

  /// `boxShadow: '0 2px 0 #A82508'` an Symbol und Auswahlmarke.
  static const Color markShadowColor = Color(0xFFA82508);

  /// Die Winkel des Verlaufs, einmal gerechnet.
  static final ({Alignment begin, Alignment end}) _markGradient =
      cssLinearGradientEnds(
        angleDegrees: 145,
        box: const Size.square(markSize),
      );

  /// Die angebotenen Städte.
  ///
  /// Als Parameter und nicht als Konstante gelesen, damit die Liste ohne
  /// Änderung an diesem Widget umziehen kann, siehe `auth_city.dart`.
  final List<AuthCity> cities;

  /// Die gewählte Stadt. Nie `null`, siehe Klassendoku.
  final AuthCity selected;

  /// Der Text im Suchfeld. Gehört dem Aufrufer.
  final TextEditingController searchController;

  /// Wird mit der angetippten Stadt aufgerufen.
  final ValueChanged<AuthCity> onSelected;

  /// `signup.homeCity`.
  final String label;

  /// `signup.optional`.
  final String optionalSuffix;

  /// `signup.citySearchPlaceholder`.
  final String searchPlaceholder;

  /// `signup.cityActiveBonus`.
  final String activeBonusLabel;

  /// `signup.cityFactsCount`, mit `{n}` bereits ersetzt. Die Ersetzung gehört
  /// zum Aufrufer, weil nur er die Übersetzungen hat.
  final String Function(AuthCity city) factsCountLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.factColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AuthLabel(text: label, suffix: optionalSuffix),
          const SizedBox(height: AuthLabel.bottomSpacing),
          _searchBox(colors),
          const SizedBox(height: searchBottomSpacing),
          // `ValueListenableBuilder` und kein `setState` beim Aufrufer: das
          // Suchfeld filtert nur diese Liste, ein Neubau des ganzen Formulars
          // wäre dafür zu viel.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) => _list(colors, value.text),
          ),
        ],
      ),
    );
  }

  Widget _searchBox(FactColors colors) {
    final inputStyle = FactTypography.bodyText.copyWith(
      fontSize: searchFontSize,
      color: colors.ink,
    );
    return Container(
      padding: searchPadding,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: const BorderRadius.all(Radius.circular(searchRadius)),
        border: Border.fromBorderSide(
          BorderSide(color: colors.border2, width: searchBorderWidth),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Opacity(
            opacity: magnifierOpacity,
            child: Text(
              magnifierGlyph,
              style: TextStyle(fontSize: magnifierFontSize),
            ),
          ),
          const SizedBox(width: searchGap),
          Expanded(
            child: TextField(
              controller: searchController,
              style: inputStyle,
              cursorColor: colors.red,
              decoration: InputDecoration.collapsed(
                hintText: searchPlaceholder,
                hintStyle: inputStyle.copyWith(color: colors.ink3),
              ),
            ),
          ),
          // Nur bei gefüllter Suche, wie in der Quelle (`{cityQuery && ...}`).
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(left: searchGap),
                    child: SplashPressable(
                      onPressed: searchController.clear,
                      child: Text(
                        clearGlyph,
                        style: FactTypography.bodyText.copyWith(
                          fontSize: clearFontSize,
                          color: colors.ink3,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _list(FactColors colors, String query) {
    final matches = filterAuthCities(cities, query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < matches.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: cardGap),
          _card(colors, matches[i]),
        ],
      ],
    );
  }

  Widget _card(FactColors colors, AuthCity city) {
    final isSelected = city.name == selected.name;
    return SplashPressable(
      onPressed: () => onSelected(city),
      selected: isSelected,
      child: Container(
        padding: cardPadding,
        decoration: BoxDecoration(
          color: isSelected ? colors.surface2 : null,
          borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
          // Auch unausgewählt ein Rahmen, nur durchsichtig: sonst wackelte die
          // Höhe der Karte beim Auswählen um zwei Pixel.
          border: Border.fromBorderSide(
            BorderSide(
              color: isSelected ? colors.border2 : const Color(0x00000000),
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            _mark(colors, isSelected: isSelected),
            const SizedBox(width: cardGapInner),
            Expanded(child: _labels(colors, city, isSelected: isSelected)),
            if (isSelected) ...<Widget>[
              const SizedBox(width: cardGapInner),
              _selectionBadge(colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mark(FactColors colors, {required bool isSelected}) {
    return Container(
      width: markSize,
      height: markSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? null : colors.surface3,
        gradient: isSelected
            ? LinearGradient(
                begin: _markGradient.begin,
                end: _markGradient.end,
                colors: const <Color>[markGradientStart, markGradientEnd],
              )
            : null,
        borderRadius: const BorderRadius.all(Radius.circular(markRadius)),
        boxShadow: isSelected
            ? const <BoxShadow>[
                BoxShadow(color: markShadowColor, offset: Offset(0, 2)),
              ]
            : const <BoxShadow>[],
      ),
      child: const Text(markGlyph, style: TextStyle(fontSize: markFontSize)),
    );
  }

  Widget _labels(FactColors colors, AuthCity city, {required bool isSelected}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(text: city.name),
              // Der Ländercode ist in der Quelle ein `<span>` **im** Stadtnamen,
              // mit eigener Familie, Größe und Gewicht. Deshalb ein Span und
              // keine zweite Zeile.
              TextSpan(
                text: ' ${city.country}',
                style: FactTypography.mono.copyWith(
                  fontSize: countryFontSize,
                  color: colors.ink3,
                ),
              ),
            ],
          ),
          style: FactTypography.heading.copyWith(
            fontSize: nameFontSize,
            color: colors.ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: detailTopSpacing),
        Text(
          city.active ? activeBonusLabel : factsCountLabel(city),
          style: FactTypography.mono.copyWith(
            fontSize: detailFontSize,
            color: isSelected ? colors.red : colors.ink3,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _selectionBadge(FactColors colors) {
    return Container(
      width: badgeSize,
      height: badgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.red,
        // `borderRadius: 999` auf einer 20-Pixel-Fläche ist ein Kreis.
        shape: BoxShape.circle,
        boxShadow: const <BoxShadow>[
          BoxShadow(color: markShadowColor, offset: Offset(0, 2)),
        ],
      ),
      // DM Sans und nicht Nunito: die Auswahlmarke setzt in der Quelle nur
      // `fontWeight: 700` und erbt die Familie vom `body`, also DM Sans
      // (`styles.css:116`). Geladen sind davon 400, 500 und 600
      // (`pubspec.yaml`), die Engine nimmt für 700 den nächstliegenden Schnitt.
      // Einen siebten Schnitt für eine Glyphe zu schneiden wäre der falsche
      // Preis.
      child: Text(
        badgeGlyph,
        style: FactTypography.bodyText.copyWith(
          fontSize: badgeFontSize,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFFFFF),
          height: 1,
        ),
      ),
    );
  }
}
