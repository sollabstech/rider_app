import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'rider_home_controller.dart';

// ═══════════════════════════════════════════════
//  Logger Utility
// ═══════════════════════════════════════════════

enum _LogLevel { debug, info, warn, error }

class MapLogger {
  const MapLogger._();

  static const String _tag = '[RiderMap]';

  // Coloured emoji prefix per level
  static const Map<_LogLevel, String> _prefix = {
    _LogLevel.debug: '🔍 DEBUG',
    _LogLevel.info:  'ℹ️  INFO ',
    _LogLevel.warn:  '⚠️  WARN ',
    _LogLevel.error: '🔴 ERROR',
  };

  // ── Public helpers ─────────────────────────────
  static void d(String section, String msg) =>
      _log(_LogLevel.debug, section, msg);

  static void i(String section, String msg) =>
      _log(_LogLevel.info, section, msg);

  static void w(String section, String msg) =>
      _log(_LogLevel.warn, section, msg);

  static void e(String section, String msg, [Object? error, StackTrace? stack]) {
    _log(_LogLevel.error, section, msg);
    if (error != null) debugPrint('   ↳ Exception : $error');
    if (stack != null) debugPrint('   ↳ Stack     :\n$stack');
  }

  // ── Internal ───────────────────────────────────
  static void _log(_LogLevel level, String section, String msg) {
    // In release mode only show warn / error
    if (!kDebugMode && level.index < _LogLevel.warn.index) return;
    final time = DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.mmm
    debugPrint('${_prefix[level]} $_tag [$section] $time → $msg');
  }

  // ── Divider helpers ────────────────────────────
  static void section(String title) {
    if (!kDebugMode) return;
    debugPrint('');
    debugPrint('━━━━━━━━━━━━━━━━  $title  ━━━━━━━━━━━━━━━━');
  }
}

// ═══════════════════════════════════════════════

class RiderMapPage extends StatelessWidget {
  const RiderMapPage({super.key, required this.order});
  final RiderOrder order;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_RiderMapController>(
      init: _RiderMapController(order: order),
      builder: (c) => _RiderMapView(c: c, order: order),
    );
  }
}

// ═══════════════════════════════════════════════
//  Permission / load state
// ═══════════════════════════════════════════════

enum _LocState {
  loading,      // checking / requesting
  gpsOff,       // device location service disabled
  permDenied,   // user tapped Deny (can ask again)
  permForever,  // permanently denied — need App Settings
  geocodeFail,  // could not resolve address
  ready,        // map + route loaded
}

// ═══════════════════════════════════════════════
//  Internal Controller (scoped to this page)
// ═══════════════════════════════════════════════

class _RiderMapController extends GetxController {
  _RiderMapController({required this.order});

  final RiderOrder order;

  // ── Replace with your real key ──────────────
  static const String _apiKey = 'AIzaSyAGinxO6zr27-S828Jk7haDLEvT-WmuU6Y';

  // ── State ───────────────────────────────────
  GoogleMapController? mapController;
  LatLng? riderPos;
  LatLng? destPos;

  final Rx<_LocState> state        = _LocState.loading.obs;
  final RxString      distanceText = '—'.obs;
  final RxString      durationText = '—'.obs;

  Set<Marker>   markers   = {};
  Set<Polyline> polylines = {};

  @override
  void onInit() {
    super.onInit();
    MapLogger.section('RiderMapController INIT');
    MapLogger.i('Lifecycle', 'onInit — order: ${order.clientName} | addr: ${order.fullAddress}');
    _init();
  }

  @override
  void onClose() {
    MapLogger.i('Lifecycle', 'onClose — disposing map controller');
    mapController?.dispose();
    super.onClose();
  }

  // ─────────────────────────────────────────────
  //  Main init — runs on open and on retry
  // ─────────────────────────────────────────────

