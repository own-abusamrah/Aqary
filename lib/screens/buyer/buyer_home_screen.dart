//import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// تم إضافة hide Path لمنع التعارض مع أداة الرسم
import 'package:latlong2/latlong.dart' hide Path;
import '../../utils/app_theme.dart';
import '../../utils/logout_helper.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/app_map.dart';
import 'filters_screen.dart';
import 'land_details_screen.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'premium_pins_screen.dart';
import '../provider/providers_list_screen.dart';
import '../../widgets/buyer_nav_bar.dart';
import 'dart:ui';
import '../buyer/profile/buyer_profile_screen.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedNavIndex = 2;
  int _unreadCount = 0;

  Map<String, dynamic> _filters = {};
  List<LandListing> _listings = [];
  Set<String> _favoriteIds = {};
  bool _isLoading = true;
  String? _nextDocId;
  bool _hasMore = false;
  LandListing? _selectedListing;
  double _mapZoom = 13;

  static LatLng _amman = const LatLng(31.9539, 35.9106);
  LatLng _mapCenter = _amman;
  String? get _uid => Firebase.auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _loadCurrentLoc();
    _loadListings();
    _loadFavorites();
    _startLocationUpdates();
    _watchUnreadCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    LocationService.instance.stopPeriodicLocationUpdates();
    super.dispose();
  }

  void _watchUnreadCount() {
    if (_uid == null) return;
    NotificationService.instance.watchUnreadCount(_uid!).listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  void _startLocationUpdates() {
    LocationService.instance.requestPermission().then((_) {
      LocationService.instance.startPeriodicLocationUpdates();
    });
  }

  Future<void> _loadListings({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _listings = [];
        _nextDocId = null;
      });
    }
    setState(() => _isLoading = true);
    try {
      final result = await ListingService.instance.getListings(
        area: _filters['area'],
        landType: _filters['landTypes'] != null &&
                (_filters['landTypes'] as List).isNotEmpty
            ? (_filters['landTypes'] as List).first as String
            : _filters['landType'],
        minPrice: _filters['minPrice']?.toDouble(),
        maxPrice: _filters['maxPrice']?.toDouble(),
        minSize: _filters['minSize']?.toDouble(),
        maxSize: _filters['maxSize']?.toDouble(),
        lastDocId: refresh ? null : _nextDocId,
      );
      setState(() {
        _listings =
            refresh ? result.listings : [..._listings, ...result.listings];
        _nextDocId = result.nextDocId;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load listings: $e')));
      }
    }
  }

  void _loadFavorites() {
    if (_uid == null) return;
    ListingService.instance.watchFavoriteIds(_uid!).listen((ids) {
      if (mounted) setState(() => _favoriteIds = ids);
    });
  }

  Future<void> _loadCurrentLoc() async {
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null && mounted) {
        final ll = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _amman = ll;
          _mapCenter = ll;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite(LandListing listing) async {
    if (_uid == null) return;
    final isFav = _favoriteIds.contains(listing.id);
    if (isFav) {
      await ListingService.instance.removeFavorite(_uid!, listing.id);
    } else {
      await ListingService.instance.addFavorite(_uid!, listing.id);
    }
  }

  void _openFilters() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => FiltersScreen(currentFilters: _filters)),
    );
    if (result != null) {
      setState(() => _filters = result);
      _loadListings(refresh: true);
    }
  }

  // ─── تصميم القائمة الجانبية (End Drawer) ───
  Widget _buildSideMenu() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.65,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 24,
              left: 20,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Buyer Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded,
                color: AppTheme.primary),
            title: const Text(
              'Profile',
              style: TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BuyerProfileScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Colors.grey.shade200, height: 1),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              confirmAndLogout(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      endDrawer: _buildSideMenu(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on_rounded, size: 20, color: AppTheme.primary),
          SizedBox(width: 6),
          Text('Aqary',
              style: TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
            child: InkWell(
              onTap: _openFilters,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.tune_rounded,
                        color: AppTheme.primary, size: 22),
                    if (_filters.isNotEmpty)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Builder(
            builder: (innerContext) => Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: InkWell(
                onTap: () {
                  Scaffold.of(innerContext).openEndDrawer();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Tooltip(
                    message: 'Menu',
                    child: Icon(Icons.more_vert_rounded,
                        color: AppTheme.primary, size: 22),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicatorPadding: const EdgeInsets.all(4),
              indicator: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Map')
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('List')
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildMapView(), _buildListView()],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BuyerNavBar(
              currentIndex: _selectedNavIndex,
              unreadCount: _unreadCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    final currentListing = _selectedListing;

    return Stack(children: [
      AppMapView(
        center: _mapCenter,
        zoom: _mapZoom,
        onTap: (_) => setState(() => _selectedListing = null),
        markers: _listings.map((listing) {
          final isSelected = _selectedListing?.id == listing.id;
          return AppMapMarker(
            point: LatLng(listing.latitude, listing.longitude),
            // نستخدم الـ ID مع حالة التحديد لضمان إعادة رسم الـ Marker عند النقر (خاصة بخرائط جوجل)
            title: isSelected ? '${listing.id}_selected' : listing.id,
            onTap: () => setState(() => _selectedListing = listing),
            // تمرير التصميم الحديث مع دعم ميزة تغيير اللون عند التحديد
            child: _ModernPricePin(
              price: listing.formattedPrice,
              isSelected: isSelected,
            ),
          );
        }).toList(),
      ),
      if (_isLoading)
        const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(child: CircularProgressIndicator())),
      Positioned(
        right: 12,
        bottom: AppTheme.navBarTotal(context) + 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MapControlButton(
              icon: Icons.add,
              onTap: () =>
                  setState(() => _mapZoom = (_mapZoom + 1).clamp(1, 20)),
            ),
            const SizedBox(height: 4),
            _MapControlButton(
              icon: Icons.remove,
              onTap: () =>
                  setState(() => _mapZoom = (_mapZoom - 1).clamp(1, 20)),
            ),
            const SizedBox(height: 8),
            _MapControlButton(
              icon: Icons.my_location_rounded,
              onTap: () async {
                final pos = await LocationService.instance.getCurrentPosition();
                if (pos != null && mounted) {
                  setState(
                      () => _mapCenter = LatLng(pos.latitude, pos.longitude));
                }
              },
            ),
          ],
        ),
      ),
      if (currentListing != null)
        Positioned(
          bottom: AppTheme.navBarTotal(context) + 29,
          left: 16,
          right: 16,
          child: _QuickInfoCard(
            listing: currentListing,
            isFavorite: _favoriteIds.contains(currentListing.id),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LandDetailsScreen(listing: currentListing))),
            onFavorite: () => _toggleFavorite(currentListing),
            onDismiss: () => setState(() => _selectedListing = null),
          ),
        ),
    ]);
  }

  Widget _buildListView() {
    if (_isLoading && _listings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_listings.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.search_off_rounded,
            size: 64, color: AppTheme.textMuted),
        const SizedBox(height: 12),
        const Text('No listings found',
            style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        TextButton(
            onPressed: () => _loadListings(refresh: true),
            child: const Text('Refresh')),
      ]));
    }

    final double topPadding =
        MediaQuery.of(context).padding.top + kToolbarHeight + 80;

    return RefreshIndicator(
      onRefresh: () => _loadListings(refresh: true),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
            16, topPadding, 16, AppTheme.navBarTotal(context) + 16),
        itemCount: _listings.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _listings.length) {
            _loadListings();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final listing = _listings[index];
          return _ListingCard(
            listing: listing,
            isFavorite: _favoriteIds.contains(listing.id),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LandDetailsScreen(listing: listing))),
            onFavorite: () => _toggleFavorite(listing),
          );
        },
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppTheme.primary),
      ),
    );
  }
}

