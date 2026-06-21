//import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'land_details_screen.dart';
import '../../widgets/buyer_nav_bar.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  int _unreadCount = 0;
  String? get _uid => Firebase.auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _watchUnreadCount();
  }

  void _watchUnreadCount() {
    if (_uid == null) return;
    NotificationService.instance.watchUnreadCount(_uid!).listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  Future<void> _removeFavorite(LandListing listing) async {
    if (_uid == null) return;
    await ListingService.instance.removeFavorite(_uid!, listing.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          _uid == null
              ? const Center(child: Text('Please log in'))
              : StreamBuilder<List<LandListing>>(
                  stream: ListingService.instance.watchFavoriteListings(_uid!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Error: ${snapshot.error}',
                              style:
                                  const TextStyle(color: AppTheme.textMuted)));
                    }

                    final favorites = snapshot.data ?? [];

                    if (favorites.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_outline,
                                size: 72,
                                color:
                                    AppTheme.textMuted.withValues(alpha: 0.4)),
                            const SizedBox(height: 16),
                            const Text('No favorites yet',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMuted)),
                            const SizedBox(height: 8),
                            const Text(
                                'Tap the heart on any listing to save it here',
                                style: TextStyle(
                                    fontSize: 14, color: AppTheme.textMuted),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: AppTheme.navBarTotal(context)),
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final listing = favorites[index];
                        return Dismissible(
                          key: Key(listing.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _removeFavorite(listing),
                          background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white, size: 28)),
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        LandDetailsScreen(listing: listing))),
                            child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.06),
                                          blurRadius: 10)
                                    ]),
                                child: Row(children: [
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                          width: 72,
                                          height: 72,
                                          child: listing.photoUrls.isNotEmpty
                                              ? Image.network(
                                                  listing.photoUrls.first,
                                                  fit: BoxFit.cover)
                                              : Container(
                                                  color: AppTheme.background,
                                                  child: const Icon(
                                                      Icons.landscape,
                                                      color: AppTheme
                                                          .textMuted)))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(
                                            '${listing.price.toStringAsFixed(0)} JD',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary)),
                                        Text(
                                            '${listing.size.toStringAsFixed(0)} m²  •  ${listing.landType}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.textMuted)),
                                        Text(listing.area,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.textMuted)),
                                      ])),
                                  const Icon(Icons.favorite,
                                      color: AppTheme.error, size: 20),
                                ])),
                          ),
                        );
                      },
                    );
                  },
                ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BuyerNavBar(currentIndex: 0, unreadCount: _unreadCount),
          ),
        ],
      ),
    );
  }
}
