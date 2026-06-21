import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../../utils/image_helper.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/app_map.dart';

class EditLandScreen extends StatefulWidget {
  final LandListing listing;
  const EditLandScreen({super.key, required this.listing});
  @override
  State<EditLandScreen> createState() => _EditLandScreenState();
}

class _EditLandScreenState extends State<EditLandScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plotController;
  late final TextEditingController _sizeController;
  late final TextEditingController _priceController;
  late final TextEditingController _areaController;
  late final TextEditingController _descController;

  late String _selectedLandType;
  late LatLng _selectedLocation;
  late List<String> _existingUrls; // already uploaded
  final List<PickedImage> _newImages = []; // newly picked, not yet uploaded
  String? _existingDeedUrl;
  PickedImage? _newDeedImage;
  bool _removeDeed = false;
  bool _isSubmitting = false;
  String _submitStatus = '';
  String? get _uid => Firebase.auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final l = widget.listing;
    _plotController = TextEditingController(text: l.plotNumber ?? '');
    _sizeController = TextEditingController(text: l.size.toStringAsFixed(0));
    _priceController = TextEditingController(text: l.price.toStringAsFixed(0));
    _areaController = TextEditingController(text: l.area);
    _descController = TextEditingController(text: l.description);
    _selectedLandType = l.landType;
    _selectedLocation = LatLng(l.latitude, l.longitude);
    _existingUrls = List.from(l.photoUrls);
    _existingDeedUrl = l.deedPhotoUrl;
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

  Future<void> _pickImages() async {
    final totalCurrent = _existingUrls.length + _newImages.length;
    final remaining = _maxImages - totalCurrent;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 7 photos allowed')));
      return;
    }
    final files = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty) {
      final picked =
          await PickedImage.fromXFiles(files.take(remaining).toList());
      setState(() => _newImages.addAll(picked));
      if (files.length > remaining) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Maximum 7 photos allowed — extra photos were ignored')));
        }
      }
    }
  }

  Future<void> _pickDeedFromGallery() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      final picked = await PickedImage.fromXFile(file);
      setState(() {
        _newDeedImage = picked;
        _removeDeed = false;
      });
    }
  }

  Future<void> _pickDeedFromCamera() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file != null) {
      final picked = await PickedImage.fromXFile(file);
      setState(() {
        _newDeedImage = picked;
        _removeDeed = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingUrls.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('At least one photo is required')));
      return;
    }
    if (_uid == null) return;
    setState(() {
      _isSubmitting = true;
      _submitStatus = 'Saving...';
    });

    try {
      List<String> allUrls = List.from(_existingUrls);

      // Upload any newly added images
      if (_newImages.isNotEmpty) {
        setState(() =>
            _submitStatus = 'Uploading ${_newImages.length} new photo(s)...');
        final newUrls = await ListingService.instance.uploadPhotos(
          sellerId: _uid!,
          listingId: widget.listing.id,
          imageBytes: _newImages.map((p) => p.bytes).toList(),
        );
        allUrls.addAll(newUrls);
      }

      String? deedUrl = _removeDeed ? null : _existingDeedUrl;
      if (_newDeedImage != null) {
        setState(() => _submitStatus = 'Uploading title deed...');
        deedUrl = await ListingService.instance.uploadDeedPhoto(
          sellerId: _uid!,
          listingId: widget.listing.id,
          imageBytes: _newDeedImage!.bytes,
        );
      }

      setState(() => _submitStatus = 'Updating listing...');
      await ListingService.instance.updateListing(widget.listing.id, {
        'plotNumber': _plotController.text.trim().isEmpty
            ? null
            : _plotController.text.trim(),
        'landType': _selectedLandType,
        'size': double.parse(_sizeController.text),
        'price': double.parse(_priceController.text),
        'area': _areaController.text.trim(),
        'description': _descController.text.trim(),
        'photoUrls': allUrls,
        'deedPhotoUrl': deedUrl,
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Listing updated'),
            backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitStatus = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Edit Listing')),
        body: Form(
            key: _formKey,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              // Location map (tap to move pin)
              const Text('Location',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
              const SizedBox(height: 8),
              ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                      height: 160,
                      child: AppMapView(
                        center: _selectedLocation,
                        zoom: 15,
                        onTap: (point) =>
                            setState(() => _selectedLocation = point),
                        markers: [
                          AppMapMarker(
                            point: _selectedLocation,
                          ),
                        ],
                      ))),
              const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Tap the map to adjust the pin location.',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textMuted))),
              const SizedBox(height: 20),
              // Land type
              const Text('Land Type',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
              const SizedBox(height: 8),
              Row(
                  children:
                      ['Residential', 'Commercial', 'Agricultural'].map((t) {
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
                      prefixIcon: Icon(Icons.map_outlined)),
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
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Description is required'
                      : null),
              const SizedBox(height: 20),
              const Text('Photos',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
              const SizedBox(height: 8),
              SizedBox(
                  height: 90,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    // Existing uploaded photos
                    ..._existingUrls
                        .asMap()
                        .entries
                        .map((e) => Stack(children: [
                              Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                          image: NetworkImage(e.value),
                                          fit: BoxFit.cover))),
                              Positioned(
                                  top: 2,
                                  right: 10,
                                  child: GestureDetector(
                                      onTap: () => setState(
                                          () => _existingUrls.removeAt(e.key)),
                                      child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                              color: AppTheme.error,
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.close,
                                              size: 12, color: Colors.white)))),
                            ])),
                    // Newly picked images (local)
                    ..._newImages.asMap().entries.map((e) =>
                        PickedImageThumbnail(
                            image: e.value,
                            onRemove: () =>
                                setState(() => _newImages.removeAt(e.key)))),
                    // Add more button
                    GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFE5E7EB))),
                            child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppTheme.primary))),
                  ])),
              const SizedBox(height: 24),
              Text.rich(
                TextSpan(
                  text: 'Land Title Deed  ',
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
              if (_newDeedImage != null)
                _DeedPreview(
                    child: Image.memory(_newDeedImage!.bytes,
                        fit: BoxFit.cover, width: double.infinity, height: 140),
                    onRemove: () => setState(() => _newDeedImage = null))
              else if (_existingDeedUrl != null && !_removeDeed)
                _DeedPreview(
                    child: Image.network(_existingDeedUrl!,
                        fit: BoxFit.cover, width: double.infinity, height: 140),
                    onRemove: () => setState(() => _removeDeed = true))
              else
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: _pickDeedFromGallery,
                          icon: const Icon(Icons.photo_library_outlined,
                              size: 18),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side:
                                  const BorderSide(color: AppTheme.primary)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: _pickDeedFromCamera,
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side:
                                  const BorderSide(color: AppTheme.primary)))),
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
                  onPressed: _isSubmitting ? null : _save,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Save Changes')),
              const SizedBox(height: 24),
            ])));
  }
}

class _DeedPreview extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _DeedPreview({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
          width: double.infinity,
          height: 140,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB))),
          child:
              ClipRRect(borderRadius: BorderRadius.circular(10), child: child)),
      Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
              onTap: onRemove,
              child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: AppTheme.error, shape: BoxShape.circle),
                  child:
                      const Icon(Icons.close, size: 14, color: Colors.white)))),
    ]);
  }
}
