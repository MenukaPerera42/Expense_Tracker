import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Retains scaled axis labels without squeezing neighboring labels together.
class ResponsiveChart extends StatelessWidget {
  const ResponsiveChart({
    super.key,
    required this.height,
    required this.minWidth,
    required this.child,
  });
  final double height;
  final double minWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(constraints.maxWidth, minWidth),
        height: height,
        child: child,
      ),
    ),
  );
}