  Future<void> _init() async {
    MapLogger.section('_init');
    state.value = _LocState.loading;

    // 1. Check GPS service
    MapLogger.d('Init', 'Checking location service…');
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      MapLogger.w('Init', 'GPS service is OFF → showing gpsOff screen');
      state.value = _LocState.gpsOff;
      return;
    }
    MapLogger.i('Init', 'GPS service is ON');

    // 2. Check / request permission
    var perm = await Geolocator.checkPermission();
    MapLogger.d('Permission', 'Current permission: $perm');

    if (perm == LocationPermission.denied) {
      MapLogger.i('Permission', 'Denied — requesting from user…');
      perm = await Geolocator.requestPermission();
      MapLogger.i('Permission', 'User response: $perm');
    }
    if (perm == LocationPermission.deniedForever) {
      MapLogger.w('Permission', 'Permanently denied → showing permForever screen');
      state.value = _LocState.permForever;
      return;
    }
    if (perm == LocationPermission.denied) {
      MapLogger.w('Permission', 'Denied again → showing permDenied screen');
      state.value = _LocState.permDenied;
      return;
    }
    MapLogger.i('Permission', 'Permission granted: $perm');

    // 3. Get actual GPS position
    MapLogger.d('GPS', 'Fetching current position…');
    final pos = await _getPosition();
    if (pos == null) {
      MapLogger.e('GPS', 'Could not get position → showing gpsOff screen');
      state.value = _LocState.gpsOff;
      return;
    }
    riderPos = LatLng(pos.latitude, pos.longitude);
    MapLogger.i('GPS', 'Position acquired → lat: ${pos.latitude}, lng: ${pos.longitude} '
        '| accuracy: ${pos.accuracy.toStringAsFixed(1)} m');

    // 4. Geocode delivery address
    MapLogger.d('Geocode', 'Geocoding address: "${order.fullAddress}"');
    final dest = await _geocodeAddress(order.fullAddress);
    if (dest == null) {
      MapLogger.e('Geocode', 'Geocoding failed → showing geocodeFail screen');
      state.value = _LocState.geocodeFail;
      return;
    }
    destPos = dest;
    MapLogger.i('Geocode', 'Destination resolved → lat: ${dest.latitude}, lng: ${dest.longitude}');

    // 5. Build markers + fetch route
    MapLogger.d('Init', 'Building markers…');
    _buildMarkers();

    MapLogger.d('Init', 'Fetching route…');
    await _fetchRoute();

    state.value = _LocState.ready;
    MapLogger.i('Init', '✅ Map ready — distance: ${distanceText.value}, ETA: ${durationText.value}');
    update();

