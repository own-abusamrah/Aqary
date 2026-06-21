import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // استدعاء الفايربيس مهم جداً هنا
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/app_theme.dart';
import 'package:flutter/services.dart';

class ProviderDetailsScreen extends StatefulWidget {
  final String providerId;
  const ProviderDetailsScreen({super.key, required this.providerId});

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  ServiceProvider? _provider;
  String _userName = ''; // لتخزين اسم اليوزر الحقيقي
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 1. جلب بيانات المزود
      final provider =
          await ProviderService.instance.getProvider(widget.providerId);

      String fetchedName = 'Unknown User';

      if (provider != null) {
        debugPrint(
            '✅ Provider loaded: ${provider.id} | UserID: ${provider.userId}');

        // 2. البحث عن المستخدم في جدول users
        final userDoc = await FirebaseFirestore.instance
            .collection('users') // تأكد أن الاسم هنا يطابق الفايربيس تماماً
            .doc(provider.userId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final appUser = AppUser.fromMap(userDoc.data()!, userDoc.id);

          fetchedName = appUser.name.isNotEmpty
              ? appUser.name.toUpperCase()
              : 'Name is Empty in DB';
        } else {}
      }

      if (mounted) {
        setState(() {
          _provider = provider;
          _userName = fetchedName;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  IconData _providerIcon(String type) {
    switch (type.toLowerCase()) {
      case 'engineer':
        return Icons.engineering_rounded;
      case 'contractor':
        return Icons.construction_rounded;
      case 'lawyer':
        return Icons.gavel_rounded;
      case 'surveyor':
        return Icons.map_rounded;
      case 'construction company':
        return Icons.business_rounded;
      default:
        return Icons.business_center_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final provider = _provider;
    if (provider == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
            child: Text('Provider not found', style: TextStyle(fontSize: 18))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. الخلفية العلوية والصورة الشخصية (Avatar)
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                height: 220,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
              ),
              Positioned(
                bottom: -55,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: const Color(0xFFE8F0F2),
                    child: Icon(
                      _providerIcon(provider.type),
                      size: 55,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 65),

          // 2. معلومات المزود (الاسم المجلوب من فايربيس، الدور، والوصف)
          Center(
            child: Text(
              _userName.isNotEmpty
                  ? _userName
                  : 'User Name', // عرض الاسم المجلوب
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                provider.type.toUpperCase(), // نوع المزود (ENGINEER وغيرها)
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          if (provider.bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                provider.bio,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],

          const SizedBox(height: 30),

          // 3. البطاقات (الخدمات، معرض الأعمال، ومعلومات الاتصال)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (provider.services.isNotEmpty) ...[
                  _buildSectionCard(
                    icon: Icons.build_circle_outlined,
                    title: 'Services',
                    child: Text(
                      provider.services,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildSectionCard(
                  icon: Icons.photo_library_outlined,
                  title: 'Portfolio',
                  child: provider.galleryUrls.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.image_not_supported_outlined,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No portfolio images available',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: provider.galleryUrls.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                          itemBuilder: (_, index) {
                            return GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    backgroundColor: Colors.black,
                                    child: InteractiveViewer(
                                      child: Image.network(
                                        provider.galleryUrls[index],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  provider.galleryUrls[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                if (provider.contactInfo.isNotEmpty) ...[
                  _buildSectionCard(
                    icon: Icons.contact_mail_outlined,
                    title: 'Contact Information',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.contactInfo,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.copy_rounded,
                                  color: AppTheme.primary, size: 20),
                              tooltip: 'Copy',
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: provider.contactInfo));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied successfully'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
