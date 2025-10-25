import 'package:flutter/material.dart';

class NoRestoreScrollWrapper extends StatelessWidget {
  final Widget child;

  const NoRestoreScrollWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: NoRestoreScrollBehavior(),
      child: child,
    );
  }
}

class NoRestoreScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());
  }
}