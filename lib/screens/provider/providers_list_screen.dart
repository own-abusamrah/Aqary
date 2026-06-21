import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'provider_details_screen.dart';
import '../../widgets/buyer_nav_bar.dart';

class ProvidersListScreen extends StatefulWidget {
  final double? nearLat;
  final double? nearLng;
  const ProvidersListScreen({super.key, this.nearLat, this.nearLng});
  @override
  State<ProvidersListScreen> createState() => _ProvidersListScreenState();
}

class _ProvidersListScreenState extends State<ProvidersListScreen> {
  String _filter = 'All';
  List<ServiceProvider> _providers = [];
  bool _isLoading = true;
  int _unreadCount = 0;
  String? get _uid => Firebase.auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadProviders();
    _watchUnreadCount();
  }

  void _watchUnreadCount() {
    if (_uid == null) return;
    NotificationService.instance.watchUnreadCount(_uid!).listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoading = true);
    try {
      double? lat = widget.nearLat;
      double? lng = widget.nearLng;

      if (lat == null || lng == null) {
        final pos = await LocationService.instance.getCurrentPosition();
        lat = pos?.latitude;
        lng = pos?.longitude;
      }

      if (lat == null || lng == null) {
        lat = 31.9539;
        lng = 35.9106;
      }

      final result = await ProviderService.instance.getNearbyProviders(
        lat: lat,
        lng: lng,
        type: _filter == 'All' ? null : _filter,
      );

      if (mounted)
        setState(() {
          _providers = result;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to load providers: $e'),
            backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Service Providers'),
        automaticallyImplyLeading: false, // ← شيل الباك
      ),
      body: Stack(
        children: [
          Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                    children:
                        ['All', 'Engineer', 'Construction Company'].map((f) {
                  final sel = _filter == f;
                  return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                          onTap: () {
                            setState(() => _filter = f);
                            _loadProviders();
                          },
                          child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                  color: sel ? AppTheme.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: sel
                                          ? AppTheme.primary
                                          : const Color(0xFFE5E7EB))),
                              child: Text(f,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: sel
                                          ? Colors.white
                                          : AppTheme.textDark)))));
                }).toList())),
            const SizedBox(height: 8),
            Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _providers.isEmpty
                        ? Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Icon(Icons.engineering_outlined,
                                    size: 64,
                                    color: AppTheme.textMuted
                                        .withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                const Text('No providers found nearby',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: AppTheme.textMuted))
                              ]))
                        : RefreshIndicator(
                            onRefresh: _loadProviders,
                            child: ListView.builder(
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, top: 16, bottom: 96),
                                itemCount: _providers.length,
                                itemBuilder: (context, i) =>
                                    _ProviderCard(provider: _providers[i])))),
          ]),
          // ← الـ Nav Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BuyerNavBar(currentIndex: 3, unreadCount: _unreadCount),
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final ServiceProvider provider;
  const _ProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProviderDetailsScreen(providerId: provider.userId),
        ),
      ),
      child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(
                      provider.type == 'Engineer'
                          ? Icons.engineering_rounded
                          : Icons.business_rounded,
                      color: AppTheme.primary,
                      size: 26)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(provider.type,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                    if (provider.bio.isNotEmpty)
                      Text(provider.bio,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ])),
            ]),
            if (provider.services.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: provider.services
                      .split(',')
                      .take(3)
                      .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(s.trim(),
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted))))
                      .toList()),
            ],
            if (provider.galleryUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                  height: 64,
                  child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.galleryUrls.length,
                      itemBuilder: (_, i) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                  image: NetworkImage(provider.galleryUrls[i]),
                                  fit: BoxFit.cover))))),
            ],
            const SizedBox(height: 12),
            if (provider.contactInfo.isNotEmpty)
              Row(children: [
                const Icon(Icons.phone_outlined,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(provider.contactInfo,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted)),
              ]),
          ])),
    );
  }
}
