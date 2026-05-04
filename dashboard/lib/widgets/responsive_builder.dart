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
          // Wide: Row with consistent horizontal spacing between children.
          // Keep existing spacers if caller provided them explicitly.
          final rowChildren = <Widget>[];
          for (var i = 0; i < children.length; i++) {
            final child = children[i];
            rowChildren.add(child);
            final isLast = i == children.length - 1;
            if (!isLast) {
              // Don't add spacing after explicit spacing widgets.
              if (child is SizedBox &&
                  child.width != null &&
                  child.child == null) {
                continue;
              }
              rowChildren.add(SizedBox(width: spacing));
            }
          }

          // Note: don't wrap LayoutBuilder output with IntrinsicHeight; Flutter
          // disallows intrinsic sizing for LayoutBuilder.
          //
          // Also: don't use CrossAxisAlignment.stretch when height is unbounded
          // (e.g. inside a scroll view), or Flutter will throw "infinite height".
          final crossAxisAlignment = constraints.hasBoundedHeight
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start;
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: rowChildren,
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