    await Future.delayed(const Duration(milliseconds: 400));
    _fitBounds();
  }

  // ─────────────────────────────────────────────
  //  GPS position fetch
  // ─────────────────────────────────────────────

  Future<Position?> _getPosition() async {
    // 1️⃣ Try last known position first (instant, no GPS lock needed)
    try {
      MapLogger.d('GPS', 'Trying getLastKnownPosition…');
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final age = DateTime.now().difference(last.timestamp);
        MapLogger.i('GPS', 'Last known position age: ${age.inSeconds}s');
        if (age.inMinutes < 5) {
          MapLogger.i('GPS', 'Using last known position (fresh enough)');
          return last;
        }
      }
    } catch (e) {
      MapLogger.w('GPS', 'getLastKnownPosition failed: $e');
    }

    // 2️⃣ Try medium accuracy (faster lock, works indoors)
    try {
      MapLogger.d('GPS', 'Trying medium accuracy (8s timeout)…');
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      MapLogger.w('GPS', 'Medium accuracy failed: $e');
    }

    // 3️⃣ Try lowest accuracy as last resort
    try {
      MapLogger.d('GPS', 'Trying low accuracy (6s timeout)…');
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.lowest,
        timeLimit: const Duration(seconds: 6),
      );
    } catch (e) {
      MapLogger.e('GPS', 'All position strategies failed', e);
    }

    return null;
  }
  // ─────────────────────────────────────────────
  //  Geocoding — address → LatLng
  // ─────────────────────────────────────────────

  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
            '?address=${Uri.encodeComponent(address)}'
            '&key=$_apiKey',
      );
      MapLogger.d('Geocode', 'GET $url');

      final res = await http.get(url);
      MapLogger.d('Geocode', 'HTTP ${res.statusCode} — body length: ${res.body.length} chars');

      final json = jsonDecode(res.body);
      final status = json['status'] as String?;
      MapLogger.d('Geocode', 'API status: $status');

      if (status != 'OK') {
        final errMsg = json['error_message'] ?? 'no error_message field';
        MapLogger.e('Geocode', 'Non-OK status "$status" — $errMsg');
        return null;
      }

      final loc = json['results'][0]['geometry']['location'];
      final lat  = (loc['lat'] as num).toDouble();
      final lng  = (loc['lng'] as num).toDouble();
      MapLogger.i('Geocode', 'Resolved → ($lat, $lng)');
      return LatLng(lat, lng);

    } catch (e, s) {
      MapLogger.e('Geocode', 'Exception during geocoding', e, s);
      return null;
    }
  }

  // ─────────────────────────────────────────────
  //  Markers
  // ─────────────────────────────────────────────

  void _buildMarkers() {
    markers = {
      Marker(
        markerId: const MarkerId('rider'),
        position: riderPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: order.clientName,
          snippet: order.fullAddress,
        ),
      ),
    };
    MapLogger.d('Markers', '${markers.length} markers built');
  }

  // ─────────────────────────────────────────────
  //  Directions API — route + polyline
  // ─────────────────────────────────────────────

  Future<void> _fetchRoute() async {
    if (riderPos == null || destPos == null) {
      MapLogger.w('Route', '_fetchRoute called before positions are set — skipping');
      return;
    }
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=${riderPos!.latitude},${riderPos!.longitude}'
            '&destination=${destPos!.latitude},${destPos!.longitude}'
            '&mode=driving'
            '&key=$_apiKey',
      );
      MapLogger.d('Route', 'GET $url');

      final res  = await http.get(url);
      MapLogger.d('Route', 'HTTP ${res.statusCode}');

      final json = jsonDecode(res.body);
      final status = json['status'] as String?;
      MapLogger.d('Route', 'API status: $status');

      if (status != 'OK') {
        MapLogger.w('Route', 'Non-OK status "$status" — route will not be drawn');
        return;
      }

      final route = json['routes'][0];
      final leg   = route['legs'][0];
      distanceText.value = leg['distance']['text'] as String;
      durationText.value = leg['duration']['text'] as String;
      MapLogger.i('Route', 'Route fetched — distance: ${distanceText.value}, '
          'ETA: ${durationText.value}');

      final encoded = route['overview_polyline']['points'] as String;
      final points  = _decodePolyline(encoded);
      MapLogger.d('Route', 'Polyline decoded — ${points.length} points');

      polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: const Color(0xFF4361EE),
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(8)],
        ),
      };
    } catch (e, s) {
      MapLogger.e('Route', 'Exception during route fetch', e, s);
    }
  }

  // ─────────────────────────────────────────────
  //  Google polyline decoder
  // ─────────────────────────────────────────────

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> pts = [];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      pts.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }

  // ─────────────────────────────────────────────
  //  Camera
  // ─────────────────────────────────────────────

  void _fitBounds() {
    if (mapController == null || riderPos == null || destPos == null) {
      MapLogger.w('Camera', '_fitBounds skipped — controller or positions not ready');
      return;
    }
    final sw = LatLng(
      riderPos!.latitude  < destPos!.latitude  ? riderPos!.latitude  : destPos!.latitude,
      riderPos!.longitude < destPos!.longitude ? riderPos!.longitude : destPos!.longitude,
    );
    final ne = LatLng(
      riderPos!.latitude  > destPos!.latitude  ? riderPos!.latitude  : destPos!.latitude,
      riderPos!.longitude > destPos!.longitude ? riderPos!.longitude : destPos!.longitude,
    );
    MapLogger.d('Camera', 'fitBounds → SW: (${sw.latitude}, ${sw.longitude}) '
        'NE: (${ne.latitude}, ${ne.longitude})');
    mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 80));
  }

  void recenterOnRider() {
    if (mapController == null || riderPos == null) {
      MapLogger.w('Camera', 'recenterOnRider skipped — not ready');
      return;
    }
    MapLogger.d('Camera', 'Recentering on rider at ${riderPos!.latitude}, ${riderPos!.longitude}');
    mapController!.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: riderPos!, zoom: 16)));
  }

  // ─────────────────────────────────────────────
  //  UI action handlers
  // ─────────────────────────────────────────────

  Future<void> openLocationSettings() {
    MapLogger.i('Action', 'User tapped → openLocationSettings');
    return Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() {
    MapLogger.i('Action', 'User tapped → openAppSettings');
    return Geolocator.openAppSettings();
  }

  Future<void> requestAgain() {
    MapLogger.i('Action', 'User tapped → requestAgain');
    return _init();
  }

  void retry() {
    MapLogger.i('Action', 'User tapped → retry');
    _init();
  }
}

