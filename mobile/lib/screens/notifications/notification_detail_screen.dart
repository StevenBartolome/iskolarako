import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'notification_screen.dart';

class NotificationDetailScreen extends StatefulWidget {
  final NotificationItem? notification;

  const NotificationDetailScreen({super.key, this.notification});

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  late NotificationItem _item;
  bool _isMarkingRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.notification != null) {
      _item = widget.notification!;
    } else {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is NotificationItem) {
        _item = args;
      } else {
        _item = NotificationItem(
          id: 'preview',
          icon: LucideIcons.bell,
          iconVariant: IconVariant.green,
          title: 'Notification Notice',
          message: 'No details available.',
          time: 'Recently',
          isUnread: false,
          accentType: StatusType.info,
        );
      }
    }
    _autoMarkAsRead();
  }

  Future<void> _autoMarkAsRead() async {
    if (_item.isUnread && !_isMarkingRead) {
      _isMarkingRead = true;
      try {
        await Supabase.instance.client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', _item.id);
        setState(() {
          _item.isUnread = false;
        });
      } catch (e) {
        debugPrint('[Auto Mark Read Error]: $e');
      } finally {
        _isMarkingRead = false;
      }
    }
  }

  Future<void> _launchGoogleMapsDirections() async {
    final lat = _item.lat;
    final lng = _item.lng;
    final loc = _item.location ?? '';

    Uri url;
    if (lat != null && lng != null) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else if (loc.isNotEmpty) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(loc)}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No location coordinates or venue address available.', style: GoogleFonts.inter()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[Launch Google Maps Error]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open map: $e', style: GoogleFonts.inter()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String? _getStaticMapUrl() {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'AIzaSyC7X2FgqGkYw65WPXGxo5lRoHL11y3D1k0';
    final lat = _item.lat;
    final lng = _item.lng;
    final loc = _item.location;

    if (lat != null && lng != null) {
      return 'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=15&size=600x300&scale=2&maptype=roadmap&markers=color:red%7Clabel:V%7C$lat,$lng&key=$apiKey';
    } else if (loc != null && loc.isNotEmpty) {
      return 'https://maps.googleapis.com/maps/api/staticmap?center=${Uri.encodeComponent(loc)}&zoom=15&size=600x300&scale=2&maptype=roadmap&markers=color:red%7Clabel:V%7C${Uri.encodeComponent(loc)}&key=$apiKey';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isExam = _item.announcementType == 'Examination Schedule' ||
                   _item.title.toLowerCase().contains('exam') ||
                   _item.category == 'Reminders' && _item.location != null;
    final staticMapUrl = _getStaticMapUrl();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
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
                              'NOTICE DETAILS',
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
                          'Broadcast & Alerts',
                          style: GoogleFonts.inter(
                            fontSize: 18,
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
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Badges & Category
                    Row(
                      children: [
                        if (_item.senderBadge != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withAlpha(12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _item.senderBadge!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (_item.announcementType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _item.announcementType!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.amberDeep,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      _item.title,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date & Time Timestamp
                    Row(
                      children: [
                        const Icon(LucideIcons.calendar, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          _item.time,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_item.showVerified) ...[
                          const SizedBox(width: 10),
                          const VerifiedBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Program info card if present
                    if (_item.programTitle != null && _item.programTitle!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.rule, width: 0.8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(LucideIcons.graduationCap, size: 18, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scholarship Program',
                                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    _item.programTitle!,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Message Body Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.rule, width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withAlpha(8),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Message Announcement',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.amberDeep,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _item.message,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Examination Venue Section (Interactive Google Maps Preview)
                    if (isExam && _item.location != null && _item.location!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.amber.withAlpha(60), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.amber.withAlpha(12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(LucideIcons.mapPin, size: 16, color: AppColors.amberDeep),
                                    const SizedBox(width: 6),
                                    Text(
                                      'EXAMINATION VENUE',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.amberDeep,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.amber.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Verified Pin',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.amberDeep),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Text(
                              _item.location!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Static Google Map Image
                            if (staticMapUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  height: 160,
                                  width: double.infinity,
                                  color: Colors.grey.shade200,
                                  child: Image.network(
                                    staticMapUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: progress.expectedTotalBytes != null
                                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                              : null,
                                          color: AppColors.amber,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: AppColors.pendingBg,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(LucideIcons.map, size: 28, color: AppColors.amberDeep),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Map Preview Available',
                                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.amberDeep),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Open in Google Maps Directions Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _launchGoogleMapsDirections,
                                icon: const Icon(LucideIcons.navigation, size: 16, color: Colors.white),
                                label: Text(
                                  'Get Directions in Google Maps',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Action Button (View tracker or explore scholarships)
                    if (_item.route != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, _item.route!);
                          },
                          icon: const Icon(LucideIcons.arrowRight, size: 16, color: AppColors.primaryDark),
                          label: Text(
                            _item.actionLabel ?? 'Open Application Tracker',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.rule, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
