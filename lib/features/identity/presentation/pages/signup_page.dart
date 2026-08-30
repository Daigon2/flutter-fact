import 'dart:async';

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/core/widgets/primary_button.dart';
import 'package:fact_app/features/identity/presentation/formatting/auth_failure_text.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/signup_notifier.dart';
import 'package:fact_app/features/identity/presentation/notifiers/username_check_notifier.dart';
import 'package:fact_app/features/identity/presentation/notifiers/username_suggestion.dart';
import 'package:fact_app/features/identity/presentation/state/auth_city.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_checkbox.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_divider.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_error_box.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_field.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_header.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_notice_box.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_oauth_row.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_top_glow.dart';
import 'package:fact_app/features/identity/presentation/widgets/city_picker.dart';
import 'package:fact_app/features/identity/presentation/widgets/password_strength_meter.dart';
import 'package:fact_app/features/identity/presentation/widgets/signup_progress_bar.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pressable.dart';
import 'package:fact_app/features/identity/presentation/widgets/username_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Die Registrierung, `02_Frontend/app/screen-auth.jsx:569-814`
/// (`SignupScreen`).
///
/// Benutzt die geteilten Bausteine aus Schritt 9 (`AuthHeader`, `AuthField`,
/// `AuthCheckbox`, `AuthDivider`, `AuthOAuthRow`, `AuthErrorBox`,
/// `AuthTopGlow`, `PrimaryButton`) und ergänzt vier eigene: `SignupProgressBar`,
/// `UsernameField`, `PasswordStrengthMeter` und `CityPicker`. Jeder davon ist
/// dort begründet, wo er steht.
///
/// ## Kein `<form>`, also kein Absenden mit der Eingabetaste
///
/// Wie bei der Anmeldung: die Quelle hat kein Formularelement, die Felder sind
/// einzelne `<input>`. Eine Eingabetaste löst dort nichts aus, und hier deshalb
/// auch nicht.
///
/// ## Der Ladezustand sperrt nur den Knopf
///
/// Samt Wechsel der Beschriftung auf `onboarding.loading` und Deckkraft 0.6.
/// Zurück-Pfeil, Felder und der Wechsel zur Anmeldung bleiben bedienbar, genau
/// wie in der Quelle.
///
/// ## Was die Quelle hier tut und dieser Nachbau nicht
///
/// `Storage.setUser({ name, username, hometown, joinDate })` und
/// `onProfileSave(...)`. Beides ist ein **lokaler** Nutzerspeicher, den es im
/// Neubau nicht gibt: das Profil kommt in Phase 7 und liest dann aus `profiles`.
/// Das Beitrittsdatum schreibt die Quelle zusätzlich bei jeder Anmeldung neu
/// (`screen-auth.jsx:469`), es wandert also mit; auch das ist nicht übernommen,
/// siehe die Begründung in `LoginPage`.
class SignupPage extends ConsumerStatefulWidget {
  /// Erzeugt die Registrierung.
  const SignupPage({super.key});

  /// `paddingTop: 52` des Scroll-Containers.
  static const double topInset = 52;

  /// `paddingBottom: 28` des Scroll-Containers.
  static const double bottomInset = 28;

  /// `padding: '28px 24px 20px'` des Hero-Blocks.
  static const EdgeInsets heroPadding = EdgeInsets.only(
    top: 28,
    left: 24,
    right: 24,
    bottom: 20,
  );

  /// `padding: '0 22px'` des Formularblocks.
  static const double formHorizontalPadding = 22;

  /// `marginBottom: 18` unter der Einwilligung.
  static const double termsBottomSpacing = 18;

  /// `marginBottom: 26` unter den Fremdanmeldungen.
  static const double oauthBottomSpacing = 26;

  /// `marginBottom: 14` unter der Fußzeile.
  static const double footerBottomSpacing = 14;

  /// `fontSize: 30` des Hero-Titels. **Nicht** die 32 der Anmeldung.
  static const double heroTitleFontSize = 30;

  /// Deckkraft des Primärknopfes während der Registrierung.
  static const double submittingOpacity = 0.6;

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _citySearch = TextEditingController();

