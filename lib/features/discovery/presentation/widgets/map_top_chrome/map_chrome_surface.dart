part of 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';

/// Eine Pille mit Weichzeichner, Rahmen und optionalem Schatten.
///
/// Der Weichzeichner braucht einen Clip, sonst greift er über die Pille
/// hinaus; der Schatten muss außerhalb dieses Clips liegen, sonst schneidet
/// ihn derselbe Clip weg. Dieselbe Reihenfolge wie in
/// `app/shell/floating_tab_bar.dart`.
class _Blurred extends StatelessWidget {
  const _Blurred({
    required this.radius,
    required this.sigma,
    required this.background,
    required this.border,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.shadow,
    this.size,
  });

  final double radius;
  final double sigma;
  final Color background;
  final Color border;
  final EdgeInsets padding;
  final BoxShadow? shadow;
  final Size? size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.all(Radius.circular(radius));
    Widget content = Container(
      width: size?.width,
      height: size?.height,
      alignment: size == null ? null : Alignment.center,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius,
        border: Border.all(color: border),
      ),
      child: child,
    );
    content = ClipRRect(
      borderRadius: borderRadius,
      // Der Parameter von CSS `blur()` ist laut Filter Effects Level 1 die
      // Standardabweichung der Gaußfunktion, also derselbe Wert, den
      // `ImageFilter.blur` als Sigma erwartet. Keine Umrechnung nötig.
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: content,
      ),
    );
    if (shadow == null) {
      return content;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[shadow!],
      ),
      child: content,
    );
  }
}

/// `borderRadius: 999`, also so rund wie möglich.
const double _fullRadius = 999;

/// `backdropFilter: 'blur(14px)'`, `screen-map.jsx:3029`, `:3106`, `:3209`.
const double _blurStrong = 14;

/// `backdropFilter: 'blur(10px)'` der Coin-Pille, `screen-map.jsx:711`.
const double _blurLight = 10;

/// `boxShadow: '0 1px 6px rgba(0,0,0,0.12)'`, `screen-map.jsx:714` und `:3111`.
const BoxShadow _softShadow = BoxShadow(
  color: Color(0x1F000000),
  offset: Offset(0, 1),
  blurRadius: 6,
);
