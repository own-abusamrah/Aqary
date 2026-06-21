import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/logout_helper.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'seller_broadcast_screen.dart';
import 'add_land_screen.dart';
import 'edit_land_screen.dart';
import 'seller_contact_requests_screen.dart';
import 'seller_hidden_listings_screen.dart';
import 'seller_notifications_screen.dart';
import 'premium_membership_screen.dart';
import '../../widgets/seller_nav_bar.dart';
import 'profile/seller_profile_screen.dart';

class SellerHomeScreen extends StatelessWidget {
  final String? focusListingId;
  const SellerHomeScreen({super.key, this.focusListingId});

  @override
  Widget build(BuildContext context) {
    final uid = Firebase.auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }
    return _SellerHome(uid: uid, focusListingId: focusListingId);
  }
}

class _SellerHome extends StatefulWidget {
  final String uid;
  final String? focusListingId;
  const _SellerHome({required this.uid, this.focusListingId});

  @override
  State<_SellerHome> createState() => _SellerHomeState();
}

class _SellerHomeState extends State<_SellerHome> {
  // 'all', 'active', 'hidden'
  String _filter = 'all';

  Future<void> _hideListing(BuildContext context, LandListing listing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hide Listing?'),
        content: const Text(
            'This listing will be hidden from buyers. You can unhide it anytime from Hidden Listings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hide', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await ListingService.instance.hideListing(listing.id);
    await NotificationService.instance
        .deleteNotificationsByLinkedId(listing.id);
  }

  Future<void> _unhideListing(BuildContext context, LandListing listing) async {
    await ListingService.instance.unhideListing(listing.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing is now visible to buyers')),
      );
    }
  }

  Future<void> _deleteListing(BuildContext context, LandListing listing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: const Text(
            'This will permanently delete the listing, all contact requests, and related notifications. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ListingService.instance.deleteListing(listing.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing deleted successfully'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // استخدمنا endDrawer لكي تفتح من اليمين
      endDrawer: _buildDrawer(context),
      body: StreamBuilder<List<LandListing>>(
        stream: ListingService.instance.watchSellerListings(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allListings = snapshot.data ?? [];
          final listings = widget.focusListingId == null
              ? allListings
              : allListings
                  .where((l) => l.id == widget.focusListingId)
                  .toList();

          final totalCount = listings.length;
          final activeCount =
              listings.where((l) => l.status == 'active').length;
          final hiddenCount =
              listings.where((l) => l.status == 'hidden').length;

          final filtered = _filter == 'all'
              ? listings
              : listings.where((l) => l.status == _filter).toList();

          return Stack(
            children: [
              // ─── الطبقة الخلفية (الرأس المخصص) ───
              Container(
                height: 125,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
              ),

              // ─── الطبقة الأمامية (المحتوى) ───
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // شريط العنوان المخصص
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // مسافة فارغة على اليسار للحفاظ على العنوان في المنتصف
                          const SizedBox(width: 48),

                          Expanded(
                            child: Text(
                              widget.focusListingId == null
                                  ? 'My Lands'
                                  : 'Requested Land',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          // زر المنيو أصبح على اليمين الآن
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu_rounded,
                                  color: Colors.white, size: 28),
                              tooltip: 'Menu',
                              // تم التعديل لفتح endDrawer
                              onPressed: () =>
                                  Scaffold.of(context).openEndDrawer(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ─── أزرار الفلترة (Stats Card) ───
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ModernFilterTab(
                                label: 'Total',
                                count: totalCount,
                                selected: _filter == 'all',
                                onTap: () => setState(() => _filter = 'all'),
                              ),
                            ),
                            Expanded(
                              child: _ModernFilterTab(
                                label: 'Active',
                                count: activeCount,
                                selected: _filter == 'active',
                                onTap: () => setState(() => _filter = 'active'),
                              ),
                            ),
                            Expanded(
                              child: _ModernFilterTab(
                                label: 'Hidden',
                                count: hiddenCount,
                                selected: _filter == 'hidden',
                                onTap: () => setState(() => _filter = 'hidden'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ─── قائمة الأراضي ───
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_location_alt_outlined,
                                      size: 72,
                                      color: AppTheme.textMuted
                                          .withValues(alpha: 0.4)),
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.focusListingId == null
                                        ? 'No listings yet'
                                        : 'Requested land not found',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.focusListingId == null
                                        ? 'Tap + to add your first land listing'
                                        : 'This notification opens only the land tied to that contact request.',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textMuted),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async {},
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  MediaQuery.of(context).padding.bottom,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, i) => _SellerListingCard(
                                  listing: filtered[i],
                                  onEdit: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => EditLandScreen(
                                            listing: filtered[i])),
                                  ),
                                  onHide: () =>
                                      _hideListing(context, filtered[i]),
                                  onUnhide: () =>
                                      _unhideListing(context, filtered[i]),
                                  onDelete: () =>
                                      _deleteListing(context, filtered[i]),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const SellerNavBar(
        currentIndex: 0,
      ),
    );
  }

  // ─── التصميم الجديد للقائمة الجانبية (Drawer) ───
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        // جعل حواف القائمة دائرية من الجهة اليسرى لتعطي طابع عصري
        borderRadius: BorderRadius.horizontal(left: Radius.circular(30)),
      ),
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // 1. الهيدر (الجزء العلوي) مع زر الـ X
          Container(
            padding:
                const EdgeInsets.only(top: 50, bottom: 30, left: 20, right: 20),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.primary, // متناسق مع لون الثيم الخاص بك
              borderRadius: BorderRadius.only(topLeft: Radius.circular(30)),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dashboard_customize_rounded,
                          color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Seller Menu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // زر الـ X لإغلاق القائمة
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () {
                        Navigator.pop(context); // إغلاق القائمة
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. عناصر القائمة
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            leading: const Icon(Icons.person_outline_rounded,
                color: AppTheme.primary, size: 26),
            title: const Text(
              'Profile',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(context); // إغلاق المنيو أولاً
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SellerProfileScreen()),
              );
            },
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Divider(color: Colors.black12, thickness: 1),
          ),

          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            leading: const Icon(Icons.logout_rounded,
                color: AppTheme.error, size: 26),
            title: const Text(
              'Log Out',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error),
            ),
            onTap: () {
              Navigator.pop(context); // إغلاق المنيو
              confirmAndLogout(context); // استدعاء دالة الخروج
            },
          ),
        ],
      ),
    );
  }
}

