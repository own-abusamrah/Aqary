import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:widget_to_marker/widget_to_marker.dart';
import '../config/app_map_settings.dart';
import '../utils/app_theme.dart';

// ==========================================
// 1. كلاس تصميم الـ Pin الحديث (مستطيل مع بروز) لعرض الأسعار
// ==========================================
class ModernPriceMarker extends StatelessWidget {
  final String title;

  const ModernPriceMarker({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // المستطيل الذي يحتوي على السعر
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(4), // زوايا شبه حادة (رقم صغير)
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // البروز (المثلث) في الأسفل
        CustomPaint(
          size: const Size(16, 10),
          painter: _TrianglePainter(color: AppTheme.primary),
        ),
      ],
    );
  }
}

// ==========================================
// 2. كلاس تصميم الـ Pin المخصص للموقع المحدد (Selected)
// ==========================================
class SelectedLocationPin extends StatelessWidget {
  const SelectedLocationPin({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary, 
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
        CustomPaint(
          size: const Size(16, 10),
          painter: _TrianglePainter(color: AppTheme.primary),
        ),
      ],
    );
  }
}

// أداة رسم المثلث السفلي المشتركة للدبابيس
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0); // الزاوية العلوية اليسرى للمثلث
    path.lineTo(size.width / 2, size.height); // الرأس السفلي
    path.lineTo(size.width, 0); // الزاوية العلوية اليمنى
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// 3. الكلاسات الأساسية للخريطة
// ==========================================
class AppMapMarker {
  final LatLng point;
  final Widget? child;
  final String? title;
  final VoidCallback? onTap;

  const AppMapMarker({
    required this.point,
    this.child,
    this.title,
    this.onTap,
  });

  // لمنع إعادة بناء الـ Markers بدون داعٍ وتحسين الأداء
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppMapMarker &&
          runtimeType == other.runtimeType &&
          point == other.point &&
          title == other.title;

  @override
  int get hashCode => point.hashCode ^ title.hashCode;
}

class AppMapView extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final List<AppMapMarker> markers;
  final void Function(LatLng point)? onTap;
  final bool interactive;

  const AppMapView({
    super.key,
    required this.center,
    required this.zoom,
    this.markers = const [],
    this.onTap,
    this.interactive = true,
  });

  @override
  State<AppMapView> createState() => _AppMapViewState();
}

class _AppMapViewState extends State<AppMapView> {
  final MapController _osmController = MapController();
  gmaps.GoogleMapController? _googleController;

  Set<gmaps.Marker> _googleMarkers = {};

  @override
  void initState() {
    super.initState();
    if (AppMapSettings.useGoogleMaps) {
      _buildGoogleMarkers();
    }
  }

  Future<void> _buildGoogleMarkers() async {
    final futureMarkers = widget.markers.map((marker) async {
      
      // هنا المعالجة الذكية: إذا لم يمرر الـ child وكان العنوان فارغاً، يتم عرض SelectedLocationPin تلقائياً
      final iconWidget = marker.child ?? 
          ((marker.title == null || marker.title!.isEmpty)
              ? const SelectedLocationPin()
              : ModernPriceMarker(title: marker.title!));
              
      final icon = await iconWidget.toBitmapDescriptor();

      return gmaps.Marker(
        markerId: gmaps.MarkerId(
          '${marker.point.latitude}_${marker.point.longitude}_${marker.title ?? ''}',
        ),
        position: gmaps.LatLng(
          marker.point.latitude,
          marker.point.longitude,
        ),
        icon: icon,
        onTap: marker.onTap,
      );
    }).toList();

    final resolvedMarkers = await Future.wait(futureMarkers);

    if (mounted) {
      setState(() {
        _googleMarkers = resolvedMarkers.toSet();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AppMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (AppMapSettings.useGoogleMaps && !listEquals(oldWidget.markers, widget.markers)) {
      _buildGoogleMarkers();
    }

    final centerChanged = oldWidget.center != widget.center;
    final zoomChanged = oldWidget.zoom != widget.zoom;
    if (!centerChanged && !zoomChanged) return;

    if (AppMapSettings.useOpenStreetMap) {
      _osmController.move(widget.center, widget.zoom);
    } else {
      _googleController?.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: gmaps.LatLng(widget.center.latitude, widget.center.longitude),
            zoom: widget.zoom,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _googleController?.dispose();
    _osmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMapSettings.useGoogleMaps) {
      return gmaps.GoogleMap(
        initialCameraPosition: gmaps.CameraPosition(
          target: gmaps.LatLng(widget.center.latitude, widget.center.longitude),
          zoom: widget.zoom,
        ),
        onMapCreated: (controller) => _googleController = controller,
        onTap: widget.onTap == null
            ? null
            : (point) => widget.onTap!(LatLng(point.latitude, point.longitude)),
        zoomControlsEnabled: false,
        zoomGesturesEnabled: widget.interactive,
        scrollGesturesEnabled: widget.interactive,
        rotateGesturesEnabled: widget.interactive,
        tiltGesturesEnabled: widget.interactive,
        markers: _googleMarkers,
      );
    }

    return FlutterMap(
      mapController: _osmController,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        onTap: widget.onTap == null ? null : (_, point) => widget.onTap!(point),
        interactionOptions: InteractionOptions(
          flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.aqary.app',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: widget.markers.map((marker) {
            return Marker(
              point: marker.point,
              width: 140, // تم تكبير العرض ليستوعب الأسعار الكبيرة والـ Selected Pin
              height: 60, // تم تكبير الارتفاع ليستوعب المستطيل والمثلث والظلال
              alignment: Alignment.topCenter, // لجعل رأس المثلث يؤشر على النقطة بالضبط
              child: GestureDetector(
                onTap: marker.onTap,
                // تطبيق نفس المنطق الذكي هنا لخرائط OpenStreetMap
                child: marker.child ?? 
                    ((marker.title == null || marker.title!.isEmpty)
                        ? const SelectedLocationPin()
                        : ModernPriceMarker(title: marker.title!)),
              ),
            );
          }).toList(),
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors', onTap: null),
          ],
        ),
      ],
    );
  }
}