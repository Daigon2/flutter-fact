/// Die einzige Stelle im Projekt, an der Route-Pfade als Strings stehen
/// (ADR-004: keine rohen Route-Strings außerhalb der Routing-Infrastruktur).
///
/// `routeName` statt `name`, weil `name` den eingebauten `Enum.name`-Getter
/// verdecken würde.
enum AppRoute {
  splash('/', 'splash');

  const AppRoute(this.path, this.routeName);

  final String path;
  final String routeName;
}