// ─── زر الفلتر ───────────────────────────────────────────────────────────────

class _ModernFilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _ModernFilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: selected ? AppTheme.primary : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: selected ? AppTheme.primary : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 4,
            width: selected ? 70 : 0,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Listing Card ─────────────────────────────────────────────────────────────

class _SellerListingCard extends StatelessWidget {
  final LandListing listing;
  final VoidCallback onEdit;
  final VoidCallback onHide;
  final VoidCallback? onUnhide;
  final VoidCallback onDelete;

  const _SellerListingCard({
    required this.listing,
    required this.onEdit,
    required this.onHide,
    this.onUnhide,
    required this.onDelete,
  });

  Color get _statusColor => switch (listing.status) {
        'active' => AppTheme.success,
        'hidden' => AppTheme.accent,
        _ => AppTheme.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 10),
        ],
      ),
      // ... بداية دالة build ...
      child: Column(
        children: [
          // ─── قسم الصور بعد التكبير ───
          if (listing.photoUrls.isNotEmpty)
            SizedBox(
              height: 130, // 👈 الحجم القديم كان 82، جعلناه 130
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: listing.photoUrls.length,
                itemBuilder: (_, index) => Container(
                  margin: const EdgeInsets.only(right: 12, bottom: 12), // مسافة أوسع قليلاً
                  width: 160, // 👈 العرض القديم كان 96، جعلناه 160
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12), // حواف دائرية أنعم
                    image: DecorationImage(
                      image: NetworkImage(listing.photoUrls[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            )
          else
            // ─── حالة عدم وجود صور (الـ Placeholder) ───
            Container(
              height: 118, // 👈 كبرنا المكان المخصص ليتناسب مع التصميم الجديد
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                // كبرنا أيقونة الأرض لتتناسب مع المساحة الجديدة
                child: Icon(Icons.landscape_rounded, size: 40, color: AppTheme.textMuted), 
              ),
            ),
            
          // ─── قسم النصوص والقائمة المنسدلة (يبقى كما هو) ───
          Row(

            // جعل العناصر في الأعلى لتكون الثلاث نقاط بمحاذاة السعر
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${listing.price.toStringAsFixed(0)} JD',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary),
                    ),
                    Text(
                      '${listing.size.toStringAsFixed(0)} m2 • ${listing.landType}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        listing.status.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _statusColor),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── القائمة المنسدلة الجديدة ───
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppTheme.textMuted),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'visibility') {
                    listing.status == 'hidden' ? onUnhide?.call() : onHide();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: const [
                        Icon(Icons.edit_outlined,
                            color: AppTheme.primary, size: 20),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'visibility',
                    child: Row(
                      children: [
                        Icon(
                          listing.status == 'hidden'
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(listing.status == 'hidden' ? 'Unhide' : 'Hide'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: const [
                        Icon(Icons.delete_outline,
                            color: AppTheme.error, size: 20),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: AppTheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
              // ────────────────────────────────
            ],
          ),
        ],
      ),
    );
  }
}
