import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholders for indeterminate loading (replaces spinner UX).
abstract final class LoadingSkeleton {
  const LoadingSkeleton._();

  static Color _boneFill(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  static Shimmer shimmer(BuildContext context, {required Widget child}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2C2C2E) : const Color(0xFFE4E4E8);
    final hi = dark ? const Color(0xFF3D3D40) : const Color(0xFFF4F4F6);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      period: const Duration(milliseconds: 1250),
      child: child,
    );
  }

  static Widget inlineSquare(BuildContext context, {double size = 18}) {
    final fill = _boneFill(context);
    return SizedBox(
      width: size,
      height: size,
      child: shimmer(
        context,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  static Widget bannerLeading(BuildContext context) {
    final fill = _boneFill(context);
    return SizedBox(
      width: 14,
      height: 14,
      child: shimmer(
        context,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  static Widget startupBody(BuildContext context) {
    final fill = _boneFill(context);
    return shimmer(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 220,
            height: 8,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 180,
            height: 8,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 140,
            height: 8,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  static Widget hardwareList(BuildContext context) {
    final fill = _boneFill(context);
    Widget card() {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 10,
                width: double.infinity,
                margin: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 10,
                width: double.infinity,
                margin: const EdgeInsets.only(right: 64),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 10,
                width: double.infinity,
                margin: const EdgeInsets.only(right: 100),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return shimmer(
      context,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          card(),
          const SizedBox(height: 12),
          card(),
          const SizedBox(height: 12),
          card(),
        ],
      ),
    );
  }

  /// Placeholder inside chart cards while fewer than 2 samples exist.
  static Widget chartArea(BuildContext context, {double height = 200}) {
    final fill = _boneFill(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: shimmer(
        context,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                          8,
                          (i) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Container(
                                height: 24.0 + (i % 4) * 18,
                                decoration: BoxDecoration(
                                  color: fill.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 10,
                width: 120,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Logbook / narrow panels: icon-sized block + lines.
  static Widget logbookEmpty(BuildContext context) {
    final fill = _boneFill(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: shimmer(
          context,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 14,
                width: 160,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 10,
                width: 220,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 10,
                width: 200,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Narrow panels (e.g. prediction while trend data is warming up).
  static Widget compactPlaceholder(BuildContext context) {
    final fill = _boneFill(context);
    return SizedBox(
      height: 88,
      width: double.infinity,
      child: shimmer(
        context,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 12,
              width: 200,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 10,
              width: 160,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              width: 120,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Storage "Free up space" / "Largest files" mid-panel busy state.
  static Widget storagePanelBusy(BuildContext context) {
    final fill = _boneFill(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: shimmer(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 14,
                width: 180,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < 5; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 12,
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Settings → storage: block under title while fetching layout.
  static Widget storageSettingsBody(BuildContext context) {
    final fill = _boneFill(context);
    return shimmer(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 12,
            width: double.infinity,
            margin: const EdgeInsets.only(right: 40),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 12,
            width: double.infinity,
            margin: const EdgeInsets.only(right: 80),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 36,
            width: double.infinity,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}
