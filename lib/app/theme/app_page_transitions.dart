import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// iOS Web already animates history gestures. A second Cupertino slide makes
/// the previous page appear twice (flutter/flutter#114324).
PageTransitionsTheme appPageTransitions({bool isWeb = kIsWeb}) {
  const defaults = PageTransitionsTheme();
  if (!isWeb) return defaults;
  return PageTransitionsTheme(builders: {
    ...defaults.builders,
    TargetPlatform.iOS: const _InstantWebPageTransitionsBuilder(),
  });
}

class _InstantWebPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantWebPageTransitionsBuilder();

  // Returning child alone hides the slide but still keeps the outgoing route
  // alive for the default animation duration, overlapping iOS history snapshots.
  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
