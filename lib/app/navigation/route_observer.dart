/// Globaler [RouteObserver] für RouteAware-Seiten (z. B. Refresh beim Zurückkehren).
import 'package:flutter/widgets.dart';

/// Singleton-Observer, den [MaterialApp.navigatorObservers] einbindet.
final RouteObserver<ModalRoute<dynamic>> routeObserver =
    RouteObserver<ModalRoute<dynamic>>();
