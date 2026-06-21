import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'edit_land_screen.dart';

class SellerHiddenListingsScreen extends StatelessWidget {
  const SellerHiddenListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Firebase.auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }
    return _HiddenListings(uid: uid);
  }
}

class _HiddenListings extends StatelessWidget {
  final String uid;
  const _HiddenListings({required this.uid});

  Future<void> _unhide(BuildContext context, LandListing listing) async {
    await ListingService.instance.unhideListing(listing.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Listing is now visible to buyers'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hidden Listings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<List<LandListing>>(
        stream: ListingService.instance.watchSellerListings(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final hidden = (snapshot.data ?? [])
              .where((l) => l.status == 'hidden')
              .toList();

          if (hidden.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 72,
                    color: AppTheme.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hidden listings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hidden listings will appear here',
                    style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: hidden.length,
            itemBuilder: (context, i) {
              final listing = hidden[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (listing.photoUrls.isNotEmpty)
                      SizedBox(
                        height: 82,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: listing.photoUrls.length,
                          itemBuilder: (_, index) => Container(
                            margin: const EdgeInsets.only(right: 8, bottom: 10),
                            width: 96,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: NetworkImage(listing.photoUrls[index]),
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withValues(alpha: 0.3),
                                  BlendMode.darken,
                                ),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.visibility_off_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 72,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.visibility_off_outlined,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    Row(
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
                                  color: AppTheme.primary,
                                ),
                              ),
                              Text(
                                '${listing.size.toStringAsFixed(0)} m² • ${listing.landType}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'HIDDEN',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppTheme.primary,
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EditLandScreen(listing: listing),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.visibility_rounded,
                                color: AppTheme.success,
                              ),
                              tooltip: 'Unhide',
                              onPressed: () => _unhide(context, listing),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