class _QuickInfoCard extends StatelessWidget {
  final LandListing listing;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onDismiss;
  const _QuickInfoCard(
      {required this.listing,
      required this.isFavorite,
      required this.onTap,
      required this.onFavorite,
      required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)
            ]),
        child: Row(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                  width: 80,
                  height: 80,
                  color: AppTheme.background,
                  child: listing.photoUrls.isNotEmpty
                      ? Image.network(listing.photoUrls.first,
                          fit: BoxFit.cover)
                      : const Icon(Icons.landscape,
                          size: 36, color: AppTheme.textMuted))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${listing.price.toStringAsFixed(0)} JD',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark)),
                Text(
                    '${listing.size.toStringAsFixed(0)} m²  •  ${listing.landType}',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted)),
                Text(listing.area,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ])),
          Column(children: [
            IconButton(
                icon:
                    const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                onPressed: onDismiss),
            IconButton(
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_outline,
                    color: AppTheme.error),
                onPressed: onFavorite),
          ]),
        ]),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final LandListing listing;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  const _ListingCard(
      {required this.listing,
      required this.isFavorite,
      required this.onTap,
      required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07), blurRadius: 12)
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: listing.photoUrls.isNotEmpty
                      ? Image.network(listing.photoUrls.first,
                          fit: BoxFit.cover)
                      : Container(
                          color: AppTheme.background,
                          child: const Icon(Icons.landscape,
                              size: 48, color: AppTheme.textMuted)))),
          Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${listing.price.toStringAsFixed(0)} JD',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary)),
                          IconButton(
                              icon: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_outline,
                                  color: AppTheme.error),
                              onPressed: onFavorite,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints()),
                        ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      _Chip('${listing.size.toStringAsFixed(0)} m²'),
                      const SizedBox(width: 8),
                      _Chip(listing.landType),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(listing.area,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textMuted)),
                    ]),
                  ])),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primary,
              fontWeight: FontWeight.w500)));
}

class _ModernPricePin extends StatelessWidget {
  final String price;
  final bool isSelected;

  const _ModernPricePin({required this.price, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.accent : AppTheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6), // حواف شبه حادة أنيقة
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            price,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // المثلث في الأسفل
        CustomPaint(
          size: const Size(14, 8),
          painter: _PinTrianglePainter(color: color),
        ),
      ],
    );
  }
}

// الرسام الخاص برسم المثلث السفلي بدقة
class _PinTrianglePainter extends CustomPainter {
  final Color color;

  _PinTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0); // الزاوية العلوية اليسرى للمثلث
    path.lineTo(size.width / 2, size.height); // الرأس السفلي
    path.lineTo(size.width, 0); // الزاوية العلوية اليمنى
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
