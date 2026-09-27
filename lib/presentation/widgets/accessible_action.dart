import 'package:flutter/material.dart';

/// Keeps custom painted controls keyboard-operable and exposes their state.
class AccessibleAction extends StatefulWidget {
  const AccessibleAction({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final bool? selected;

  @override
  State<AccessibleAction> createState() => _AccessibleActionState();
}

class _AccessibleActionState extends State<AccessibleAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onTap != null,
    selected: widget.selected,
    label: widget.label,
    onTap: widget.label != null ? widget.onTap : null,
    excludeSemantics: widget.label != null,
    child: InkWell(
      onTap: widget.onTap,
      onFocusChange: (focused) => setState(() => _focused = focused),
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: _focused
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: widget.label == null
              ? widget.child
              : Tooltip(
                  message: widget.label!,
                  excludeFromSemantics: true,
                  child: widget.child,
                ),
        ),
      ),
    ),
  );
}
