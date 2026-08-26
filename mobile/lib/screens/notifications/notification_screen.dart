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
  final String category; // 'Announcements', 'Updates', 'Reminders'
  final String? senderBadge;
  final String? senderType;
  final String? senderName;
  final String? programTitle;
  final String? location;
  final double? lat;
  final double? lng;
  final String? announcementType;
  final Map<String, dynamic>? metadata;

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
    this.senderBadge,
    this.senderType,
    this.senderName,
    this.programTitle,
    this.location,
    this.lat,
    this.lng,
    this.announcementType,
    this.metadata,
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static final Set<String> _readItemIds = {};
  String _selectedTab = 'All';
  bool _isLoading = true;
  List<NotificationItem> _notifications = [];
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('notifications-screen-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            if (mounted) _fetchNotifications();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scholarship_applications',
          callback: (payload) {
            if (mounted) _fetchNotifications();
          },
        );
    _realtimeChannel?.subscribe();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final List<NotificationItem> loaded = [];

      if (user != null) {
        // 1. Fetch from notifications table (Admin broadcasts, Provider announcements, Agreements, Statuses)
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
              final meta = n['metadata'] is Map ? (n['metadata'] as Map<String, dynamic>) : <String, dynamic>{};

              final senderType = (meta['sender_type'] ?? '').toString().toLowerCase();
              final senderName = meta['sender_name']?.toString() ?? meta['provider_name']?.toString();
              final annType = meta['announcement_type']?.toString();
              final location = meta['location']?.toString();
              final progTitle = meta['program_title']?.toString();

              double? lat;
              double? lng;
              if (meta['coordinates'] is Map) {
                final c = meta['coordinates'] as Map;
                if (c['lat'] != null) lat = double.tryParse(c['lat'].toString());
                if (c['lng'] != null) lng = double.tryParse(c['lng'].toString());
              }

              IconVariant iconVar = IconVariant.green;
              IconData icon = LucideIcons.bell;
              StatusType statusType = StatusType.approved;
              String category = 'Updates';
              String? senderBadge;

              if (senderType == 'admin' || type == 'announcement') {
                senderBadge = '🏛️ System Admin';
                category = 'Announcements';
                icon = LucideIcons.megaphone;
                iconVar = IconVariant.amber;
                statusType = StatusType.pending;
              } else if (senderType == 'provider') {
                senderBadge = '🏢 ${senderName ?? "Provider"}';
                category = 'Announcements';
                if (type == 'exam' || annType?.toLowerCase().contains('exam') == true) {
                  icon = LucideIcons.fileCheck;
                  iconVar = IconVariant.amber;
                  statusType = StatusType.pending;
                } else if (type == 'fund' || annType?.toLowerCase().contains('fund') == true) {
                  icon = LucideIcons.banknote;
                  iconVar = IconVariant.sky;
                  statusType = StatusType.released;
                } else {
                  icon = LucideIcons.bell;
                  iconVar = IconVariant.green;
                  statusType = StatusType.approved;
                }
              } else if (type == 'success' || title.toLowerCase().contains('exam') || title.toLowerCase().contains('congrat')) {
                iconVar = IconVariant.green;
                icon = title.toLowerCase().contains('exam') ? LucideIcons.fileCheck : LucideIcons.checkCircle2;
                statusType = StatusType.approved;
                category = 'Updates';
              } else if (type == 'warning' || title.toLowerCase().contains('flag') || title.toLowerCase().contains('resubmit')) {
                iconVar = IconVariant.amber;
                icon = LucideIcons.alertTriangle;
                statusType = StatusType.pending;
                category = 'Reminders';
              } else if (type == 'error' || title.toLowerCase().contains('reject')) {
                iconVar = IconVariant.red;
                icon = LucideIcons.xCircle;
                statusType = StatusType.rejected;
                category = 'Updates';
              } else if (title.toLowerCase().contains('deadline') || title.toLowerCase().contains('schedule')) {
                category = 'Reminders';
                icon = LucideIcons.clock;
                iconVar = IconVariant.amber;
                statusType = StatusType.pending;
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
                  actionLabel: type == 'exam' || category == 'Updates' ? 'View Details →' : null,
                  route: AppRouter.applicationTracker,
                  category: category,
                  senderBadge: senderBadge,
                  senderType: senderType,
                  senderName: senderName,
                  programTitle: progTitle,
                  location: location,
                  lat: lat,
                  lng: lng,
                  announcementType: annType,
                  metadata: meta,
                  showVerified: senderType == 'admin',
                ),
              );
            }
          }
        } catch (dbErr) {
          debugPrint('[Notifications Table Query Note]: $dbErr');
        }

        // 2. Fetch live scholarship application updates
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
                  final itemId = 'flagged_${app['id']}';
                  loaded.add(
                    NotificationItem(
                      id: itemId,
                      icon: LucideIcons.alertTriangle,
                      iconVariant: IconVariant.amber,
                      title: 'Action Required: Document Issue Flagged ⚠️',
                      message: 'An issue was noted in your submitted requirement for $progTitle. Tap to view provider instructions and resubmit.',
                      time: timeStr,
                      isUnread: !_readItemIds.contains(itemId),
                      accentType: StatusType.pending,
                      actionLabel: 'Resubmit File →',
                      route: AppRouter.applicationTracker,
                      category: 'Reminders',
                      programTitle: progTitle,
                    ),
                  );
                }

                if (status == 'for_exam') {
                  final itemId = 'exam_${app['id']}';
                  loaded.add(
                    NotificationItem(
                      id: itemId,
                      icon: LucideIcons.fileCheck,
                      iconVariant: IconVariant.green,
                      title: 'Examination Shortlist 🎉',
                      message: 'Congratulations! You passed the initial evaluation for $progTitle. You are now shortlisted for the Examination stage.',
                      time: timeStr,
                      isUnread: !_readItemIds.contains(itemId),
                      accentType: StatusType.approved,
                      actionLabel: 'View Details →',
                      route: AppRouter.applicationTracker,
                      category: 'Updates',
                      programTitle: progTitle,
                    ),
                  );
                } else if (status == 'approved') {
                  final itemId = 'approved_${app['id']}';
                  loaded.add(
                    NotificationItem(
                      id: itemId,
                      icon: LucideIcons.checkCircle2,
                      iconVariant: IconVariant.green,
                      title: 'Application Approved! 🎓',
                      message: 'Congratulations! Your scholarship application for $progTitle has been officially approved. Welcome to the scholarship program!',
                      time: timeStr,
                      isUnread: !_readItemIds.contains(itemId),
                      accentType: StatusType.approved,
                      actionLabel: 'View Status →',
                      route: AppRouter.applicationTracker,
                      category: 'Updates',
                      programTitle: progTitle,
                    ),
                  );
                } else if (status == 'rejected') {
                  final itemId = 'rejected_${app['id']}';
                  loaded.add(
                    NotificationItem(
                      id: itemId,
                      icon: LucideIcons.xCircle,
                      iconVariant: IconVariant.red,
                      title: 'Application Status Update',
                      message: 'Your application for $progTitle was evaluated. ${remarks != null ? "Note: $remarks" : "Slot capacity reached for this cycle."}',
                      time: timeStr,
                      isUnread: false,
                      accentType: StatusType.rejected,
                      category: 'Updates',
                      programTitle: progTitle,
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

      // Add default welcome card if completely empty
      if (loaded.isEmpty) {
        loaded.addAll([
          NotificationItem(
            id: 'mock-1',
            icon: LucideIcons.sparkles,
            iconVariant: IconVariant.green,
            title: 'Welcome to IskoAko! 🎉',
            message: 'Your scholar account is active. Explore verified scholarships, track milestones, and receive instant announcements here.',
            time: 'Recently',
            isUnread: false,
            accentType: StatusType.approved,
            actionLabel: 'Explore Scholarships →',
            category: 'Updates',
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
        _readItemIds.add(n.id);
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

  Future<void> _handleNotificationTap(NotificationItem item) async {
    if (item.isUnread) {
      _readItemIds.add(item.id);
      setState(() => item.isUnread = false);
      try {
        await Supabase.instance.client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', item.id);
      } catch (_) {}
    }
    if (!mounted) return;

    // Navigate to dedicated NotificationDetailScreen
    await Navigator.pushNamed(
      context,
      AppRouter.notificationDetail,
      arguments: item,
    );

    if (mounted) {
      _fetchNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n.isUnread).length;

    List<NotificationItem> filtered = _notifications;
    if (_selectedTab == 'Announcements') {
      filtered = _notifications.where((n) => n.category == 'Announcements').toList();
    } else if (_selectedTab == 'Updates') {
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
                          itemBuilder: (_, idx) {
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
                              senderBadge: item.senderBadge,
                              announcementTag: item.announcementType,
                              location: item.location,
                              onTap: () => _handleNotificationTap(item),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F7EB),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 24,
                    right: 28,
                    child: Icon(
                      LucideIcons.leaf,
                      size: 26,
                      color: const Color(0xFF5BA778).withAlpha(180),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 26,
                    child: Icon(
                      LucideIcons.sparkles,
                      size: 24,
                      color: const Color(0xFFEAB308).withAlpha(200),
                    ),
                  ),
                  const Icon(
                    LucideIcons.bellOff,
                    size: 56,
                    color: Color(0xFF1E3D2F),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Notifications',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E3D2F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are all caught up! You will receive updates here when official scholarship announcements or status changes are posted.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required int unreadCount}) {
    final canPop = Navigator.canPop(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (canPop) ...[
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.arrowLeft,
                          color: Color(0xFF1E3D2F),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.diamond_rounded,
                            size: 13,
                            color: AppColors.amber,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'NOTIFICATION INBOX',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.amberDeep,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Alerts & announcements.',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E3D2F),
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/books-hats-icon.png',
                  width: 68,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedTab == 'All' ? 'All Notices' : '$_selectedTab Notices',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                GestureDetector(
                  onTap: _markAllAsRead,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.checkCheck, size: 14, color: Color(0xFF15803D)),
                        const SizedBox(width: 4),
                        Text(
                          'Mark read',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF15803D),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Modern Filter Pill Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _PillTabItem(
                    label: 'All',
                    badge: unreadCount > 0 ? '$unreadCount' : null,
                    isActive: _selectedTab == 'All',
                    onTap: () => setState(() => _selectedTab = 'All'),
                  ),
                  const SizedBox(width: 8),
                  _PillTabItem(
                    label: 'Announcements',
                    isActive: _selectedTab == 'Announcements',
                    onTap: () => setState(() => _selectedTab = 'Announcements'),
                  ),
                  const SizedBox(width: 8),
                  _PillTabItem(
                    label: 'Updates',
                    isActive: _selectedTab == 'Updates',
                    onTap: () => setState(() => _selectedTab = 'Updates'),
                  ),
                  const SizedBox(width: 8),
                  _PillTabItem(
                    label: 'Reminders',
                    isActive: _selectedTab == 'Reminders',
                    onTap: () => setState(() => _selectedTab = 'Reminders'),
                  ),
                ],
              ),
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
  final String? senderBadge;
  final String? announcementTag;
  final String? location;
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
    this.senderBadge,
    this.announcementTag,
    this.location,
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
          // Sender Badge / Tag Row
          if (senderBadge != null || announcementTag != null) ...[
            Row(
              children: [
                if (senderBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withAlpha(12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      senderBadge!,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                if (announcementTag != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      announcementTag!,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amberDeep,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],

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
            softWrap: true,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),

          // Venue Location Card (for Examination Schedules)
          if (location != null && location!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.pendingBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.amber.withAlpha(50), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.mapPin, size: 14, color: AppColors.amberDeep),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Venue: $location',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amberDeep,
                      ),
                      softWrap: true,
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.amberDeep),
                ],
              ),
            ),
          ],

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

class _PillTabItem extends StatelessWidget {
  final String label;
  final String? badge;
  final bool isActive;
  final VoidCallback onTap;

  const _PillTabItem({
    required this.label,
    this.badge,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E3D2F) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E3D2F).withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E3D2F),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
