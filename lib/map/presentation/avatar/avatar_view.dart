/// Die 3D-Figur in einem durchsichtigen WebView,
/// `08_Flutter/lib/widgets/tourist_3d.dart`.
///
/// Der einzige Ort im ganzen Projekt, an dem `webview_flutter` vorkommen darf.
/// Das ist Regel 19 im Architektur-Check, und sie hatte seit dem 31.08.2026
/// keinen Gegenstand mehr, weil der Avatar 2D werden sollte; seit dem
/// 02.09.2026 hat sie wieder einen.
///
/// ## Warum überhaupt ein WebView
///
/// Weil der teure Teil dort schon gelöst ist. Drei Wege standen zur Wahl
/// (WebView mit Three.js, `flutter_scene` auf `flutter_gpu`, eine
/// Spiel-Engine), abgewogen in `REBUILD_STATUS.md`. Bei den anderen zwei wäre
/// die Verankerung einer Figur auf einer sich bewegenden Karte neu zu bauen.
///
/// ## Dieses Widget entscheidet nichts
///
/// Und das ist Absicht. Ein WebView entsteht in keinem Widget-Test: es hängt
/// an einem Plattformkanal, und was darin passiert, sieht Flutter nicht. Alles,
/// was eine Entscheidung ist, liegt deshalb daneben und ist ohne Gerät
/// prüfbar:
///
/// * **welche Animation** gehört zu welcher Bewegung: `avatar_motion.dart`;
/// * **welcher Aufruf** geht hinaus und mit welchem Wert: `avatar_bridge.dart`;
/// * **wann** er hinausgeht, also nur bei Änderung: [avatarScriptsToSend].
///
/// Was hier bleibt, ist das Verdrahten: Steuerung anlegen, Asset laden, nach
/// dem Laden schicken, bei einer Änderung wieder schicken. Vier Zeilen Arbeit,
/// die ein Gerät beantwortet und kein Test.
///
/// ## Eine Härtung, die die Quelle nicht hat
///
/// [NavigationDelegate.onNavigationRequest] lässt **nur** das eigene Asset
/// durch und blockt alles andere. Die Quelle und der eingefrorene Port setzen
/// keinen Delegaten dafür.
///
/// Der Gedanke dahinter: ein WebView ist ein Browser, und dieser hier führt
/// 700 Kilobyte fremdes JavaScript aus. Heute lädt die Seite nichts aus dem
/// Netz, ein Test hält das fest. Wenn das jemand einmal ändert, oder wenn eine
/// der beiden Skriptdateien es täte, wäre der Weg nach draußen offen, ohne
/// dass es auffällt. Die Schranke kostet nichts und schließt die Klasse.
///
/// ## Die Peilung dreht die Figur nicht
///
/// Sie nimmt keine. Die Quelle dreht stattdessen die **Karte** über den
/// Kompass, siehe die Begründung in `avatar_motion.dart`.
library;

import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/map/presentation/avatar/avatar_bridge.dart';
import 'package:fact_app/map/presentation/avatar/avatar_motion.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Der Pfad des Wirts, wie ihn `pubspec.yaml` unter `assets` führt.
const String avatarAssetPath = 'assets/avatar/index.html';

/// Die 3D-Figur, so groß wie ihr Kasten.
class AvatarView extends StatefulWidget {
  /// Erzeugt die Figur.
  const AvatarView({
    this.animation = AvatarAnimation.idle,
    this.gender = AvatarGender.male,
    super.key,
  });

  /// Die Kennung des WebViews, für Tests.
  static const Key webViewKey = Key('avatar-webview');

  /// Was die Figur tut.
  final AvatarAnimation animation;

  /// Welche Fassung der Figur.
  final AvatarGender gender;

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> {
  late final WebViewController _controller;

  /// Ob die Seite geladen ist. Vorher geht kein Aufruf hinaus.
  bool _ready = false;

  /// Was zuletzt wirklich geschickt wurde.
  ///
  /// Zwei Felder und nicht der Vergleich mit `oldWidget`: nach einem
  /// Neuaufsetzen der Seite (`onPageFinished` zum zweiten Mal) hat sich am
  /// Widget nichts geändert, und trotzdem muss alles neu hinaus. Der
  /// Unterschied zwischen „das Widget hat sich geändert" und „die Figur weiß
  /// es schon" ist genau dieser Fall.
  AvatarAnimation? _sentAnimation;
  AvatarGender? _sentGender;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();

    // **Jeder dieser Aufrufe gibt ein Future zurück**, und jeder kann
    // scheitern: sie gehen über einen Plattformkanal. Ein gescheitertes
    // `setJavaScriptMode` ist eine Figur, die nie erscheint, und ohne
    // `reportDetached` erfährt das niemand. Der Analysator meldet es als
    // `discarded_futures`, und das zu Recht.
    //
    // Nicht abgewartet, weil `initState` nichts abwarten darf: die Reihenfolge
    // über denselben Kanal ist ohnehin die der Aufrufe.
    void detached(Future<void> work, String what) =>
        reportDetached(work, origin: 'map.avatar.$what');

    detached(
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted),
      'javascript_mode',
    );
    // Durchsichtig, damit die Karte darunter sichtbar bleibt. Ohne das ist es
    // ein weißer Kasten.
    detached(
      _controller.setBackgroundColor(const Color(0x00000000)),
      'background',
    );
    detached(
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            // Ein zweites `onPageFinished` heißt: die Seite steht neu, und die
            // Figur weiß nichts mehr. Beides vergessen, dann schickt [_sync]
            // wieder alles.
            _sentAnimation = null;
            _sentGender = null;
            _ready = true;
            _sync();
          },
          onNavigationRequest: (NavigationRequest request) {
            // Nur das eigene Asset. Alles andere ist ein Weg nach draußen.
            return request.url.contains(avatarAssetPath)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      ),
      'navigation_delegate',
    );
    detached(_controller.loadFlutterAsset(avatarAssetPath), 'load');
  }

  @override
  void didUpdateWidget(AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Schickt, was sich geändert hat.
  ///
  /// **Ohne `await` und ohne Fehlerbehandlung, und beides mit Grund.**
  /// `runJavaScript` gibt kein Ergebnis des Skripts zurück und meldet keinen
  /// Fehler darin; es gibt hier also nichts zu prüfen. Ein `await` würde die
  /// Reihenfolge zwischen zwei Aufrufen sichern, die ohnehin über denselben
  /// Kanal in derselben Folge gehen.
  void _sync() {
    final List<String> scripts = avatarScriptsToSend(
      isReady: _ready,
      animation: widget.animation,
      gender: widget.gender,
      sentAnimation: _sentAnimation,
      sentGender: _sentGender,
    );
    if (scripts.isEmpty) {
      return;
    }
    for (final String script in scripts) {
      reportDetached(
        _controller.runJavaScript(script),
        origin: 'map.avatar.script',
      );
    }
    _sentAnimation = widget.animation;
    _sentGender = widget.gender;
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    // Zweimal dasselbe gesagt, an beiden Enden: hier, damit Flutter die Geste
    // nicht an den WebView gibt, und `pointer-events: none` in der Seite,
    // damit sie drinnen niemand annimmt. Der WebView ist ein eigener
    // Empfänger, keins der beiden genügt allein.
    child: WebViewWidget(key: AvatarView.webViewKey, controller: _controller),
  );
}