  /// `React.useState(AUTH_CITIES[0])`: München ist vorbelegt.
  AuthCity _selectedCity = authCities.first;

  /// `React.useState(false)`: die Einwilligung ist beim Öffnen **nicht** gesetzt.
  bool _termsAccepted = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _citySearch.dispose();
    super.dispose();
  }

  /// Der Zurück-Weg, `onNav('onboarding')` in der Quelle.
  ///
  /// Dieselbe Begründung wie in `LoginPage`: über `push` erreicht gibt es etwas
  /// zu schließen, über einen Deep Link auf `/signup` nicht, und dann führt der
  /// Pfeil dorthin, wohin die Quelle ihn führt.
  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    const SplashRoute().go(context);
  }

  /// Wechsel zur Anmeldung, `onNav('login')`.
  ///
  /// `pushReplacement` aus demselben Grund wie umgekehrt in `LoginPage`: der
  /// Zurück-Pfeil der Anmeldung soll auf den Startbildschirm führen, nicht auf
  /// die Registrierung.
  void _openLogin() => const LoginRoute().pushReplacement(context);

  /// `unawaited` und nicht `reportDetached`: dieses `Future` trägt keinen
  /// Schreibvorgang und kann nicht scheitern, weil [SignupNotifier.submit]
  /// jeden Fehlschlag in seinen Zustand legt statt zu werfen.
  void _submit() => unawaited(_signUp());

  Future<void> _signUp() async {
    final signedIn = await ref
        .read(signupProvider.notifier)
        .submit(
          email: _email.text,
          password: _password.text,
          username: _username.text,
          usernameStatus: ref.read(usernameCheckProvider),
          termsAccepted: _termsAccepted,
          hometown: _selectedCity.name,
        );
    if (!signedIn || !mounted) {
      // `false` heißt: Eingabefehler, Serverfehler oder der Bestätigungsfall.
      // Alle drei bleiben auf dem Formular, den Text liefert der Zustand.
      return;
    }
    // Die Erstlauf-Merkung erst **nach** erfolgreicher Registrierung, wie bei
    // der Anmeldung. `reportDetached` statt `unawaited`, weil hier ein
    // Schreibvorgang dranhängt.
    reportDetached(
      ref.read(firstLaunchProvider.notifier).markLaunched(),
      origin: 'identity.first_launch.mark',
    );
    if (!mounted) {
      return;
    }
    // Navigation gehört in die Seite, nicht in den Notifier (Regel 12).
    const MapRoute().go(context);
  }

  void _toggleTerms() => setState(() => _termsAccepted = !_termsAccepted);

  void _togglePasswordVisibility() =>
      setState(() => _passwordVisible = !_passwordVisible);

  void _onUsernameChanged(String value) =>
      ref.read(usernameCheckProvider.notifier).onChanged(value);

  /// Ein Tap auf eine Stadt, `screen-auth.jsx:751-758`.
  ///
  /// Nebenwirkung der Quelle: ist das Username-Feld **leer**, erzeugt die
  /// Stadtwahl einen Vorschlag und prüft ihn sofort. Bei gefülltem Feld passiert
  /// nichts davon, ein vom Nutzer getippter Name wird also nie überschrieben.
  void _onCitySelected(AuthCity city) {
    setState(() => _selectedCity = city);
    if (_username.text.isNotEmpty) {
      return;
    }
    final suggestion = suggestUsername(
      city.name,
      randomIndex: ref.read(randomIndexProvider),
    );
    _username.text = suggestion;
    // Die Quelle ruft `handleUsernameChange(sug)` ausdrücklich mit auf: ein
    // programmatisch gesetzter Wert löst kein `onChange` aus.
    _onUsernameChanged(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final submission = ref.watch(signupProvider);
    final colors = context.factColors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        // Wie bei Startbildschirm und Anmeldung um den **ganzen** Stapel: das
        // Inset ist in der Quelle ein `padding` des `body`
        // (`index.html:101-107`) und verschiebt damit auch den Lichtkegel.
        child: Stack(
          children: <Widget>[
            // Der Lichtkegel liegt **außerhalb** des Scrollbereichs und bleibt
            // beim Scrollen stehen. In der Quelle liegt er als erstes Kind
            // *innerhalb* des Scrollers und wandert mit nach oben. Übernommen
            // aus Schritt 9, damit Anmeldung und Registrierung denselben Kopf
            // haben; sichtbar wird der Unterschied nur, wenn man weit scrollt.
            const Positioned(top: 0, left: 0, right: 0, child: AuthTopGlow()),
            // Die Fußzeile ist hier, anders als bei der Anmeldung, **im Fluss**:
            // die Quelle setzt sie nicht `absolute`. Sie scrollt also mit.
            SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: SignupPage.topInset,
                bottom: SignupPage.bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Anders als die Anmeldung **mit** Titel
                  // (`screen-auth.jsx:764`).
                  AuthHeader(
                    onBack: _close,
                    title: strings.text('signup.stepTitle'),
                  ),
                  const SignupProgressBar(),
                  _hero(strings, colors),
                  _form(strings, colors, submission),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `screen-auth.jsx:775-782`.
  ///
  /// Der Titel steht in der Quelle in einem `dangerouslySetInnerHTML`. Geprüft:
  /// `signup.heroTitle` enthält in **beiden** Sprachen kein Markup ("Leg los.",
  /// "Get started."), ein einfacher Text ist also nicht nur einfacher, sondern
  /// gleichwertig.
  Widget _hero(AppStrings strings, FactColors colors) {
    return Padding(
      padding: SignupPage.heroPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.text('signup.xpBadge').toUpperCase(),
            style: FactTypography.mono.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.red,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.text('signup.heroTitle'),
            style: FactTypography.displayTitle.copyWith(
              fontSize: SignupPage.heroTitleFontSize,
              color: colors.ink,
              height: 1.05,
              letterSpacing: FactTypography.displayTracking(
                SignupPage.heroTitleFontSize,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.text('signup.heroBody'),
            style: FactTypography.bodyText.copyWith(
              fontSize: 14,
              color: colors.ink2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// `screen-auth.jsx:784-812`. Reihenfolge wie dort.
  Widget _form(
    AppStrings strings,
    FactColors colors,
    AsyncValue<SignupStatus> submission,
  ) {
    final submitting = submission.isLoading;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SignupPage.formHorizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (submission.error case final Object error)
            AuthErrorBox(
              message: strings.text(
                // Der Sammeltext der Registrierung ist ein anderer als der der
                // Anmeldung, siehe `auth_failure_text.dart`.
                authFailureTextKey(error, genericKey: signupGenericKey),
              ),
            ),
          if (submission case AsyncData<SignupStatus>(
            value: SignupStatus.emailConfirmationPending,
          ))
            AuthNoticeBox(message: strings.text('signup.confirmEmailHint')),
          UsernameField(
            controller: _username,
            status: ref.watch(usernameCheckProvider),
            onChanged: _onUsernameChanged,
            label: strings.text('username.label'),
            placeholder: strings.text('username.placeholder'),
            hint: strings.text('username.hint'),
            checkingBadge: strings.text('username.checking'),
            takenBadge: strings.text('username.taken'),
          ),
          AuthField(
            label: strings.text('onboarding.email'),
            placeholder: strings.text('onboarding.emailPlaceholder'),
            controller: _email,
            icon: '✉',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
          ),
          AuthField(
            label: strings.text('onboarding.password'),
            // Anders als die Anmeldung: der Platzhalter ist hier ein Text
            // ("Mind. 6 Zeichen") und nicht eine Reihe von Punkten.
            placeholder: strings.text('onboarding.passwordHint'),
            controller: _password,
            icon: '🔒',
            obscureText: !_passwordVisible,
            // `autoComplete="new-password"`: der Passwortspeicher soll ein neues
            // Passwort vorschlagen, nicht das gespeicherte einsetzen.
            autofillHints: const <String>[AutofillHints.newPassword],
            trailing: _passwordVisibilityToggle(strings, colors),
          ),
          // `{password.length > 0 && <AuthPwStrength .../>}`: bei leerem Feld
          // gibt es die Anzeige nicht.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _password,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : PasswordStrengthMeter(
                    score: passwordStrengthScore(value.text),
                  ),
          ),
          CityPicker(
            cities: authCities,
            selected: _selectedCity,
            searchController: _citySearch,
            onSelected: _onCitySelected,
            label: strings.text('signup.homeCity'),
            optionalSuffix: strings.text('signup.optional'),
            searchPlaceholder: strings.text('signup.citySearchPlaceholder'),
            activeBonusLabel: strings.text('signup.cityActiveBonus'),
            factsCountLabel: (city) => strings.text(
              'signup.cityFactsCount',
              params: <String, String>{'n': '${city.facts}'},
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              bottom: SignupPage.termsBottomSpacing,
            ),
            child: _terms(strings, colors),
          ),
          Opacity(
            opacity: submitting ? SignupPage.submittingOpacity : 1,
            child: PrimaryButton(
              label: strings.text(
                submitting ? 'onboarding.loading' : 'splash.createAccountCta',
              ),
              onPressed: submitting ? null : _submit,
              // `padding: '15px', fontSize: 17` überschreiben die Maße von
              // `.btn`.
              padding: const EdgeInsets.all(15),
              fontSize: 17,
            ),
          ),
          const AuthDivider(),
          Padding(
            padding: const EdgeInsets.only(
              bottom: SignupPage.oauthBottomSpacing,
            ),
            child: AuthOAuthRow(
              appleLabel: strings.text('auth.appleSoon'),
              googleLabel: strings.text('auth.googleSoon'),
              comingSoonHint: strings.text('auth.comingSoon'),
            ),
          ),
          _footer(strings, colors),
        ],
      ),
    );
  }

  /// Der Sichtbarkeitsschalter im Passwortfeld, `screen-auth.jsx:729-731`.
  Widget _passwordVisibilityToggle(AppStrings strings, FactColors colors) {
    return SplashPressable(
      onPressed: _togglePasswordVisibility,
      child: Text(
        strings
            .text(_passwordVisible ? 'login.pwHide' : 'login.pwShow')
            .toUpperCase(),
        style: FactTypography.mono.copyWith(
          fontSize: 10,
          color: colors.ink3,
          letterSpacing: 0.15,
        ),
      ),
    );
  }

  /// Die Einwilligung, `screen-auth.jsx:781-786`.
  ///
  /// Vier Textbausteine, zwei davon rot und fett. Sie sind **keine Links**, siehe
  /// die Begründung an `AuthCheckbox.labelSpans`.
  Widget _terms(AppStrings strings, FactColors colors) {
    final prefix = strings.text('signup.agbPrefix');
    final terms = strings.text('signup.agbTerms');
    final and = strings.text('signup.agbAnd');
    final privacy = strings.text('signup.agbPrivacy');
    final highlight = TextStyle(color: colors.red, fontWeight: FontWeight.w700);
    return AuthCheckbox(
      checked: _termsAccepted,
      // Der Punkt am Ende steht in der Quelle im Markup, nicht in der
      // Übersetzung.
      label: '$prefix $terms $and $privacy.',
      labelSpans: <InlineSpan>[
        TextSpan(text: '$prefix '),
        TextSpan(text: terms, style: highlight),
        TextSpan(text: ' $and '),
        TextSpan(text: privacy, style: highlight),
        const TextSpan(text: '.'),
      ],
      onChanged: _toggleTerms,
    );
  }

  /// `screen-auth.jsx:806-811`.
  ///
  /// Im Fluss und mittig, mit denselben zwei bewussten Abweichungen wie bei der
  /// Anmeldung: eine Lücke von 4 Pixeln statt eines Leerzeichens, und beide Teile
  /// dürfen umbrechen. Der Grund ist die Antippbarkeit des Links.
  Widget _footer(AppStrings strings, FactColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SignupPage.footerBottomSpacing),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: <Widget>[
          Text(
            strings.text('signup.alreadyMember'),
            style: FactTypography.bodyText.copyWith(
              fontSize: 13,
              color: colors.ink2,
            ),
          ),
          SplashPressable(
            onPressed: _openLogin,
            child: Text(
              strings.text('auth.signIn'),
              style: FactTypography.heading.copyWith(
                fontSize: 13,
                color: colors.red,
                decoration: TextDecoration.underline,
                decorationColor: const Color.fromRGBO(232, 56, 13, 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
