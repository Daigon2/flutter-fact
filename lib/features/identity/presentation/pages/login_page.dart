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
import 'package:fact_app/features/identity/presentation/notifiers/login_notifier.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_checkbox.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_divider.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_error_box.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_field.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_header.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_oauth_row.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_top_glow.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Die Anmeldung, `02_Frontend/app/screen-auth.jsx:428-556` (`LoginScreen`).
///
/// ## Was hier absichtlich fehlt: der Passwort-Reset
///
/// Die Quelle hängt am Passwort-Label einen Knopf "Vergessen?", der
/// `resetPasswordForEmail` mit `redirectTo: window.location.origin + '/'`
/// aufruft (`screen-auth.jsx:440-457`). Beides gibt es hier nicht, und zwar aus
/// einem geprüften Grund, nicht aus Zeitmangel:
///
/// 1. **Eine Web-Origin existiert in einer App nicht.** Ein Deep-Link-Ziel für
///    den Reset wäre eine neue öffentliche Vertragsfläche und gehört nicht in
///    diesen Schritt.
/// 2. **Der naheliegende Ausweg ist nachweislich kaputt.** `redirectTo`
///    weglassen und die im Supabase-Projekt konfigurierte Standard-URL greifen
///    lassen, würde eine Mail schicken, deren Link niemand einlösen kann:
///    `supabase_flutter 2.17.2` benutzt standardmäßig
///    `AuthFlowType.pkce` (`supabase-2.16.1`,
///    `supabase_client_options.dart:42`), und `resetPasswordForEmail` legt den
///    zugehörigen Code-Verifier **auf dem Gerät** ab
///    (`gotrue_client.dart:1113-1130`). Der Link landet dann in der PWA, die den
///    Verifier nicht hat, und der Tausch scheitert.
///
/// **Was der Nutzer sieht:** die Label-Zeile über dem Passwortfeld zeigt nur
/// "PASSWORT". Kein Knopf, der nichts tut, und kein roter Text, der wie ein
/// Knopf aussieht. Wer sein Passwort vergessen hat, setzt es solange über die
/// PWA zurück. Das ist eine offene Stelle und gehört als solche in den
/// Statusbericht, nicht als Kommentar an einen tauben Knopf.
///
/// ## "Angemeldet bleiben" hat keine Wirkung, in der Quelle genauso
///
/// `stayIn` wird in `screen-auth.jsx:431` gesetzt und **nirgends gelesen**;
/// `persistSession` kommt in der ganzen PWA nicht vor. Das Kästchen ist hier
/// nachgebaut, weil es sichtbarer Teil des Bildschirms ist, aber es steuert
/// nichts. Eine echte Sitzungspersistenz-Semantik einzuführen wäre eine
/// Auth-Verhaltensänderung und braucht eine Freigabe.
///
/// ## `joinDate` wird nicht gesetzt
///
/// Die Quelle schreibt bei **jeder** Anmeldung `new Date()` als Beitrittsdatum
/// (`screen-auth.jsx:469`). Das ist ein Defekt: das Beitrittsdatum wandert damit
/// bei jeder Anmeldung nach vorn. Nicht übernommen. Ein lokaler Nutzerspeicher
/// existiert im Neubau ohnehin nicht, das Profil kommt in Phase 7.
///
/// ## Ladezustand
///
/// Gesperrt wird **nur** der Primärknopf, samt Wechsel der Beschriftung auf
/// `onboarding.loading`. Kein Spinner, kein gesperrter Bildschirm: Zurück-Pfeil
/// und der Wechsel zur Registrierung bleiben bedienbar, genau wie in der Quelle.
/// Was dabei passieren kann und wofür es einen Test gibt: der Nutzer verlässt
/// den Bildschirm, während `signIn` noch läuft. Die Absicherung steckt in
/// [LoginNotifier] (`ref.mounted`) und in den `mounted`-Prüfungen unten.
class LoginPage extends ConsumerStatefulWidget {
  /// Erzeugt die Anmeldung.
  const LoginPage({super.key});

  /// `paddingTop: 52` des Scroll-Containers.
  static const double topInset = 52;

  /// `padding: '32px 24px 22px'` des Hero-Blocks.
  static const EdgeInsets heroPadding = EdgeInsets.only(
    top: 32,
    left: 24,
    right: 24,
    bottom: 22,
  );

  /// `padding: '0 22px'` des Formularblocks.
  static const double formHorizontalPadding = 22;

