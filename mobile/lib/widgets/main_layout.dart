import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/scholarships/scholarship_list_screen.dart';
import '../screens/applications/application_tracker_screen.dart';
import '../screens/funds/fund_tracking_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../constants/app_colors.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const ScholarshipListScreen(),
    const ApplicationTrackerScreen(),
    const FundTrackingScreen(),
    const ProfileScreen(),
  ];

  static const List<_NavItem> _navItems = [
    _NavItem(icon: LucideIcons.home, label: 'Home'),
    _NavItem(icon: LucideIcons.graduationCap, label: 'Browse'),
    _NavItem(icon: LucideIcons.clipboardList, label: 'My Apps'),
    _NavItem(icon: LucideIcons.wallet, label: 'Funds'),
    _NavItem(icon: LucideIcons.user, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    final double start = _currentIndex.toDouble();
    final double end = index.toDouble();

    setState(() {
      _currentIndex = index;
    });

    _animation = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    // Total margin around the floating navigation bar
    const double horizontalMargin = 20.0;
    const double bottomMargin = 24.0;
    const double navBarHeight = 68.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          horizontalMargin,
          0,
          horizontalMargin,
          bottomMargin,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double totalWidth = constraints.maxWidth;
            final double itemWidth = totalWidth / _navItems.length;

            return AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final double currentX = (_animation.value + 0.5) * itemWidth;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Custom Painted Background with Bezier Cutout Curve
                    CustomPaint(
                      size: Size(totalWidth, navBarHeight),
                      painter: _NavBarPainter(
                        activeIndex: _animation.value,
                        color: AppColors.surface,
                      ),
                    ),

                    // 2. Floating Circular Bubble containing the selected icon
                    Positioned(
                      left: currentX - 28.0, // 28 is half of bubble width (56)
                      top:
                          -35.0, // Increased floating height above the top edge to create more gap
                      child: Container(
                        width: 56.0,
                        height: 56.0,
                        decoration: BoxDecoration(
                          color: AppColors.primary, // System green theme color
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(80), // Tinted shadow for green bubble
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _navItems[_currentIndex].icon,
                            color: Colors.white, // White icon color
                            size: 26.0,
                          ),
                        ),
                      ),
                    ),

                    // 3. Tab Items Row
                    SizedBox(
                      height: navBarHeight,
                      child: Row(
                        children: List.generate(_navItems.length, (i) {
                          final item = _navItems[i];
                          final isSelected = _currentIndex == i;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _onTabTapped(i),
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Icon: Visible only when not selected
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 150),
                                    opacity: isSelected ? 0.0 : 1.0,
                                    child: AnimatedScale(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      scale: isSelected ? 0.5 : 1.0,
                                      child: isSelected
                                          ? const SizedBox(height: 24)
                                          : Icon(
                                              item.icon,
                                              size: 22.0,
                                              color: AppColors.textMuted,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Label Text
                                  Text(
                                    item.label,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.0,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NavBarPainter extends CustomPainter {
  final double activeIndex;
  final Color color;

  _NavBarPainter({required this.activeIndex, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Soft, realistic shadow for the floating layout
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final path = Path();
    final double w = size.width;
    final double h = size.height;
    final double r = 24.0; // Rounded corners of the floating bar

    final double itemWidth = w / 5;
    final double cx = (activeIndex + 0.5) * itemWidth;

    // Draw outline
    path.moveTo(0, r);

    // Top Left Corner
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true);

    // Curve Cutout around activeIndex
    final double cutoutHalfWidth = 46.0;
    final double cutoutStart = cx - cutoutHalfWidth;
    final double cutoutEnd = cx + cutoutHalfWidth;

    path.lineTo(cutoutStart, 0);

    // Smooth Bezier Curve mapping perfectly to the circular bubble shape
    path.cubicTo(cx - 24, 0, cx - 22, 28, cx, 28);
    path.cubicTo(cx + 22, 28, cx + 24, 0, cutoutEnd, 0);

    path.lineTo(w - r, 0);

    // Top Right Corner
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: true);

    // Bottom Right Corner
    path.lineTo(w, h - r);
    path.arcToPoint(
      Offset(w - r, h),
      radius: Radius.circular(r),
      clockwise: true,
    );

    // Bottom Left Corner
    path.lineTo(r, h);
    path.arcToPoint(
      Offset(0, h - r),
      radius: Radius.circular(r),
      clockwise: true,
    );

    path.close();

    // Intersect the drawn path with the perfect rounded rectangle boundary of the nav bar
    // to cleanly remove any pixels spilling outside the rounded corners on leftmost (Home) and rightmost (Profile) tabs.
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(r),
    );
    final borderPath = Path()..addRRect(rrect);
    final finalPath = Path.combine(PathOperation.intersect, path, borderPath);

    // Draw shadow path slightly offset down
    canvas.drawPath(finalPath.shift(const Offset(0, 4)), shadowPaint);

    // Draw background shape
    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant _NavBarPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex || oldDelegate.color != color;
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
