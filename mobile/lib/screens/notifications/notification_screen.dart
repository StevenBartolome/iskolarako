import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'package:iskoako/utils/app_router.dart';

enum IconVariant { green, amber, sky, red }

class NotificationItem {
  final String id;
  final IconData icon;
  final IconVariant iconVariant;
  final String title;
  final String message;
  final String time;
  bool isUnread;
  final StatusType accentType;
  final String? actionLabel;
  final String? route;
  final bool showVerified;
  final String category; // 'Updates', 'Reminders'

  NotificationItem({
    required this.id,
    required this.icon,
    required this.iconVariant,
    required this.title,
    required this.message,
    required this.time,
    required this.isUnread,
    required this.accentType,
    this.actionLabel,
    this.route,
    this.showVerified = false,
    this.category = 'Updates',
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _selectedTab = 'All';
  bool _isLoading = true;
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final List<NotificationItem> loaded = [];

      if (user != null) {
        // 1. Fetch from notifications table
        try {
          final res = await Supabase.instance.client
              .from('notifications')
              .select('*')
              .eq('user_id', user.id)
              .order('created_at', ascending: false);

          if (res.isNotEmpty) {
            for (final n in res) {
              final type = (n['type'] ?? 'info').toString().toLowerCase();
              final title = (n['title'] ?? 'Notification').toString();
              final message = (n['message'] ?? '').toString();
              final isRead = n['is_read'] == true;
              final createdAtRaw = n['created_at']?.toString();
              final timeStr = _formatTimestamp(createdAtRaw);

              IconVariant iconVar = IconVariant.green;
              IconData icon = LucideIcons.bell;
              StatusType statusType = StatusType.approved;

              if (type == 'success' || title.toLowerCase().contains('exam') || title.toLowerCase().contains('congrat')) {
                iconVar = IconVariant.green;
                icon = title.toLowerCase().contains('exam') ? LucideIcons.fileCheck : LucideIcons.checkCircle2;
                statusType = StatusType.approved;
              } else if (type == 'warning' || title.toLowerCase().contains('flag') || title.toLowerCase().contains('resubmit')) {
                iconVar = IconVariant.amber;
                icon = LucideIcons.alertTriangle;
                statusType = StatusType.pending;
              } else if (type == 'error' || title.toLowerCase().contains('reject')) {
                iconVar = IconVariant.red;
                icon = LucideIcons.xCircle;
                statusType = StatusType.rejected;
              }

              loaded.add(
                NotificationItem(
                  id: n['id'].toString(),
                  icon: icon,
                  iconVariant: iconVar,
                  title: title,
                  message: message,
                  time: timeStr,
                  isUnread: !isRead,
                  accentType: statusType,
                  actionLabel: 'View Tracker →',
                  route: AppRouter.applicationTracker,
                  category: title.toLowerCase().contains('deadline') || title.toLowerCase().contains('resubmit') ? 'Reminders' : 'Updates',
                ),
              );
            }
          }
        } catch (dbErr) {
          debugPrint('[Notifications Table Query Note]: $dbErr');
        }

        // 2. Fetch live scholarship application updates to ensure instant notifications
        try {
          final scholarRes = await Supabase.instance.client
              .from('scholar')
              .select('id')
              .eq('user_id', user.id)
              .maybeSingle();

          if (scholarRes != null && scholarRes['id'] != null) {
            final scholarId = scholarRes['id'].toString();

            final apps = await Supabase.instance.client
                .from('scholarship_applications')
                .select('id, status, remarks, submitted_documents, updated_at, cycle:application_cycles(cycle_name, program:scholarship_programs(title))')
                .eq('scholar_id', scholarId);

            if (apps.isNotEmpty) {
              for (final app in apps) {
                final status = (app['status'] ?? '').toString().toLowerCase();
                final progTitle = app['cycle']?['program']?['title'] ?? 'Scholarship Program';
                final timeStr = _formatTimestamp(app['updated_at']?.toString());
                final remarks = app['remarks']?.toString();

                // Check for flagged documents
                final submittedDocsObj = app['submitted_documents'];
                List<dynamic> docsList = [];
                if (submittedDocsObj is Map && submittedDocsObj['documents'] is List) {
                  docsList = submittedDocsObj['documents'];
                } else if (submittedDocsObj is List) {
                  docsList = submittedDocsObj;
                }

                final hasFlagged = docsList.any((d) =>
                    d is Map &&
                    (d['status']?.toString().toLowerCase() == 'flagged' ||
                     d['verification_status']?.toString().toLowerCase() == 'rejected'));

                if (hasFlagged) {
                  loaded.add(
                    NotificationItem(
                      id: 'flagged_${app['id']}',
                      icon: LucideIcons.alertTriangle,
                      iconVariant: IconVariant.amber,
                      title: 'Action Required: Document Issue Flagged ⚠️',
                      message: 'An issue was noted in your submitted requirement for $progTitle. Tap to view provider instructions and resubmit before the deadline.',
                      time: timeStr,
                      isUnread: true,
                      accentType: StatusType.pending,
                      actionLabel: 'Resubmit File →',
                      route: AppRouter.applicationTracker,
                      category: 'Reminders',
                    ),
                  );
                }

                if (status == 'for_exam') {
                  loaded.add(
                    NotificationItem(
                      id: 'exam_${app['id']}',
                      icon: LucideIcons.fileCheck,
                      iconVariant: IconVariant.green,
                      title: 'Examination Shortlist 🎉',
                      message: 'Congratulations! You passed the initial evaluation for $progTitle. You are now shortlisted for the Examination / Screening stage. Please wait for further announcements regarding the schedule and testing venue.',
                      time: timeStr,
                      isUnread: true,
                      accentType: StatusType.approved,
                      actionLabel: 'View Tracker →',
                      route: AppRouter.applicationTracker,
                      category: 'Updates',
                    ),
                  );
                } else if (status == 'approved') {
                  loaded.add(
                    NotificationItem(
                      id: 'approved_${app['id']}',
                      icon: LucideIcons.checkCircle2,
                      iconVariant: IconVariant.green,
                      title: 'Application Approved! 🎓',
                      message: 'Congratulations! Your scholarship application for $progTitle has been officially approved by the committee. Welcome to the scholarship program!',
                      time: timeStr,
                      isUnread: true,
                      accentType: StatusType.approved,
                      actionLabel: 'View Status →',
                      route: AppRouter.applicationTracker,
                      category: 'Updates',
                    ),
                  );
                } else if (status == 'rejected') {
                  loaded.add(
                    NotificationItem(
                      id: 'rejected_${app['id']}',
                      icon: LucideIcons.xCircle,
                      iconVariant: IconVariant.red,
                      title: 'Application Status Update',
                      message: 'Your application for $progTitle was evaluated. ${remarks != null ? "Note: $remarks" : "Slot capacity reached for this cycle."}',
                      time: timeStr,
                      isUnread: false,
                      accentType: StatusType.rejected,
                      category: 'Updates',
                    ),
                  );
                }
              }
            }
          }
        } catch (appErr) {
          debugPrint('[Apps Query Note]: $appErr');
        }
      }

      // Add standard welcome/system default cards if loaded is empty
      if (loaded.isEmpty) {
        loaded.addAll([
          NotificationItem(
            id: 'mock-1',
            icon: LucideIcons.sparkles,
            iconVariant: IconVariant.green,
            title: 'Welcome to IskoAko! 🎉',
            message: 'Your student account is active. Explore open scholarships and track your application milestones directly here.',
            time: 'Recently',
            isUnread: true,
            accentType: StatusType.approved,
            actionLabel: 'Explore Scholarships →',
            category: 'Updates',
          ),
          NotificationItem(
            id: 'mock-2',
            icon: LucideIcons.clock,
            iconVariant: IconVariant.amber,
            title: 'Prepare Requirements',
            message: 'Make sure your Transcript of Records (TOR) and Certificate of Registration (COR) are up to date for fast verification.',
            time: '1 day ago',
            isUnread: false,
            accentType: StatusType.pending,
            category: 'Reminders',
          ),
        ]);
      }

      // Deduplicate by ID
      final uniqueMap = <String, NotificationItem>{};
      for (final item in loaded) {
        uniqueMap[item.id] = item;
      }

      if (mounted) {
        setState(() {
          _notifications = uniqueMap.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Fetch Notifications Error]: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(String? iso) {
    if (iso == null) return 'Recently';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  void _markAllAsRead() async {
    setState(() {
      for (var n in _notifications) {
        n.isUnread = false;
      }
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', user.id);
      } catch (e) {
        debugPrint('[Mark Read Error]: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All notifications marked as read',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n.isUnread).length;

    List<NotificationItem> filtered = _notifications;
    if (_selectedTab == 'Updates') {
      filtered = _notifications.where((n) => n.category == 'Updates').toList();
    } else if (_selectedTab == 'Reminders') {
      filtered = _notifications.where((n) => n.category == 'Reminders').toList();
    }

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context, unreadCount: unreadCount),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchNotifications,
              color: AppColors.primary,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final item = filtered[idx];
                            return _NotifCard(
                              icon: item.icon,
                              iconVariant: item.iconVariant,
                              title: item.title,
                              message: item.message,
                              time: item.time,
                              isUnread: item.isUnread,
                              accentType: item.accentType,
                              actionLabel: item.actionLabel,
                              showVerified: item.showVerified,
                              onTap: () {
                                setState(() => item.isUnread = false);
                                if (item.route != null) {
                                  Navigator.pushNamed(context, item.route!);
                                }
                              },
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.bellOff, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'No notifications in this category',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are all caught up with your latest scholarship announcements.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required int unreadCount}) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (Navigator.canPop(context)) ...[
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          LucideIcons.chevronLeft,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Icon(
                      Icons.diamond_rounded,
                      size: 14,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'NOTIFICATION ALERTS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.amberDeep,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _markAllAsRead,
                  child: Text(
                    'Mark all read',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Alerts &\nnotifications.',
              style: GoogleFonts.playfairDisplay(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 14),
            // Tab row
            Row(
              children: [
                _TabItem(
                  label: 'All',
                  badge: unreadCount > 0 ? '$unreadCount' : null,
                  isActive: _selectedTab == 'All',
                  onTap: () => setState(() => _selectedTab = 'All'),
                ),
                const SizedBox(width: 20),
                _TabItem(
                  label: 'Updates',
                  isActive: _selectedTab == 'Updates',
                  onTap: () => setState(() => _selectedTab = 'Updates'),
                ),
                const SizedBox(width: 20),
                _TabItem(
                  label: 'Reminders',
                  isActive: _selectedTab == 'Reminders',
                  onTap: () => setState(() => _selectedTab = 'Reminders'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Notification card ───────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final IconData icon;
  final IconVariant iconVariant;
  final String title;
  final String message;
  final String time;
  final bool isUnread;
  final StatusType accentType;
  final String? actionLabel;
  final bool showVerified;
  final VoidCallback? onTap;

  const _NotifCard({
    required this.icon,
    required this.iconVariant,
    required this.title,
    required this.message,
    required this.time,
    required this.isUnread,
    required this.accentType,
    this.actionLabel,
    this.showVerified = false,
    this.onTap,
  });

  Color get _accentColor {
    switch (accentType) {
      case StatusType.approved:
        return AppColors.primary;
      case StatusType.pending:
        return AppColors.amber;
      case StatusType.released:
        return AppColors.released;
      case StatusType.rejected:
        return AppColors.error;
      case StatusType.info:
        return AppColors.textSecondary;
    }
  }

  Color get _iconBg {
    switch (iconVariant) {
      case IconVariant.green:
        return AppColors.successBg;
      case IconVariant.amber:
        return AppColors.pendingBg;
      case IconVariant.sky:
        return AppColors.releasedBg;
      case IconVariant.red:
        return AppColors.errorBg;
    }
  }

  Color get _iconColor {
    switch (iconVariant) {
      case IconVariant.green:
        return AppColors.primary;
      case IconVariant.amber:
        return AppColors.amber;
      case IconVariant.sky:
        return AppColors.released;
      case IconVariant.red:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: AppColors.rule, width: 0.5),
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: _accentColor.withAlpha(18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isUnread
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          if (actionLabel != null || showVerified) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (actionLabel != null)
                  StatusChip(label: actionLabel!, type: accentType),
                if (showVerified) const VerifiedBadge(),
              ],
            ),
          ],
        ],
      ),
    );

    if (isUnread) {
      card = Stack(
        children: [
          card,
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Container(width: 4, color: _accentColor),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}

// ─── Tab item ────────────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  final String label;
  final String? badge;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    this.badge,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? AppColors.primaryDark
                      : AppColors.textMuted,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 32 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