  /// `bottom: 28` der Fußzeile.
  static const double footerBottomInset = 28;

  /// `padding: '0 24px'` der Fußzeile.
  static const double footerHorizontalPadding = 24;

  /// Deckkraft des Primärknopfes während der Anmeldung, `opacity: loading ? 0.6
  /// : 1`.
  static const double submittingOpacity = 0.6;

  /// Platzhalter des Passwortfeldes, in der Quelle hartcodiert
  /// (`screen-auth.jsx:509`). Es gibt dafür keinen i18n-Schlüssel.
  static const String passwordPlaceholder = '••••••••';

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  /// `React.useState(true)`: das Kästchen ist beim Öffnen gesetzt.
  bool _staySignedIn = true;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Der Zurück-Weg, `onNav('onboarding')` in der Quelle.
  ///
  /// Der Startbildschirm öffnet die Anmeldung mit `push`, es gibt also etwas zu
  /// schließen. Über einen Deep Link auf `/login` gibt es das nicht, und
  /// `context.pop()` würde werfen; dann führt der Pfeil dorthin, wo die Quelle
  /// ihn hinführt.
  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    const SplashRoute().go(context);
  }

  /// `unawaited` und nicht `reportDetached`: dieses `Future` trägt keinen
  /// Schreibvorgang. Es kann auch nicht scheitern, weil [LoginNotifier.signIn]
  /// jeden Fehlschlag in seinen Zustand legt statt zu werfen.
  void _submit() => unawaited(_signIn());

  Future<void> _signIn() async {
    final succeeded = await ref
        .read(loginProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    if (!succeeded || !mounted) {
      return;
    }
    // Die Erstlauf-Merkung erst **nach** erfolgreicher Anmeldung, anders als in
    // der PWA, die sie in jeder Navigation setzt (`app.jsx:476-477`) und das in
    // `app.jsx:525-527` selbst nachbessern muss.
    //
    // `reportDetached` statt `unawaited`: hier hängt ein Schreibvorgang dran,
    // und ein stilles Scheitern hieße, dass der Startbildschirm nach dem
    // Neustart wieder erscheint, ohne Spur davon.
    reportDetached(
      ref.read(firstLaunchProvider.notifier).markLaunched(),
      origin: 'identity.first_launch.mark',
    );
    if (!mounted) {
      return;
    }
    // Navigation gehört in die Seite, nicht in den Notifier (Regel 12). `go`
    // und nicht `pop`: nach der Anmeldung soll der Startbildschirm nicht mehr
    // im Stapel liegen.
    const MapRoute().go(context);
  }

  void _toggleStaySignedIn() => setState(() => _staySignedIn = !_staySignedIn);

  void _togglePasswordVisibility() =>
      setState(() => _passwordVisible = !_passwordVisible);

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final submission = ref.watch(loginProvider);
    final colors = context.factColors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        // Wie beim Startbildschirm um den **ganzen** Stapel: das Inset ist in
        // der Quelle ein `padding` des `body` (`index.html:101-107`) und
        // verschiebt damit auch den Lichtkegel.
        child: Stack(
          children: <Widget>[
            const Positioned(top: 0, left: 0, right: 0, child: AuthTopGlow()),
            Column(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SizedBox(height: LoginPage.topInset),
                        AuthHeader(onBack: _close),
                        _hero(strings, colors),
                        _form(strings, submission),
                      ],
                    ),
                  ),
                ),
                _footer(strings, colors),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// `screen-auth.jsx:487-493`.
  Widget _hero(AppStrings strings, FactColors colors) {
    return Padding(
      padding: LoginPage.heroPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.text('login.welcomeBack').toUpperCase(),
            style: FactTypography.mono.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.red,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.text('login.heroTitle'),
            style: FactTypography.displayTitle.copyWith(
              fontSize: 32,
              color: colors.ink,
              height: 1.05,
              letterSpacing: FactTypography.displayTracking(32),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.text('login.heroBody'),
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

  /// `screen-auth.jsx:495-546`. Reihenfolge wie dort: Fehlerbox, E-Mail,
  /// Passwort, Kästchen, Primärknopf, Trenner, Fremdanmeldungen.
  Widget _form(AppStrings strings, AsyncValue<void> submission) {
    final submitting = submission.isLoading;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LoginPage.formHorizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (submission.error case final Object error)
            AuthErrorBox(message: strings.text(authFailureTextKey(error))),
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
            placeholder: LoginPage.passwordPlaceholder,
            controller: _password,
            icon: '🔒',
            obscureText: !_passwordVisible,
            autofillHints: const <String>[AutofillHints.password],
            trailing: _passwordVisibilityToggle(strings),
          ),
          // `margin: '6px 0 22px'` am Kästchen.
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 22),
            child: AuthCheckbox(
              checked: _staySignedIn,
              label: strings.text('login.stayIn'),
              onChanged: _toggleStaySignedIn,
            ),
          ),
          Opacity(
            opacity: submitting ? LoginPage.submittingOpacity : 1,
            child: PrimaryButton(
              label: strings.text(
                submitting ? 'onboarding.loading' : 'onboarding.loginBtn',
              ),
              onPressed: submitting ? null : _submit,
              // `padding: '15px', fontSize: 17` überschreiben die Maße von
              // `.btn`.
              padding: const EdgeInsets.all(15),
              fontSize: 17,
            ),
          ),
          const AuthDivider(),
          AuthOAuthRow(
            appleLabel: strings.text('auth.appleSoon'),
            googleLabel: strings.text('auth.googleSoon'),
            comingSoonHint: strings.text('auth.comingSoon'),
          ),
        ],
      ),
    );
  }

  /// Der Sichtbarkeitsschalter im Passwortfeld, `screen-auth.jsx:516-518`.
  Widget _passwordVisibilityToggle(AppStrings strings) {
    return SplashPressable(
      onPressed: _togglePasswordVisibility,
      child: Text(
        strings
            .text(_passwordVisible ? 'login.pwHide' : 'login.pwShow')
            .toUpperCase(),
        style: FactTypography.mono.copyWith(
          fontSize: 10,
          color: context.factColors.ink3,
          letterSpacing: 0.15,
        ),
      ),
    );
  }

  /// `screen-auth.jsx:548-555`.
  ///
  /// ## Zwei bewusste Abweichungen
  ///
  /// 1. Die Quelle setzt die Fußzeile `position: absolute; bottom: 28` **über**
  ///    den Inhalt. Hier sitzt sie unter dem Scrollbereich, mit demselben
  ///    Abstand von 28 zum unteren Rand. Auf der Bildschirmhöhe der Quelle
  ///    (844) ist das dasselbe Bild; auf einem kurzen Bildschirm überdeckt die
  ///    Fußzeile in der Quelle das Formular, hier nicht.
  /// 2. Zwischen Text und Link steht in der Quelle ein Leerzeichen
  ///    (`{' '}`), hier eine Lücke von 4 Pixeln, und beide Teile können
  ///    umbrechen statt als ein Absatz zu fließen. Der Grund ist die
  ///    Antippbarkeit: ein `TextSpan` mit Erkenner wäre nur so groß wie die
  ///    Glyphen und bräuchte eine eigene Lebensdauer-Verwaltung.
  ///
  /// `textUnderlineOffset: 3` hat in Flutter keine Entsprechung und fehlt
  /// deshalb. Die Unterstreichungsfarbe `rgba(232,56,13,0.4)` gibt es.
  Widget _footer(AppStrings strings, FactColors colors) {
    return Padding(
      padding: const EdgeInsets.only(
        left: LoginPage.footerHorizontalPadding,
        right: LoginPage.footerHorizontalPadding,
        bottom: LoginPage.footerBottomInset,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: <Widget>[
          Text(
            strings.text('login.noAccount'),
            style: FactTypography.bodyText.copyWith(
              fontSize: 13,
              color: colors.ink2,
            ),
          ),
          SplashPressable(
            onPressed: _openSignup,
            child: Text(
              strings.text('auth.createAccount'),
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

  /// Wechsel zur Registrierung.
  ///
  /// `pushReplacement` wäre der naheliegende Weg und der falsche: die Quelle
  /// ruft `onNav('signup')`, und der Zurück-Pfeil der Registrierung führt dort
  /// wieder auf den Startbildschirm (`screen-auth.jsx:816`), nicht auf die
  /// Anmeldung. `pushReplacement` ersetzt die Anmeldung im Stapel, der
  /// Startbildschirm bleibt darunter liegen, und der Pfeil landet genau dort.
  ///
  /// Anders als `push` liefert `pushReplacement` in der erzeugten Route kein
  /// `Future`, es gibt hier also nichts loszulassen.
  void _openSignup() => const SignupRoute().pushReplacement(context);
}
