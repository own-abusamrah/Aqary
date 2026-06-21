import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../utils/app_theme.dart';
import '../../utils/logout_helper.dart';
import '../../utils/image_helper.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/app_map.dart';
import 'provider_broadcast_screen.dart';
import '../buyer/notifications_screen.dart';
import 'provider_notifications_screen.dart';
import '../../services/firebase.dart';

class ProviderProfileScreen extends StatefulWidget {
  final bool isEditing;
  const ProviderProfileScreen({super.key, this.isEditing = false});
  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _servicesController = TextEditingController();
  final _contactController = TextEditingController();

  String _providerType = 'Engineer';
  LatLng _businessLocation = const LatLng(31.9539, 35.9106);
  List<String> _galleryUrls = [];
  final List<PickedImage> _newGalleryImages = [];
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = true;
  String _userName = '';
  // اللون المخصص للهيدر العلوي ليتطابق مع الصورة
  final Color _headerColor = const Color(0xFF166077);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isEditing;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    // جلب اسم المستخدم من مجموعة users
    try {
      final userDoc =
          await Firebase.firestore.collection('users').doc(_uid!).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _userName = userDoc.data()?['name'] ?? '';
        });
      }
    } catch (_) {}

    final existing = await ProviderService.instance.getProvider(_uid!);
    if (existing != null && mounted) {
      setState(() {
        _providerType = existing.type;
        _bioController.text = existing.bio;
        _servicesController.text = existing.services;
        _contactController.text = existing.contactInfo;
        _businessLocation = LatLng(existing.latitude, existing.longitude);
        _galleryUrls = List.from(existing.galleryUrls);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _servicesController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickGalleryImages() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty) {
      final picked = await PickedImage.fromXFiles(files);
      setState(() => _newGalleryImages.addAll(picked));
    }
  }

  Future<void> _useCurrentLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos == null || !mounted) return;
    setState(() {
      _businessLocation = LatLng(pos.latitude, pos.longitude);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uid == null) return;
    setState(() => _isSaving = true);

    try {
      List<String> allGalleryUrls = List.from(_galleryUrls);
      for (final pickedImage in _newGalleryImages) {
        final url = await ProviderService.instance.uploadGalleryPhoto(
            providerId: _uid!, imageBytes: pickedImage.bytes);
        allGalleryUrls.add(url);
      }

      final provider = ServiceProvider(
        id: _uid!,
        userId: _uid!,
        type: _providerType,
        bio: _bioController.text.trim(),
        services: _servicesController.text.trim(),
        contactInfo: _contactController.text.trim(),
        latitude: _businessLocation.latitude,
        longitude: _businessLocation.longitude,
        galleryUrls: allGalleryUrls,
      );

      await ProviderService.instance.saveProfile(provider);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
          _galleryUrls = allGalleryUrls;
          _newGalleryImages.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9), // لون الخلفية الفاتح
      appBar: AppBar(
        backgroundColor: _headerColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Profile',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // أيقونة الإشعارات
          if (_uid != null)
            StreamBuilder<int>(
              stream: NotificationService.instance.watchUnreadCount(_uid!),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return Badge(
                  label: Text('$unread'),
                  isLabelVisible: unread > 0,
                  offset: const Offset(-8, 8),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProviderNotificationsScreen(),
                      ),
                    ),
                  ),
                );
              },
            ),

          // القائمة المنسدلة (Menu) التي تحتوي على الـ Premium وتسجيل الخروج
          if (_uid != null)
            StreamBuilder<AppUser?>(
              stream: PremiumService.instance.watchCurrentUser(),
              builder: (context, snapshot) {
                final user = snapshot.data;
                final isPremium = user?.isPremiumActive == true;

                return PopupMenuButton<int>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) async {
                    if (value == 1) {
                      // منطق الـ Premium
                      if (isPremium) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ProviderBroadcastScreen()),
                        );
                        return;
                      }
                      try {
                        await PremiumService.instance
                            .requestPremiumSubscription();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Premium request sent to admin.'),
                          backgroundColor: AppTheme.success,
                        ));
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('$e'),
                              backgroundColor: AppTheme.error),
                        );
                      }
                    } else if (value == 2) {
                      // تسجيل الخروج
                      confirmAndLogout(context);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(
                              isPremium
                                  ? Icons.campaign_rounded
                                  : Icons.workspace_premium_outlined,
                              color: _headerColor),
                          const SizedBox(width: 12),
                          Text(
                            isPremium ? 'Send Nearby Ad' : 'Request Premium',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 2,
                      child: Row(
                        children: [
                          const Icon(Icons.logout_rounded,
                              color: AppTheme.error),
                          const SizedBox(width: 12),
                          const Text(
                            'Log Out',
                            style: TextStyle(
                                color: AppTheme.error,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero, // لدمج لون الـ AppBar مع الـ Header
          children: [
            // الـ Header المنحني مع الـ Avatar
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // الخلفية الزرقاء المنحنية
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: _headerColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                ),
                // صورة الحساب (Avatar)
                Container(
                  margin: const EdgeInsets.only(top: 40),
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // نفس لون الصورة
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: Icon(
                    _providerType == 'Engineer'
                        ? Icons.engineering_rounded
                        : Icons.business_rounded,
                    size: 50,
                    color: _headerColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // معلومات الحساب (الاسم، الدور، والـ Bio)
            if (!_isEditing) ...[
              Center(
                child: Text(
                  _userName.isEmpty ? 'Provider' : _userName.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _providerType.toUpperCase(),
                    style: TextStyle(
                        color: _headerColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  _bioController.text.isEmpty
                      ? 'No bio yet'
                      : _bioController.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF718096), height: 1.4),
                ),
              ),
            ],

            // في وضع التعديل (Role & Bio)
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Provider Type',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Engineer', 'Construction Company'].map((t) {
                        final sel = _providerType == t;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _providerType = t),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                  color: sel ? _headerColor : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: sel
                                          ? _headerColor
                                          : const Color(0xFFE5E7EB))),
                              child: Text(t,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: sel
                                          ? Colors.white
                                          : AppTheme.textMuted)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: _bioController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'Bio',
                            alignLabelWithHint: true,
                            hintText: 'Describe your expertise...'),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Bio is required'
                            : null),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            // باقي محتوى الصفحة (الخدمات، المعرض، التواصل، الخريطة)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Services Card
                  if (_isEditing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: TextFormField(
                          controller: _servicesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'Services Offered',
                              alignLabelWithHint: true),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Services are required'
                              : null),
                    )
                  else
                    _InfoCard(
                        icon: Icons.build_outlined,
                        title: 'Services',
                        content: _servicesController.text.isEmpty
                            ? 'No services listed'
                            : _servicesController.text),

                  // Portfolio / Gallery Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
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
                                Icon(Icons.photo_library_outlined,
                                    color: _headerColor, size: 22),
                                const SizedBox(width: 10),
                                const Text('Portfolio',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A202C))),
                              ],
                            ),
                            if (_isEditing)
                              GestureDetector(
                                onTap: _pickGalleryImages,
                                child: Text('+ Add',
                                    style: TextStyle(
                                        color: _headerColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              )
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_galleryUrls.isEmpty && _newGalleryImages.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF7FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0))),
                            child: Column(
                              children: [
                                const Icon(Icons.image_not_supported_outlined,
                                    size: 40, color: Color(0xFFA0AEC0)),
                                const SizedBox(height: 8),
                                Text(
                                  _isEditing
                                      ? 'Tap "+ Add" to upload'
                                      : 'No portfolio images available',
                                  style: const TextStyle(
                                      color: Color(0xFF718096), fontSize: 13),
                                )
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            height: 100,
                            child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  ..._galleryUrls.asMap().entries.map((e) =>
                                      Stack(children: [
                                        Container(
                                            margin: const EdgeInsets.only(
                                                right: 12),
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                image: DecorationImage(
                                                    image:
                                                        NetworkImage(e.value),
                                                    fit: BoxFit.cover))),
                                        if (_isEditing)
                                          Positioned(
                                              top: 4,
                                              right: 16,
                                              child: GestureDetector(
                                                  onTap: () => ProviderService.instance
                                                      .removeGalleryPhoto(
                                                          providerId: _uid!,
                                                          photoUrl: e.value)
                                                      .then((_) => setState(() =>
                                                          _galleryUrls.removeAt(
                                                              e.key))),
                                                  child: Container(
                                                      padding: const EdgeInsets.all(
                                                          4),
                                                      decoration: BoxDecoration(
                                                          color: AppTheme.error,
                                                          shape: BoxShape.circle,
                                                          border: Border.all(color: Colors.white, width: 1.5)),
                                                      child: const Icon(Icons.close, size: 14, color: Colors.white)))),
                                      ])),
                                  ..._newGalleryImages.asMap().entries.map(
                                      (e) => PickedImageThumbnail(
                                          image: e.value,
                                          onRemove: () => setState(() =>
                                              _newGalleryImages
                                                  .removeAt(e.key)))),
                                ]),
                          )
                      ],
                    ),
                  ),

                  // Contact Card
                  if (_isEditing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: TextFormField(
                          controller: _contactController,
                          decoration: const InputDecoration(
                              labelText: 'Contact Info',
                              hintText: 'Phone, email, WhatsApp...'),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Contact info is required'
                              : null),
                    )
                  else
                    _InfoCard(
                        icon: Icons.contact_mail_outlined,
                        title: 'Contact Information',
                        content: _contactController.text.isEmpty
                            ? 'No contact info'
                            : _contactController.text),

                  // Business Location
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                color: _headerColor, size: 22),
                            const SizedBox(width: 10),
                            const Text('Business Location',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A202C))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                                height: 160,
                                child: AppMapView(
                                  center: _businessLocation,
                                  zoom: 14,
                                  interactive: _isEditing,
                                  onTap: _isEditing
                                      ? (point) => setState(
                                          () => _businessLocation = point)
                                      : null,
                                  markers: [
                                    AppMapMarker(point: _businessLocation),
                                  ],
                                ))),
                        if (_isEditing)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tap map to set location',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted)),
                                GestureDetector(
                                  onTap: _useCurrentLocation,
                                  child: Text('Use Current GPS',
                                      style: TextStyle(
                                          color: _headerColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ),
                              ],
                            ),
                          )
                      ],
                    ),
                  ),

                  // أزرار التحكم السفلية
                  if (_isEditing)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        backgroundColor: _headerColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Text('Save Profile',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        backgroundColor: _headerColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      label: const Text('Edit Profile',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget مخصصة للكروت لتطابق التصميم بالصورة
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _InfoCard(
      {required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF166077), size: 22),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A202C))), // لون نص داكن
            ],
          ),
          const SizedBox(height: 12),
          Text(content,
              style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF4A5568),
                  height: 1.4)), // رمادي
        ],
      ),
    );
  }
}
