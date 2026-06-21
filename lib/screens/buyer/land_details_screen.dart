//import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../utils/app_theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/app_map.dart';
import '../provider/providers_list_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class LandDetailsScreen extends StatefulWidget {
  final LandListing listing;
  const LandDetailsScreen({super.key, required this.listing});
  @override
  State<LandDetailsScreen> createState() => _LandDetailsScreenState();
}

class _LandDetailsScreenState extends State<LandDetailsScreen> {
  bool _isFavorite = false;
  ContactRequest? _contactRequest;
  ContactRequest? _existingSellerRequest;
  bool _loadingContact = true;
  int _currentPhotoIndex = 0;
  String? _approvedContactInfo;

  String? get _uid => Firebase.auth.currentUser?.uid;
  LandListing get listing => widget.listing;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _watchContactRequest();
  }

  // Future<void> _loadInitialData() async {
  //   if (_uid == null) return;
  //   // Check favorite status
  //   final favIds = await ListingService.instance
  //       .watchFavoriteIds(_uid!).first;

  //    //check existing seller relationship
  //   final existing = await ContactRequestService.instance
  //       .getExistingRequestWithSeller(
  //     buyerId: _uid!,
  //     sellerId: listing.sellerId,
  //   );
  //   // if (mounted) setState(() => _isFavorite = favIds.contains(listing.id));
  //   if (mounted) {
  //     setState(() {
  //       _isFavorite = favIds.contains(listing.id);
  //       _existingSellerRequest = existing;
  //     });
  //   }
  // }

  Future<void> _loadInitialData() async {
    if (_uid == null) return;

    // Favorite
    final favIds = await ListingService.instance.watchFavoriteIds(_uid!).first;

    // Existing seller relationship
    final existing =
        await ContactRequestService.instance.getExistingRequestWithSeller(
      buyerId: _uid!,
      sellerId: listing.sellerId,
    );

    String? contactInfo;

    //Reuse approved contact from any listing
    if (existing?.status == 'approved') {
      contactInfo = await ContactRequestService.instance.getSellerContactInfo(
        requestId: existing!.id,
        sellerId: listing.sellerId,
      );
    }

    if (mounted) {
      setState(() {
        _isFavorite = favIds.contains(listing.id);
        _existingSellerRequest = existing;
        _approvedContactInfo = contactInfo; //important
      });
    }
  }

  Future<void> _callNumber(String phone) async {
    // final uri = Uri.parse('tel:$phone');
    // if (await canLaunchUrl(uri)) {
    //   await launchUrl(uri);
    // }

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:$cleanPhone');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Cannot open dialer';
    }
  }

  // Future<void> _openWhatsApp(String phone) async {
  //   //Phone must be in international format (e.g. +9627...)
  //   final uri = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}');
  //   if (await canLaunchUrl(uri)) {
  //     await launchUrl(uri, mode: LaunchMode.externalApplication);
  //   }
  // }
  Future<void> _openWhatsApp(String phone, {String message = ''}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    final uriApp = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}',
    );

    final uriWeb = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );

    try {
      // Try opening WhatsApp app first
      if (await canLaunchUrl(uriApp)) {
        await launchUrl(uriApp, mode: LaunchMode.externalApplication);
        return;
      }

      //Fallback to WhatsApp Web
      if (await canLaunchUrl(uriWeb)) {
        await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
        return;
      }

      //Final fallback
      throw 'WhatsApp not available';
    } catch (_) {
      //Final fallback → SMS
      final smsUri = Uri.parse('sms:$cleanPhone');
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    }
  }

  void _watchContactRequest() {
    if (_uid == null) {
      setState(() => _loadingContact = false);
      return;
    }
    ContactRequestService.instance
        .watchRequestStatus(
      buyerId: _uid!,
      listingId: listing.id,
    )
        .listen((request) async {
      if (!mounted) return;
      setState(() {
        _contactRequest = request;
        _loadingContact = false;
      });

      // If just approved, fetch the contact info
      if (request?.status == 'approved' && _approvedContactInfo == null) {
        final info = await ContactRequestService.instance.getSellerContactInfo(
            requestId: request!.id, sellerId: listing.sellerId);
        if (mounted) setState(() => _approvedContactInfo = info);
      }
    });
  }

  Future<void> _toggleFavorite() async {
    if (_uid == null) return;
    setState(() => _isFavorite = !_isFavorite);
    if (_isFavorite) {
      await ListingService.instance.addFavorite(_uid!, listing.id);
    } else {
      await ListingService.instance.removeFavorite(_uid!, listing.id);
    }
  }

  // Future<void> _requestContact() async {
  //   if (_uid == null) return;
  //   try {
  //     await ContactRequestService.instance.createRequest(
  //       buyerId: _uid!,
  //       sellerId: listing.sellerId,
  //       listingId: listing.id,
  //     );
  //   } catch (e) {
  //     if (mounted) ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to send request: $e'),
  //           backgroundColor: AppTheme.error));
  //   }
  // }
  Future<void> _requestContact() async {
    if (_uid == null) return;
    // Prevent duplicate seller contact
    if (_existingSellerRequest != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already contacted this seller'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    try {
      await ContactRequestService.instance.createRequest(
        buyerId: _uid!,
        sellerId: listing.sellerId,
        listingId: listing.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppTheme.primary,
          flexibleSpace: FlexibleSpaceBar(
              background: listing.photoUrls.isNotEmpty
                  ? PageView.builder(
                      itemCount: listing.photoUrls.length,
                      onPageChanged: (i) =>
                          setState(() => _currentPhotoIndex = i),
                      itemBuilder: (_, i) => Image.network(listing.photoUrls[i],
                          fit: BoxFit.cover))
                  : Container(
                      color: AppTheme.background,
                      child: const Icon(Icons.landscape,
                          size: 72, color: AppTheme.textMuted))),
          actions: [
            IconButton(
                icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_outline,
                    color: _isFavorite ? AppTheme.error : Colors.white),
                onPressed: _toggleFavorite),
          ],
        ),
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (listing.photoUrls.length > 1) ...[
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      listing.photoUrls.length,
                      (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPhotoIndex == i ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: _currentPhotoIndex == i
                                  ? AppTheme.primary
                                  : const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(4))))),
              const SizedBox(height: 20),
            ],
            Text('${listing.price.toStringAsFixed(0)} JD',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary)),
            const SizedBox(height: 12),
            Row(children: [
              _SpecBadge(
                  Icons.straighten, '${listing.size.toStringAsFixed(0)} m²'),
              const SizedBox(width: 8),
              _SpecBadge(Icons.terrain, listing.landType),
              if (listing.plotNumber != null) ...[
                const SizedBox(width: 8),
                _SpecBadge(Icons.numbers, 'Plot #${listing.plotNumber}'),
              ],
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.location_on_rounded,
                  size: 16, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(listing.area,
                  style:
                      const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
            ]),
            const SizedBox(height: 20),
            const Text('Description',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            const SizedBox(height: 8),
            Text(listing.description,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textMuted, height: 1.6)),
            if (listing.deedPhotoUrl != null) ...[
              const SizedBox(height: 20),
              const Text(' Land Title Deed ',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        _DeedFullScreenViewer(url: listing.deedPhotoUrl!))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    listing.deedPhotoUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                  'Tap photo to enlarge. Aqary does not verify land ownership.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
            // Approved contact info
            if (_approvedContactInfo != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.3))),
                child: Row(
                  children: [
                    const Icon(Icons.phone_rounded,
                        color: AppTheme.success, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      // ✅ THIS IS THE REAL FIX
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Seller Contact',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _approvedContactInfo!,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.phone,
                                    color: AppTheme.success),
                                onPressed: () =>
                                    _callNumber(_approvedContactInfo!),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.chat, color: Colors.green),
                                onPressed: () => _openWhatsApp(
                                  _approvedContactInfo!,
                                  message:
                                      "Hi, I'm interested in your land listing on Aqary.",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text('Location',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            const SizedBox(height: 8),
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                    height: 180,
                    child: AppMapView(
                      center: LatLng(listing.latitude, listing.longitude),
                      zoom: 15,
                      interactive: false,
                      markers: [
                        AppMapMarker(
                          point: LatLng(listing.latitude, listing.longitude),
                        ),
                      ],
                    ))),
            const SizedBox(height: 16),
            OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProvidersListScreen(
                        nearLat: listing.latitude,
                        nearLng: listing.longitude))),
                icon: const Icon(Icons.engineering_rounded,
                    color: AppTheme.primary),
                label: const Text('Nearby Service Providers'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 100),
          ]),
        )),
      ]),
      bottomNavigationBar: _loadingContact
          ? null
          : _ContactBar(
              request: _contactRequest,
              existingSellerRequest: _existingSellerRequest,
              onRequest: _requestContact),
    );
  }
}

class _SpecBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SpecBadge(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppTheme.primary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500))
      ]));
}

class _ContactBar extends StatelessWidget {
  final ContactRequest? request;
  final VoidCallback onRequest;
  final ContactRequest? existingSellerRequest;
  const _ContactBar(
      {required this.request,
      required this.existingSellerRequest,
      required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3))
      ]),
      child: (request == null && existingSellerRequest != null)
          ? Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    //'You already contacted this seller',
                    'You already have access to this seller',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : switch (request?.status) {
              null => ElevatedButton.icon(
                  onPressed: onRequest,
                  icon: const Icon(Icons.contact_phone_outlined),
                  label: const Text('Request Contact')),
              'pending' => Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_top, color: AppTheme.accent),
                        SizedBox(width: 8),
                        Text('Request Pending',
                            style: TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w600))
                      ])),
              'approved' => Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: AppTheme.success),
                        SizedBox(width: 8),
                        Text('Contact info shown above',
                            style: TextStyle(color: AppTheme.success))
                      ])),
              _ => Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Text('Request Declined',
                      style: TextStyle(color: AppTheme.error))),
            },
    );
  }
}

class _DeedFullScreenViewer extends StatelessWidget {
  final String url;
  const _DeedFullScreenViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Title Deed', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
