import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_map.dart';
// استدعاء شاشة الـ Home للعودة إليها
import '../../screens/buyer/buyer_home_screen.dart';

class PremiumPinsScreen extends StatefulWidget {
  const PremiumPinsScreen({super.key});

  @override
  State<PremiumPinsScreen> createState() => _PremiumPinsScreenState();
}

class _PremiumPinsScreenState extends State<PremiumPinsScreen> {
  static const LatLng _amman = LatLng(31.9539, 35.9106);
  List<PremiumAlertPin> _pins = [];
  bool _isLoading = true;
  bool _isSaving = false;
  LatLng _mapCenter = _amman;

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  Future<void> _loadPins() async {
    setState(() => _isLoading = true);
    try {
      final pins = await PremiumService.instance.getMyPremiumPins();
      if (mounted) {
        setState(() {
          _pins = pins;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPremium() async {
    setState(() => _isSaving = true);
    try {
      await PremiumService.instance.requestPremiumSubscription();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Premium request sent to admin.'),
        backgroundColor: AppTheme.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _promptAddPin(LatLng point) async {
    final radiusController = TextEditingController(text: '5');
    final labelController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Premium Pin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Radius (km)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isSaving = true);
    try {
      await PremiumService.instance.upsertPremiumPin(
        latitude: point.latitude,
        longitude: point.longitude,
        radiusKm: double.tryParse(radiusController.text) ?? 5,
        label: labelController.text.trim().isEmpty
            ? null
            : labelController.text.trim(),
      );
      await _loadPins();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deletePin(PremiumAlertPin pin) async {
    await PremiumService.instance.deletePremiumPin(pin.id);
    await _loadPins();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: PremiumService.instance.watchCurrentUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isPremium = user?.isPremiumActive == true;
        final isPending = user?.isPremiumPending == true;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA), // لون خلفية مريح للعين
          appBar: AppBar(
            title: const Text('Premium Alert Pins'),
            // 1. إضافة زر العودة لصفحة Browse
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const BuyerHomeScreen()),
                );
              },
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : isPremium
                  ? Column(
                      children: [
                        // 1. شريط التقدم الأنيق لعداد الـ Pins (يبقى في الأعلى)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Used Pins',
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (_isSaving)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        ),
                                      Text(
                                        '${_pins.length} / 5',
                                        style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _pins.length / 5,
                                  backgroundColor:
                                      AppTheme.primary.withValues(alpha: 0.1),
                                  color: AppTheme.primary,
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 2. دمج الخريطة والقائمة معاً
                        Expanded(
                          child: Stack(
                            children: [
                              // الخريطة كخلفية ممتدة للأسفل
                              Positioned.fill(
                                child: AppMapView(
                                  center: _mapCenter,
                                  zoom: 11,
                                  onTap: (point) {
                                    if (_pins.length >= 5) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Maximum 5 pins reached')),
                                      );
                                      return;
                                    }
                                    _promptAddPin(point);
                                  },
                                  markers: _pins
                                      .map(
                                        (pin) => AppMapMarker(
                                          point: LatLng(
                                              pin.latitude, pin.longitude),
                                          child: const Icon(
                                            Icons.location_on,
                                            color: AppTheme.primary,
                                            size: 44,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),

                              // القائمة العائمة في الأسفل مع حواف دائرية
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height:
                                      200, // تم تصغير المساحة لتناسب الخريطة أكثر
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(
                                          24), // الحواف الدائرية العلوية
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 15,
                                        offset: const Offset(0,
                                            -4), // ظل خفيف للأعلى ليفصلها عن الخريطة
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // مؤشر سحب بصري (Drag Handle) ليعطي إحساس الـ BottomSheet
                                      Container(
                                        margin: const EdgeInsets.only(
                                            top: 12, bottom: 8),
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey
                                              .withValues(alpha: 0.3),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      // محتوى القائمة
                                      Expanded(
                                        child: ListView.separated(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 0, 16, 16),
                                          itemCount: _pins.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final pin = _pins[index];
                                            return InkWell(
                                              onTap: () => setState(
                                                () => _mapCenter = LatLng(
                                                    pin.latitude,
                                                    pin.longitude),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: AppTheme.primary
                                                        .withValues(
                                                            alpha: 0.05),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              10),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primary
                                                            .withValues(
                                                                alpha: 0.1),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .location_on_outlined,
                                                        color: AppTheme.primary,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            pin.label ??
                                                                'Pin ${index + 1}',
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16,
                                                              color: AppTheme
                                                                  .textDark,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            '${pin.latitude.toStringAsFixed(4)}, ${pin.longitude.toStringAsFixed(4)}',
                                                            style:
                                                                const TextStyle(
                                                              color: AppTheme
                                                                  .textMuted,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.red
                                                            .withValues(
                                                                alpha: 0.1),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color: Colors.red),
                                                        onPressed: () =>
                                                            _deletePin(pin),
                                                        tooltip: 'Delete Pin',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Center(
// ... باقي كود الشاشة في حالة عدم وجود اشتراك Premium
                      // ... (تم الإبقاء على كود حالة عدم وجود اشتراك Premium كما هو تماماً)
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.workspace_premium_outlined,
                              size: 64,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isPending
                                  ? 'Your premium request is pending admin approval.'
                                  : user?.subscriptionStatus == 'disabled'
                                      ? 'Your premium subscription is disabled.'
                                      : user?.subscriptionStatus == 'rejected'
                                          ? 'Your premium request was rejected.'
                                          : 'Premium buyers can save up to 5 alert pins on the map.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.textMuted),
                            ),
                            if (user?.subscriptionStatus == 'rejected' &&
                                (user?.subscriptionRejectReason?.isNotEmpty ??
                                    false)) ...[
                              const SizedBox(height: 10),
                              Text(
                                user!.subscriptionRejectReason!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (user?.subscriptionStatus == 'disabled' &&
                                (user?.subscriptionDisableReason?.isNotEmpty ??
                                    false)) ...[
                              const SizedBox(height: 10),
                              Text(
                                user!.subscriptionDisableReason!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: isPending || _isSaving
                                  ? null
                                  : _requestPremium,
                              child: Text(
                                isPending
                                    ? 'Pending Approval'
                                    : user?.subscriptionStatus == 'disabled'
                                        ? 'Request Review'
                                        : user?.subscriptionStatus == 'rejected'
                                            ? 'Request Again'
                                            : 'Request Premium',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }
}
