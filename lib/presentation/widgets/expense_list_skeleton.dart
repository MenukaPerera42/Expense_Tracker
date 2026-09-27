import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';

/// A static (non-animated, deliberately — see the module's guidance to avoid
/// excessive animation) placeholder shaped like a handful of
/// [ExpenseListItem] cards, shown instead of a bare spinner while the
/// expense stream's first snapshot is still loading. Purely presentational —
/// no data, no providers.
class ExpenseListSkeleton extends StatelessWidget {
  const ExpenseListSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.extraLarge * 2,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.small),
        child: _SkeletonRow(),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final blockColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: blockColor, radius: 20),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bar(width: 140, color: blockColor),
                  const SizedBox(height: AppSpacing.small),
                  _Bar(width: 90, color: blockColor),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            _Bar(width: 48, color: blockColor),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        height: 12,
        child: ColoredBox(color: color),
      ),
    );
  }
}
