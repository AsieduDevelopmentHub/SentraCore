import 'package:flutter/material.dart';

/// A utility widget that displays a horizontal Row on wide screens,
/// and a vertical Column on narrow screens.
class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final double breakpoint;
  final double spacing;
  final bool useIntrinsicHeight;

  const ResponsiveRowColumn({
    required this.children,
    this.breakpoint = 900,
    this.spacing = 16,
    this.useIntrinsicHeight = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= breakpoint;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        } else {
          // Narrow: Stack vertically.
          // We need to strip out any `Expanded` or `Flexible` widgets since
          // they don't make sense inside a scrolling Column (unless bounded).
          final columnChildren = children.map((c) => _unwrapFlex(c)).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: columnChildren.asMap().entries.map((e) {
              final isLast = e.key == columnChildren.length - 1;
              // Don't add spacing after the last element or after a SizedBox that acts as spacing
              if (e.value is SizedBox &&
                  (e.value as SizedBox).width != null &&
                  (e.value as SizedBox).child == null) {
                return const SizedBox.shrink(); // Ignore horizontal spacers
              }
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
                child: e.value,
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _unwrapFlex(Widget widget) {
    if (widget is Expanded) return widget.child;
    if (widget is Flexible) return widget.child;
    return widget;
  }
}
