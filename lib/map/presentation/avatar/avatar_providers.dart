/// Die Naht, über die der Nutzermarker seine Figur bekommt.
///
/// ## Warum es diese Naht gibt, und sie ist keine Bequemlichkeit
///
/// **Ein `WebViewController` entsteht in keinem Widget-Test.** Er braucht die
/// Plattform-Umsetzung von `webview_flutter`, und die gibt es im Test nicht;
/// der Aufruf wirft. Stünde `AvatarView` fest im Baum des Kartenbildschirms,
/// wäre damit **jeder** Test dieses Bildschirms rot, und das sind nicht wenige.
///
/// Derselbe Grund und dieselbe Bauform wie bei `MapProjectionDriver` und
/// `MapCameraDriver`: was ohne Gerät nicht entstehen kann, kommt über einen
/// Provider herein, und der Test setzt etwas anderes ein.
///
/// **Und es ist mehr als eine Testhilfe.** Der Nutzermarker ist damit ohne
/// WebView prüfbar: seine Lage, sein Verschwinden ohne Ortung, sein Pulsring
/// und die Animation, die er weitergibt. Das ist alles, was er entscheidet.
library;

import 'package:fact_app/map/presentation/avatar/avatar_motion.dart';
import 'package:fact_app/map/presentation/avatar/avatar_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Baut die Figur für [animation].
typedef AvatarFigureBuilder = Widget Function(AvatarAnimation animation);

/// Wer die Figur baut.
///
/// In der App [AvatarView], im Test etwas, das sich zeichnen lässt.
final Provider<AvatarFigureBuilder> avatarFigureBuilderProvider =
    Provider<AvatarFigureBuilder>(
      (ref) =>
          (AvatarAnimation animation) => AvatarView(animation: animation),
    );
