//import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../utils/app_theme.dart';
import '../../utils/image_helper.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/app_map.dart';
import 'seller_home_screen.dart';

class AddLandScreen extends StatefulWidget {
  const AddLandScreen({super.key});
  @override
  State<AddLandScreen> createState() => _AddLandScreenState();
}

class _AddLandScreenState extends State<AddLandScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plotController = TextEditingController();
  final _sizeController = TextEditingController();
  final _priceController = TextEditingController();
  final _areaController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedLandType = 'Residential';
  LatLng? _selectedLocation;
  LatLng _mapCenter = _amman;
  Key _mapKey = UniqueKey(); // *** جديد ***
  bool _loadingLocation = true; // *** جديد ***
  bool _showMapPicker = true;
  bool _isSubmitting = false;
  String _submitStatus = '';

  final List<PickedImage> _pickedImages = [];
  PickedImage? _deedImage;

  static const LatLng _amman = LatLng(31.9539, 35.9106);
  static const double _minLat = 29.0;
  static const double _maxLat = 33.5;
  static const double _minLng = 34.8;
  static const double _maxLng = 39.4;

  String? get _uid => Firebase.auth.currentUser?.uid;

  // *** جديد: يجيب موقعك فور ما تُفتح الشاشة ***
  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _loadingLocation = false;
      if (pos != null) {
        final ll = LatLng(pos.latitude, pos.longitude);
        if (_isInsideJordan(ll)) {
          _mapCenter = ll;
        }
      }
      _mapKey = UniqueKey();
    });
  }

  bool _isInsideJordan(LatLng point) {
    return point.latitude >= _minLat &&
        point.latitude <= _maxLat &&
        point.longitude >= _minLng &&
        point.longitude <= _maxLng;
  }

  @override
  void dispose() {
    _plotController.dispose();
    _sizeController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _descController.dispose();
    super.dispose();
  }

  static const int _maxImages = 7;

  Future<void> _pickFromGallery() async {
    final remaining = _maxImages - _pickedImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 7 photos allowed')));
      return;
    }
    final files = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty) {
      final picked =
          await PickedImage.fromXFiles(files.take(remaining).toList());
      setState(() => _pickedImages.addAll(picked));
      if (files.length > remaining) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Maximum 7 photos allowed — extra photos were ignored')));
        }
      }
    }
  }

  Future<void> _pickFromCamera() async {
    if (_pickedImages.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 7 photos allowed')));
      return;
    }
    final file = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file != null) {
      final picked = await PickedImage.fromXFile(file);
      setState(() => _pickedImages.add(picked));
    }
  }

  Future<void> _pickDeedFromGallery() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      final picked = await PickedImage.fromXFile(file);
      setState(() => _deedImage = picked);
    }
  }

  Future<void> _pickDeedFromCamera() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file != null) {
      final picked = await PickedImage.fromXFile(file);
      setState(() => _deedImage = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a location on the map')));
      return;
    }
    if (_pickedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one photo')));
      return;
    }
    if (_uid == null) return;

    setState(() {
      _isSubmitting = true;
      _submitStatus = 'Uploading photos...';
    });

    try {
      final tempKey = '${_uid!}_${DateTime.now().millisecondsSinceEpoch}';

      final urls = await ListingService.instance.uploadPhotos(
        sellerId: _uid!,
        listingId: tempKey,
        imageBytes: _pickedImages.map((p) => p.bytes).toList(),
      );

      String? deedUrl;
      if (_deedImage != null) {
        setState(() => _submitStatus = 'Uploading title deed...');
        deedUrl = await ListingService.instance.uploadDeedPhoto(
          sellerId: _uid!,
          listingId: tempKey,
          imageBytes: _deedImage!.bytes,
        );
      }

      setState(() => _submitStatus = 'Saving listing...');
      final listing = LandListing(
        id: '',
        sellerId: _uid!,
        plotNumber: _plotController.text.trim().isEmpty
            ? null
            : _plotController.text.trim(),
        landType: _selectedLandType,
        size: double.parse(_sizeController.text),
        price: double.parse(_priceController.text),
        area: _areaController.text.trim(),
        description: _descController.text.trim(),
        photoUrls: urls,
        deedPhotoUrl: deedUrl,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        status: 'active',
        createdAt: DateTime.now(),
      );
      await ListingService.instance.createListing(listing);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const SellerHomeScreen(),
          ),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.success,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Listing published successfully'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitStatus = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to publish: $e'),
            backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showMapPicker ? 'Select Location' : 'Add Land Details'),
        leading: _showMapPicker
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showMapPicker = true)),
      ),
      body: _showMapPicker ? _buildMapPicker() : _buildDetailsForm(),
    );
  }

  Widget _buildMapPicker() {
    // *** جديد: loading بينما يجيب الموقع ***
    if (_loadingLocation) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Getting your location...',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return Stack(children: [
      AppMapView(
        key: _mapKey, // *** جديد ***
        center: _selectedLocation ?? _mapCenter,
        zoom: 14,
        onTap: (point) => setState(() {
          _selectedLocation = point;
          _mapCenter = point;
        }),
        markers: _selectedLocation == null
            ? const []
            : [
                AppMapMarker(
                  point: _selectedLocation!,
                  child:
                      const _SelectedLocationPin(), // تم استخدام الدبوس الجديد هنا
                ),
              ],
      ),
      Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10)
                  ]),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Tap the map to pin your land location',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textMuted))),
                TextButton(
                    onPressed: () async {
                      final pos =
                          await LocationService.instance.getCurrentPosition();
                      if (pos != null && mounted) {
                        final ll = LatLng(pos.latitude, pos.longitude);
                        setState(() {
                          _selectedLocation = ll;
                          _mapCenter = ll;
                          _mapKey = UniqueKey(); // *** جديد ***
                        });
                      }
                    },
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Use GPS',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600))),
              ]))),
      Positioned(
          bottom: 32,
          left: 24,
          right: 24,
          child: ElevatedButton.icon(
              onPressed: _selectedLocation != null
                  ? () => setState(() => _showMapPicker = false)
                  : null,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Confirm Location'),
              style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: Colors.grey.shade300))),
    ]);
  }

  Widget _buildDetailsForm() {
    return Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.location_on_rounded,
                    color: AppTheme.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Lat ${_selectedLocation!.latitude.toStringAsFixed(5)}, '
                        'Lng ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.success))),
                GestureDetector(
                    onTap: () => setState(() => _showMapPicker = true),
                    child: const Text('Change',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600))),
              ])),
          const SizedBox(height: 20),
          const Text('Land Type',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          const SizedBox(height: 8),
          Row(
              children: ['Residential', 'Commercial', 'Agricultural'].map((t) {
            final sel = _selectedLandType == t;
            return Expanded(
                child: GestureDetector(
                    onTap: () => setState(() => _selectedLandType = t),
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            color: sel ? AppTheme.primary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: sel
                                    ? AppTheme.primary
                                    : const Color(0xFFE5E7EB))),
                        child: Text(t,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white
                                    : AppTheme.textMuted)))));
          }).toList()),
          const SizedBox(height: 16),
          TextFormField(
              controller: _plotController,
              decoration: const InputDecoration(
                  labelText: 'Plot Number (optional)',
                  prefixIcon: Icon(Icons.numbers_rounded))),
          const SizedBox(height: 14),
          TextFormField(
              controller: _sizeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Size (m²)',
                  prefixIcon: Icon(Icons.straighten_rounded),
                  suffixText: 'm²'),
              validator: (v) =>
                  (v == null || v.isEmpty || (double.tryParse(v) ?? 0) <= 0)
                      ? 'Enter a valid size'
                      : null),
          const SizedBox(height: 14),
          TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Price (JD)',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  suffixText: 'JD'),
              validator: (v) =>
                  (v == null || v.isEmpty || (double.tryParse(v) ?? 0) <= 0)
                      ? 'Enter a valid price'
                      : null),
          const SizedBox(height: 14),
          TextFormField(
              controller: _areaController,
              decoration: const InputDecoration(
                  labelText: 'Area / Governorate',
                  prefixIcon: Icon(Icons.map_outlined),
                  hintText: 'e.g. Abdoun, Amman'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Area is required' : null),
          const SizedBox(height: 14),
          TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 64),
                      child: Icon(Icons.description_outlined))),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Description is required' : null),
          const SizedBox(height: 20),
          const Text('Photos',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          const SizedBox(height: 8),
          if (_pickedImages.isNotEmpty)
            SizedBox(
                height: 90,
                child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedImages.length,
                    itemBuilder: (_, i) => PickedImageThumbnail(
                        image: _pickedImages[i],
                        onRemove: () =>
                            setState(() => _pickedImages.removeAt(i))))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary)))),
            const SizedBox(width: 12),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: _pickFromCamera,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary)))),
          ]),
          const SizedBox(height: 24),
          Text.rich(
            TextSpan(
              text: 'Land Title Deed ',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark),
              children: [
                TextSpan(
                  text: ' optional',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
              'A photo of the title deed shown to buyers along with the listing.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted.withValues(alpha: 0.8))),
          const SizedBox(height: 8),
          if (_deedImage != null)
            Stack(children: [
              Container(
                  width: double.infinity,
                  height: 140,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_deedImage!.bytes,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 140))),
              Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                      onTap: () => setState(() => _deedImage = null),
                      child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: AppTheme.error, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white)))),
            ])
          else
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _pickDeedFromGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary)))),
              const SizedBox(width: 12),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _pickDeedFromCamera,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary)))),
            ]),
          const SizedBox(height: 32),
          if (_isSubmitting && _submitStatus.isNotEmpty) ...[
            Center(
                child: Text(_submitStatus,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13))),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Publish Listing')),
          const SizedBox(height: 16),
          Center(
              child: Text('Aqary does not verify land ownership.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted.withValues(alpha: 0.7)))),
          const SizedBox(height: 24),
        ]));
  }
}

// ==========================================
// تصميم الـ Pin المخصص لصفحة إضافة الأرض
// ==========================================
class _SelectedLocationPin extends StatelessWidget {
  const _SelectedLocationPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // المستطيل العلوي الذي يحتوي على الأيقونة والنص
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary, // استخدمنا اللون الأساسي ليكون متناسقاً
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.push_pin_rounded, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'Selected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        // المثلث السفلي (رأس الدبوس)
        CustomPaint(
          size: const Size(16, 10),
          painter: _PinTrianglePainter(color: AppTheme.primary),
        ),
      ],
    );
  }
}

// أداة رسم المثلث السفلي للـ Pin
class _PinTrianglePainter extends CustomPainter {
  final Color color;
  _PinTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0); // الزاوية العلوية اليسرى
    path.lineTo(size.width / 2, size.height); // الرأس السفلي المؤشر على الخريطة
    path.lineTo(size.width, 0); // الزاوية العلوية اليمنى
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
