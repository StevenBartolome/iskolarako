import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/scholarships/scholarship_list_screen.dart';
import '../screens/applications/application_tracker_screen.dart';
import '../screens/funds/fund_tracking_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../constants/app_colors.dart';
import '../services/push_notification_service.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Animation<double> _bubbleScaleAnimation;
  late Animation<double> _bubbleHopAnimation;
  bool _isNavbarShrunk = false;

  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();

  late final List<Widget> _pages = [
    DashboardScreen(
      key: _dashboardKey,
      onSelectTab: _onTabTapped,
    ),
    ScholarshipListScreen(
      onSelectTab: _onTabTapped,
    ),
    ApplicationTrackerScreen(
      onSelectTab: _onTabTapped,
    ),
    FundTrackingScreen(
      onSelectTab: _onTabTapped,
    ),
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PushNotificationService.initializeAndRegister(context);
      }
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    // Bouncy spring curve for horizontal cutout and bubble glide
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Cubic(0.34, 1.45, 0.64, 1.0),
      ),
    );

    // Juicy squash-and-stretch bounce effect
    _bubbleScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.86)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.86, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
    ]).animate(_animationController);

    // Playful vertical hop bounce during transit
    _bubbleHopAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -6.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -6.0, end: 0.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      if (index == 0) {
        _dashboardKey.currentState?.refreshDashboard();
      }
      return;
    }

    final double start = _currentIndex.toDouble();
    final double end = index.toDouble();

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
      _isNavbarShrunk = false;
    });

    if (index == 0) {
      _dashboardKey.currentState?.refreshDashboard();
    }

    _animation = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Cubic(0.34, 1.45, 0.64, 1.0),
      ),
    );
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isForward = _currentIndex >= _previousIndex;

    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is UserScrollNotification) {
            if (scrollNotification.direction == ScrollDirection.reverse) {
              if (!_isNavbarShrunk) {
                setState(() {
                  _isNavbarShrunk = true;
                });
              }
            } else if (scrollNotification.direction == ScrollDirection.forward) {
              if (_isNavbarShrunk) {
                setState(() {
                  _isNavbarShrunk = false;
                });
              }
            }
          }
          return false;
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset(isForward ? 0.035 : -0.035, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                ),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: _pages[_currentIndex],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    // Total margin around the floating navigation bar
    const double horizontalMargin = 20.0;
    const double bottomMargin = 24.0;
    const double navBarHeight = 68.0;

    return AnimatedScale(
      scale: _isNavbarShrunk ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _isNavbarShrunk ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: SafeArea(
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
                  animation: _animationController,
                  builder: (context, child) {
                    final double currentX = (_animation.value + 0.5) * itemWidth;
                    final double currentScale = _bubbleScaleAnimation.value;
                    final double currentHop = _bubbleHopAnimation.value;

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

                        // 2. Floating Circular Bubble containing the selected icon with Hop & Bounce
                        Positioned(
                          left: currentX - 24.0, // 24 is half of bubble width (48)
                          top: -24.0 + currentHop, // Animated hop bounce
                          child: Transform.scale(
                            scale: currentScale, // Animated squash and stretch bounce
                            child: Container(
                              width: 48.0,
                              height: 48.0,
                              decoration: BoxDecoration(
                                color: AppColors.primary, // System green theme color
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                    offset: Offset(0, 4 - (currentHop * 0.5)),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(
                                      scale: CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutBack,
                                      ),
                                      child: RotationTransition(
                                        turns: Tween<double>(begin: -0.06, end: 0.0).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutBack,
                                          ),
                                        ),
                                        child: FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    _navItems[_currentIndex].icon,
                                    key: ValueKey<int>(_currentIndex),
                                    color: Colors.white,
                                    size: 22.0,
                                  ),
                                ),
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
                                        duration: const Duration(milliseconds: 200),
                                        opacity: isSelected ? 0.0 : 1.0,
                                        child: AnimatedScale(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          curve: Curves.easeOutBack,
                                          scale: isSelected ? 0.4 : 1.0,
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
                                      // Label Text with micro scale and color transition
                                      AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 220),
                                        curve: Curves.easeOutCubic,
                                        style: GoogleFonts.inter(
                                          fontSize: isSelected ? 10.5 : 10.0,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                        ),
                                        child: Text(item.label),
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

    final double w = size.width;
    final double h = size.height;
    final double r = 24.0; // Rounded corners of the floating bar

    final double itemWidth = w / 5;
    final double cx = (activeIndex + 0.5) * itemWidth;

    final path = Path();
    
    // Draw outline with smooth fillet cutout
    path.moveTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true);

    // Flat line to start of cutout fillet
    path.lineTo(cx - 42.0, 0);

    // Fillet curve down: starts flat at y=0, curves down to y=12.0
    path.cubicTo(
      cx - 34.0, 0,
      cx - 32.0, 6.0,
      cx - 28.0, 12.0,
    );

    // Main dip curve: curves down to y=30.0 at center cx (6.0px gap under bubble)
    path.cubicTo(
      cx - 20.0, 24.0,
      cx - 14.0, 30.0,
      cx, 30.0,
    );

    // Main dip curve back up: curves up to y=12.0
    path.cubicTo(
      cx + 14.0, 30.0,
      cx + 20.0, 24.0,
      cx + 28.0, 12.0,
    );

    // Fillet curve up: starts at y=12.0, curves flat to y=0 at cx+42.0
    path.cubicTo(
      cx + 32.0, 6.0,
      cx + 34.0, 0,
      cx + 42.0, 0,
    );

    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: true);

    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r), clockwise: true);

    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r), clockwise: true);
    
    path.close();

    // Intersect the drawn path with the perfect rounded rectangle boundary of the nav bar.
    // This cleanly handles overlap at leftmost (Home) and rightmost (Profile) tabs,
    // ensuring the outer rounded corners are never cut off.
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
