import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class AdminListingsScreen extends StatefulWidget {
  const AdminListingsScreen({super.key});
  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends State<AdminListingsScreen> {
  String _statusFilter = 'All';
  List<LandListing> _listings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() => _isLoading = true);
    try {
      // Admin fetches all listings regardless of status.
      // We fetch each status separately and merge, since getListings()
      // is buyer-facing (active only). Admin uses Firestore directly.
      final db = Firebase.firestore;

      Query query = db.collection('listings').orderBy('createdAt', descending: true);
      if (_statusFilter != 'All') {
        query = query.where('status', isEqualTo: _statusFilter);
      }

      final snap = await query.limit(100).get();
      final listings = snap.docs.map((doc) =>
          LandListing.fromMap(
              Map<String, dynamic>.from(doc.data() as Map), doc.id)).toList();

      if (mounted) setState(() { _listings = listings; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleHide(LandListing listing) async {
    final isHidden = listing.status == 'hidden';
    final action = isHidden ? 'Show' : 'Hide';
    final confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Listing?'),
        content: Text(isHidden
            ? 'This will make the listing visible to buyers again.'
            : 'This will hide the listing from all buyers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(action,
                style: TextStyle(color: isHidden ? AppTheme.success : AppTheme.accent))),
        ]));
    if (confirm == true) {
      try {
        if (isHidden) {
          await AdminService.instance.showListing(listing.id);
        } else {
          await AdminService.instance.hideListing(listing.id);
        }
        _loadListings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
        }
      }
    }
  }

  Future<void> _deleteListing(LandListing listing) async {
    final confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: const Text(
            'This permanently removes the listing and all its photos. Use only for clear policy violations.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
        ]));
    if (confirm == true) {
      try {
        await AdminService.instance.deleteListing(listing.id);
        _loadListings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Listings')),
      body: Column(children: [
        // Status filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'active', 'hidden', 'deleted'].map((s) {
                final sel = _statusFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () { setState(() => _statusFilter = s); _loadListings(); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? AppTheme.primary : const Color(0xFFE5E7EB))),
                      child: Text(s[0].toUpperCase() + s.substring(1),
                        style: TextStyle(fontSize: 13,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                            color: sel ? Colors.white : AppTheme.textDark)))));
              }).toList()))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Text('${_listings.length} listing${_listings.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ])),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _listings.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.location_off_outlined, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text('No listings found', style: TextStyle(fontSize: 16, color: AppTheme.textMuted))]))
                  : RefreshIndicator(
                      onRefresh: _loadListings,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _listings.length,
                        itemBuilder: (context, i) => _AdminListingCard(
                          listing: _listings[i],
                          onToggleHide: () => _toggleHide(_listings[i]),
                          onDelete: () => _deleteListing(_listings[i]))))),
      ]),
    );
  }
}

class _AdminListingCard extends StatelessWidget {
  final LandListing listing;
  final VoidCallback onToggleHide;
  final VoidCallback onDelete;
  const _AdminListingCard({required this.listing, required this.onToggleHide, required this.onDelete});

  Color get _statusColor => switch (listing.status) {
    'active'  => AppTheme.success,
    'hidden'  => AppTheme.accent,
    _         => AppTheme.error,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 64, height: 64,
            child: listing.photoUrls.isNotEmpty
                ? Image.network(listing.photoUrls.first, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppTheme.background,
                        child: const Icon(Icons.landscape, color: AppTheme.textMuted)))
                : Container(color: AppTheme.background,
                    child: const Icon(Icons.landscape, color: AppTheme.textMuted)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${listing.price.toStringAsFixed(0)} JD',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          Text('${listing.size.toStringAsFixed(0)} m²  •  ${listing.landType}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          Text(listing.area, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(listing.status.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor))),
        ])),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted),
          onSelected: (v) { if (v == 'hide') onToggleHide(); if (v == 'delete') onDelete(); },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'hide',
              child: Row(children: [
                Icon(listing.status == 'hidden' ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(listing.status == 'hidden' ? 'Show' : 'Hide')])),
            const PopupMenuItem(value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                SizedBox(width: 8), Text('Delete')])),
          ]),
      ]));
  }
}
