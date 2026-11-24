import 'package:flutter/material.dart';

class AppToast {
  static OverlayEntry? _currentEntry;

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom + kBottomNavigationBarHeight + 12;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          left: 16,
          right: 16,
          bottom: bottomInset,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 16),
                    child: child,
                  ),
                );
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF3C1518).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFFF8A80), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          entry.remove();
                          if (_currentEntry == entry) _currentEntry = null;
                        },
                        child: const Icon(Icons.close, color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);

    Future<void>.delayed(duration, () {
      if (entry.mounted) {
        entry.remove();
        if (_currentEntry == entry) _currentEntry = null;
      }
    });
  }
}