import 'package:flutter/material.dart';

/// Reflows dense rows when the available width or text scale needs more room.
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({super.key, required this.children, this.breakpoint = 280});
  final List<Widget> children;
  final double breakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < breakpoint ||
          MediaQuery.textScalerOf(context).scale(14) > 19;
      if (!stacked) return Row(children: children);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children)
            if (child is Flexible)
              child.child
            else if (child is Spacer)
              const SizedBox(height: 8)
            else if (child is SizedBox && child.width != null)
              SizedBox(height: child.width)
            else
              child,
        ],
      );
    },
  );
}
