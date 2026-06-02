import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/carousel_item_model.dart';

class CustomCarousel extends StatefulWidget {
  final List<CarouselItem> items;
  final Duration autoScrollDuration;

  const CustomCarousel({
    super.key,
    required this.items,
    this.autoScrollDuration = const Duration(seconds: 4),
  });

  @override
  State<CustomCarousel> createState() => _CustomCarouselState();
}

class _CustomCarouselState extends State<CustomCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    _pageController = PageController(initialPage: 0);
    _startTimer();
    super.initState();
  }

  void _startTimer() {
    _timer = Timer.periodic(widget.autoScrollDuration, (timer) {
      if (!mounted || widget.items.isEmpty) return;
      final nextIndex = (_currentIndex + 1) % widget.items.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth * 0.55; // Maintain aspect ratio
        return Stack(
          children: [
            // Carousel Slider
            SizedBox(
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image
                        Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Color(0xFF2E7D32)),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 40,
                                color: Color(0xFF2E7D32),
                              ),
                            );
                          },
                        ),
                        // Soft dark gradient overlay for text legibility
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.1),
                                  Colors.black.withOpacity(0.7),
                                ],
                                stops: const [0.5, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Title
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black45,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            // Pagination Indicators (Dots)
            Positioned(
              right: 16,
              bottom: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  widget.items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == index ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
