import 'package:flutter/material.dart';
import '../theme/ladolce_pos_ui.dart';
import '../utils/responsive_layout.dart';

/// Centralized animated skeleton loaders for LaDolce app
class SkeletonLoader extends StatefulWidget {
  final Widget child;
  const SkeletonLoader({super.key, required this.child});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}

/// Cashier POS Products Loading Skeleton
class PosProductSkeleton extends StatelessWidget {
  final bool isGridView;
  const PosProductSkeleton({super.key, required this.isGridView});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: isGridView ? _buildGrid(context) : _buildList(),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final maxExtent = ResponsiveLayout.productGridMaxCrossAxisExtent(context);
    final aspect = ResponsiveLayout.productGridChildAspectRatio(context);

    return Container(
      color: LaDolcePosUi.surface,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          childAspectRatio: aspect,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: LaDolcePosUi.card,
              borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
              border: Border.all(color: LaDolcePosUi.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardHeight = constraints.maxHeight;
                final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                final isCompactText = textScale > 1.1;
                final imageHeight =
                    (cardHeight * (isCompactText ? 0.50 : 0.54)).clamp(84.0, 132.0);
                final padding = cardHeight < 220 ? 10.0 : 12.0;
                final gap = cardHeight < 220 ? 6.0 : 8.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: imageHeight,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(LaDolcePosUi.radius),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 14,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            SizedBox(height: gap),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    flex: 0,
                                    child: Container(
                                      height: 12,
                                      width: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildList() {
    return Container(
      color: LaDolcePosUi.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LaDolcePosUi.card,
              borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
              border: Border.all(color: LaDolcePosUi.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 14,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Customer Self Order Home/Catalog Loading Skeleton
class CustomerSelfOrderSkeleton extends StatelessWidget {
  final bool isWide;
  final bool isMobile;
  final bool isSmall;
  const CustomerSelfOrderSkeleton({
    super.key,
    required this.isWide,
    required this.isMobile,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return SkeletonLoader(
        child: Row(
          children: [
            // Left Cart Preview Column
            Expanded(
              flex: 28,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 20, width: 120, color: Colors.grey[200]),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: 3,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(height: 36, width: 36, color: Colors.grey[200]),
                                const SizedBox(width: 12),
                                Expanded(child: Container(height: 12, color: Colors.grey[200])),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Right Catalog Column
            Expanded(
              flex: 72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  _buildCategoryChips(),
                  Expanded(child: _buildGrid()),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SkeletonLoader(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          _buildCategoryChips(),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            width: index == 0 ? 80 : 64,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    final hPad = isSmall ? 8.0 : 12.0;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 3 : (isMobile ? 1 : 2),
        mainAxisExtent: isWide ? 132 : (isMobile ? 110 : 126),
        crossAxisSpacing: isSmall ? 8 : 10,
        mainAxisSpacing: isSmall ? 8 : 10,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: isWide ? 104 : 90,
                  height: isWide ? 104 : 90,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            height: 14,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
