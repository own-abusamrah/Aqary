import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../services/services.dart';
import '../buyer/land_details_screen.dart';
import '../provider/provider_details_screen.dart';
import 'seller_home_screen.dart';
import '../buyer/seller_public_listings_screen.dart';
import '../buyer/notifications_screen.dart';
import '../../widgets/seller_nav_bar.dart';

class SellerNotificationsScreen extends StatefulWidget {
  const SellerNotificationsScreen({super.key});

  @override
  State<SellerNotificationsScreen> createState() =>
      _SellerNotificationsScreenState();
}

class _SellerNotificationsScreenState extends State<SellerNotificationsScreen> {
  String? get _uid => Firebase.auth.currentUser?.uid;

  Future<void> _onNotificationTap(AppNotification n) async {
    await NotificationService.instance.markAsRead(n.id);
    if (!mounted) return;

    switch (n.type) {
      case 'new_listing':
      case 'premium_new_listing':
      case 'listing_updated':
      case 'premium_listing_updated':
      case 'contact_approved':
      case 'contact_rejected':
        if (n.linkedId == null) return;
        final listing = await ListingService.instance.getListing(n.linkedId!);
        if (listing != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LandDetailsScreen(listing: listing),
            ),
          );
        }
        break;

      case 'contact_request':
        if (n.linkedId == null) return;
        // linkedId هنا هو contact request ID، نجيب منه listingId
        final requestDoc = await Firebase.firestore
            .collection('contact_requests')
            .doc(n.linkedId!)
            .get();
        final listingId = requestDoc.data()?['listingId'] as String?;
        if (listingId != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SellerHomeScreen(focusListingId: listingId),
            ),
          );
        }
        break;

      case 'provider_broadcast':
        if (n.linkedId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProviderDetailsScreen(providerId: n.linkedId!),
          ),
        );
        break;

      case 'seller_broadcast':
        if (n.linkedId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SellerPublicListingsScreen(sellerId: n.linkedId!),
          ),
        );
        break;

      default:
        break;
    }
  }

  IconData _iconForType(String type) => switch (type) {
        'new_listing' => Icons.location_on_rounded,
        'premium_new_listing' => Icons.workspace_premium_rounded,
        'listing_updated' => Icons.edit_location_alt_outlined,
        'premium_listing_updated' => Icons.edit_location_alt_rounded,
        'contact_request' => Icons.contact_phone_outlined,
        'contact_approved' => Icons.check_circle_outline,
        'contact_rejected' => Icons.cancel_outlined,
        'provider_broadcast' => Icons.storefront_outlined,
        _ => Icons.notifications_outlined,
      };

  Color _colorForType(String type) => switch (type) {
        'new_listing' => AppTheme.primary,
        'premium_new_listing' => const Color(0xFF8B5CF6),
        'listing_updated' => AppTheme.primary,
        'premium_listing_updated' => const Color(0xFF8B5CF6),
        'contact_approved' => AppTheme.success,
        'contact_rejected' => AppTheme.error,
        'provider_broadcast' => const Color(0xFFF59E0B),
        _ => AppTheme.accent,
      };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Icon(Icons.notifications_rounded, color: Colors.white),
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: () => NotificationService.instance.markAllAsRead(_uid!),
            icon: const Icon(Icons.done_all_rounded,
                color: Colors.white, size: 16),
            label: const Text(
              'Mark all read',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: () =>
                NotificationService.instance.deleteAllNotifications(_uid!),
            icon: const Icon(Icons.delete_sweep_rounded,
                color: Colors.white, size: 26),
            tooltip: 'Delete all',
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationService.instance.watchNotifications(_uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error, fontSize: 14),
                ),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 56,
                      color: AppTheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).padding.bottom,
            ),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) =>
                    NotificationService.instance.deleteNotification(n.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                child: GestureDetector(
                  onTap: () => _onNotificationTap(n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isRead
                          ? Colors.white
                          : AppTheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: n.isRead
                            ? const Color(0xFFE5E7EB)
                            : AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                _colorForType(n.type).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _iconForType(n.type),
                            color: _colorForType(n.type),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: n.isRead
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: AppTheme.textMuted),
                                    tooltip: 'Delete',
                                    onPressed: () => NotificationService
                                        .instance
                                        .deleteNotification(n.id),
                                  ),
                                  Text(
                                    _timeAgo(n.createdAt),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.body,
                                style: const TextStyle(
                                    fontSize: 13, color: AppTheme.textMuted),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (n.linkedId != null &&
                                  n.type != 'broadcast') ...[
                                const SizedBox(height: 6),
                                Text(
                                  switch (n.type) {
                                    'contact_request' => 'View in My Lands ->',
                                    'provider_broadcast' => 'View profile ->',
                                    'seller_broadcast' => 'View lands ->',
                                    _ => 'View listing ->',
                                  },
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const SellerNavBar(
        currentIndex: 4,
      ),
    );
  }
}