// ═══════════════════════════════════════════════
//  View
// ═══════════════════════════════════════════════

class _RiderMapView extends StatelessWidget {
  const _RiderMapView({required this.c, required this.order});

  final _RiderMapController c;
  final RiderOrder           order;

  static const Color _primary  = Color(0xFF4361EE);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF8A8FA8);
  static const Color _green    = Color(0xFF00C853);
  static const Color _orange   = Color(0xFFFF9800);
  static const Color _red      = Color(0xFFFF5252);
  static const Color _bg       = Color(0xFFF6F7FB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Obx(() => _bodyForState(c.state.value)),
          _topBar(context),
          Obx(() => c.state.value == _LocState.ready
              ? _bottomStrip()
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Route to screen by state
  // ─────────────────────────────────────────────

  Widget _bodyForState(_LocState s) {
    switch (s) {
      case _LocState.loading:
        return _loadingView();

      case _LocState.gpsOff:
        return _permScreen(
          icon: Icons.gps_off_rounded,
          iconColor: _orange,
          title: 'Location Services Off',
          body: 'Your device\'s location is disabled.\n'
              'Turn it on so we can show your position on the map\n'
              'and draw the delivery route.',
          primaryLabel: 'Open Location Settings',
          primaryIcon: Icons.settings_rounded,
          onPrimary: c.openLocationSettings,
          secondaryLabel: 'Go back',
          onSecondary: Get.back,
        );

      case _LocState.permDenied:
        return _permScreen(
          icon: Icons.location_off_rounded,
          iconColor: _red,
          title: 'Location Access Needed',
          body: 'We need your location to show where you are\n'
              'and draw the route to the customer\'s address.\n\n'
              'Please allow location access when prompted.',
          primaryLabel: 'Grant Permission',
          primaryIcon: Icons.location_on_rounded,
          onPrimary: c.requestAgain,
          secondaryLabel: 'Not now',
          onSecondary: Get.back,
        );

      case _LocState.permForever:
        return _permScreen(
          icon: Icons.lock_outline_rounded,
          iconColor: _red,
          title: 'Permission Blocked',
          body: 'Location permission was permanently denied.\n'
              'Please open App Settings and allow location\n'
              'access for this app.',
          primaryLabel: 'Open App Settings',
          primaryIcon: Icons.settings_applications_rounded,
          onPrimary: c.openAppSettings,
          secondaryLabel: 'Go back',
          onSecondary: Get.back,
          note: 'Settings → Apps → [App] → Permissions → Location → Allow',
        );

      case _LocState.geocodeFail:
        return _permScreen(
          icon: Icons.wrong_location_rounded,
          iconColor: _orange,
          title: 'Address Not Found',
          body: 'Could not locate the delivery address on the map.\n'
              'Check your internet connection and try again.',
          primaryLabel: 'Retry',
          primaryIcon: Icons.refresh_rounded,
          onPrimary: c.retry,
          secondaryLabel: 'Go back',
          onSecondary: Get.back,
        );

      case _LocState.ready:
        return _mapView();
    }
  }

  // ─────────────────────────────────────────────
  //  Loading screen
  // ─────────────────────────────────────────────

  Widget _loadingView() => Container(
    color: _bg,
    child: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primary),
          SizedBox(height: 16),
          Text('Getting your location…',
              style: TextStyle(
                  color: _textGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );

  // ─────────────────────────────────────────────
  //  Reusable permission / error screen
  // ─────────────────────────────────────────────

  Widget _permScreen({
    required IconData     icon,
    required Color        iconColor,
    required String       title,
    required String       body,
    required String       primaryLabel,
    required IconData     primaryIcon,
    required VoidCallback onPrimary,
    required String       secondaryLabel,
    required VoidCallback onSecondary,
    String? note,
  }) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withOpacity(0.25), width: 2),
            ),
            child: Icon(icon, size: 50, color: iconColor),
          ),
          const SizedBox(height: 26),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: _textDark, height: 1.3)),
          const SizedBox(height: 12),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13.5, color: _textGrey, height: 1.7)),
          const SizedBox(height: 34),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: onPrimary,
              icon: Icon(primaryIcon, color: Colors.white, size: 20),
              label: Text(primaryLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary, elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: OutlinedButton(
              onPressed: onSecondary,
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDDE0EF), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: Text(secondaryLabel,
                  style: const TextStyle(
                      color: _textDark,
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _orange.withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: _orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(note,
                        style: const TextStyle(
                            fontSize: 12, color: _orange, height: 1.55)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Google Map widget
  // ─────────────────────────────────────────────

  Widget _mapView() {
    final initial = c.riderPos ?? const LatLng(20.5937, 78.9629);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initial, zoom: 14),
      myLocationEnabled:       true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled:     false,
      markers:   c.markers,
      polylines: c.polylines,
      onMapCreated: (ctrl) {
        MapLogger.i('Map', 'GoogleMap created — fitting bounds');
        c.mapController = ctrl;
        c._fitBounds();
      },
    );
  }

  // ─────────────────────────────────────────────
  //  Top bar
  // ─────────────────────────────────────────────

  Widget _topBar(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 12, left: 8, right: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4361EE), Color(0xFF3A0CA3)],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: Get.back,
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.clientName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(order.fullAddress,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75), fontSize: 11)),
                ],
              ),
            ),
            Obx(() => c.state.value == _LocState.ready
                ? IconButton(
              onPressed: c.recenterOnRider,
              icon: const Icon(Icons.my_location_rounded,
                  color: Colors.white, size: 22),
              tooltip: 'My Location',
            )
                : const SizedBox(width: 48)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Bottom strip
  // ─────────────────────────────────────────────

  Widget _bottomStrip() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4)),
            ),
            Obx(() => Row(
              children: [
                _infoChip(Icons.straighten_rounded, 'Distance',
                    c.distanceText.value, _primary),
                const SizedBox(width: 12),
                _infoChip(Icons.timer_outlined, 'ETA',
                    c.durationText.value, _green),
              ],
            )),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8EAF0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: _red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(order.fullAddress,
                        style: const TextStyle(
                            fontSize: 12, color: _textDark,
                            fontWeight: FontWeight.w500, height: 1.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10, color: color.withOpacity(0.7),
                        fontWeight: FontWeight.w600)),
                Text(value,
                    style: TextStyle(
                        fontSize: 16, color: color,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}