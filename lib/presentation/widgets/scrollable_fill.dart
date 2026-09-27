import 'package:flutter/material.dart';

/// Wraps non-scrollable content (a loading spinner, an error [StatusView])
/// in a minimally-scrollable list that still fills the viewport height.
///
/// [RefreshIndicator] requires a scrollable descendant to detect the pull
/// gesture, so screens that want pull-to-refresh available in every state —
/// not just once data has loaded — wrap their loading/error content in this
/// rather than a bare [Center].
class ScrollableFill extends StatelessWidget {
  const ScrollableFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ],
      ),
    );
  }
}
