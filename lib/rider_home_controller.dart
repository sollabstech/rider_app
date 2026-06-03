// lib/controllers/rider_home_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'Rider_map_page.dart';
import 'rider_auth_controller.dart';

// ═══════════════════════════════════════════════
//  Order Model (Rider side)
// ═══════════════════════════════════════════════

class RiderOrder {
  final String id;
  final String clientName;
  final double totalAmount;
  final String doorNumber;
  final String streetName;
  final String areaName;
  final String city;
  final String state;
  final String status;
  final String assignMethod;

  RiderOrder({
    required this.id,
    required this.clientName,
    required this.totalAmount,
    required this.doorNumber,
    required this.streetName,
    required this.areaName,
    required this.city,
    required this.state,
    required this.status,
    this.assignMethod = 'manual',
  });

  /// Full delivery address string
  String get fullAddress =>
      '$doorNumber, $streetName, $areaName, $city, $state';

  /// URL-encoded address for map queries
  String get encodedAddress =>
      Uri.encodeComponent('$doorNumber $streetName $areaName $city $state');

  factory RiderOrder.fromMap(Map<String, dynamic> map) => RiderOrder(
    id:           map['id']           ?? '',
    clientName:   map['clientName']   ?? '',
    totalAmount:  (map['totalAmount'] ?? 0).toDouble(),
    doorNumber:   map['doorNumber']   ?? '',
    streetName:   map['streetName']   ?? '',
    areaName:     map['areaName']     ?? '',
    city:         map['city']         ?? '',
    state:        map['state']        ?? '',
    status:       map['status']       ?? 'picked',
    assignMethod: map['assignMethod'] ?? 'manual',
  );
}

// ═══════════════════════════════════════════════
//  Notification Model
// ═══════════════════════════════════════════════

class RiderNotification {
  final String id;
  final String orderId;
  final String type;
  final String message;
  final String address;
  final double amount;
  final bool seen;

  RiderNotification({
    required this.id,
    required this.orderId,
    required this.type,
    required this.message,
    required this.address,
    required this.amount,
    required this.seen,
  });

  factory RiderNotification.fromMap(
      String docId, Map<String, dynamic> map) =>
      RiderNotification(
        id:      docId,
        orderId: map['orderId'] ?? '',
        type:    map['type']    ?? '',
        message: map['message'] ?? '',
        address: map['address'] ?? '',
        amount:  (map['amount'] ?? 0).toDouble(),
        seen:    map['seen']    ?? false,
      );
}

// ═══════════════════════════════════════════════
//  GPS Permission State
// ═══════════════════════════════════════════════

enum GpsState {
  unknown,       // not yet checked
  checking,      // permission request in progress
  active,        // streaming live location
  serviceOff,    // device GPS turned off
  permDenied,    // user denied (can ask again)
  permForever,   // permanently denied — needs App Settings
}

// ═══════════════════════════════════════════════
//  Rider Home Controller
// ═══════════════════════════════════════════════

class RiderHomeController extends GetxController {
  final _db   = FirebaseFirestore.instance;
  final _auth = Get.find<RiderAuthController>();

  // ── Reactive State ─────────────────────────────
  final RxList<RiderOrder>        myOrders      = <RiderOrder>[].obs;
  final RxList<RiderNotification> notifications = <RiderNotification>[].obs;
  final Rx<Position?>             currentPos    = Rx<Position?>(null);

  final RxBool              isUpdating  = false.obs;
  final Rx<GpsState>        gpsState    = GpsState.unknown.obs;
  final RxString            riderStatus = 'available'.obs;

  // ── Internal ────────────────────────────────────
  final List<Function()>    _listeners  = [];
  StreamSubscription<Position>? _posStream;

  // ── Convenience getters ─────────────────────────
  String get riderId     => _auth.currentRider.value?.id ?? '';
  int    get unseenCount => notifications.where((n) => !n.seen).length;

  /// True only when GPS is actively streaming
  bool get gpsEnabled => gpsState.value == GpsState.active;

  @override
  void onInit() {
    super.onInit();
    if (riderId.isEmpty) return;
    _setOnline();
    _listenToMyOrders();
    _listenToNotifications();
    _initGps();
  }

  @override
  void onClose() {
    for (final cancel in _listeners) cancel();
    _posStream?.cancel();
    super.onClose();
  }

  // ─────────────────────────────────────────────
  //  Set online when app opens
  // ─────────────────────────────────────────────

  Future<void> _setOnline() async {
    try {
      final doc = await _db.collection('riders').doc(riderId).get();
      if (!doc.exists) return;
      final status = doc.data()?['status'] ?? 'available';
      riderStatus.value = status;
      if (status == 'offline') {
        await _db
            .collection('riders')
            .doc(riderId)
            .update({'status': 'available'});
        riderStatus.value = 'available';
      }
    } catch (e) {
      debugPrint('setOnline: $e');
    }
  }

  // ─────────────────────────────────────────────
  //  Real-time: orders assigned to this rider
  // ─────────────────────────────────────────────

  void _listenToMyOrders() {
    final sub = _db
        .collection('orders')
        .where('assignedBoyId', isEqualTo: riderId)
        .where('status', whereIn: ['picked'])
        .snapshots()
        .listen((snap) {
      myOrders.assignAll(
          snap.docs.map((d) => RiderOrder.fromMap(d.data())).toList());
    });
    _listeners.add(sub.cancel);
  }

  // ─────────────────────────────────────────────
  //  Real-time: notifications for this rider
  // ─────────────────────────────────────────────

  void _listenToNotifications() {
    final sub = _db
        .collection('notifications')
        .where('riderId', isEqualTo: riderId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      notifications.assignAll(snap.docs
          .map((d) => RiderNotification.fromMap(d.id, d.data()))
          .toList());
    });
    _listeners.add(sub.cancel);
  }

  // ─────────────────────────────────────────────
  //  GPS — Full permission flow + live stream
  // ─────────────────────────────────────────────

  /// Called on init and when user taps "retry" from UI.
  Future<void> _initGps() async {
    gpsState.value = GpsState.checking;

    // 1. Check if device location service is on
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      gpsState.value = GpsState.serviceOff;
      return;
    }

    // 2. Check / request permission
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      gpsState.value = GpsState.permForever;
      return;
    }
    if (perm == LocationPermission.denied) {
      gpsState.value = GpsState.permDenied;
      return;
    }

    // 3. Permission granted (whileInUse or always) — start live stream
    gpsState.value = GpsState.active;
    _startLocationStream();
  }

  /// Starts a live position stream and writes to Firestore on every update.
  /// Replaces the old 15-second timer approach.
  void _startLocationStream() {
    _posStream?.cancel(); // cancel any existing stream first

    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: 10, // metres — update only when rider moved ≥10m
      ),
    ).listen(
          (pos) async {
        currentPos.value = pos;
        try {
          await _db.collection('riders').doc(riderId).update({
            'latitude':  pos.latitude,
            'longitude': pos.longitude,
          });
        } catch (e) {
          debugPrint('GPS push: $e');
        }
      },
      onError: (e) {
        debugPrint('GPS stream error: $e');
        gpsState.value = GpsState.serviceOff;
        _posStream?.cancel();
      },
      cancelOnError: false,
    );
  }

  // ─────────────────────────────────────────────
  //  Public: retry GPS after user fixes setting
  //  Call this from UI when user taps "Retry"
  // ─────────────────────────────────────────────

  Future<void> retryGps() => _initGps();

  /// Opens device location settings (for serviceOff state)
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// Opens app settings (for permForever state)
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  // ─────────────────────────────────────────────
  //  Open Map — navigates to the in-app Google Maps
  //  directions page (RiderMapPage).
  // ─────────────────────────────────────────────

  void openMapToAddress(RiderOrder order) {
    Get.to(
          () => RiderMapPage(order: order),
      transition: Transition.downToUp,
      duration: const Duration(milliseconds: 350),
    );
  }

  // REPLACED — old external launcher kept for reference
  Future<void> _openMapExternalLEGACY(RiderOrder order) async {
    final dest = order.encodedAddress;

    final pos       = currentPos.value;
    final hasOrigin = pos != null;

    final List<Uri> candidates = [];

    if (hasOrigin) {
      final lat = pos.latitude;
      final lng = pos.longitude;
      candidates.add(Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
              '&origin=$lat,$lng'
              '&destination=$dest'
              '&travelmode=driving'));
      candidates.add(Uri.parse('geo:$lat,$lng?q=$dest'));
    } else {
      candidates.add(Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$dest'));
      candidates.add(Uri.parse(
          'https://www.openstreetmap.org/search?query=$dest'));
    }

    bool launched = false;
    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        }
      } catch (_) {}
    }

    if (!launched) {
      final osmUrl = Uri.parse(
          'https://www.openstreetmap.org/search?query=$dest');
      await launchUrl(osmUrl, mode: LaunchMode.externalApplication);
    }
  }

  // ─────────────────────────────────────────────
  //  Mark Order as Delivered
  // ─────────────────────────────────────────────

  Future<void> markDelivered(RiderOrder order) async {
    isUpdating.value = true;
    try {
      final batch = _db.batch();
      batch.update(_db.collection('orders').doc(order.id),
          {'status': 'delivered'});
      batch.update(_db.collection('riders').doc(riderId),
          {'status': 'available'});
      await batch.commit();

      myOrders.removeWhere((o) => o.id == order.id);
      riderStatus.value = 'available';
      _ok('Delivered! You are now available.');
    } catch (e) {
      _err('Failed to update. Try again.');
      debugPrint('markDelivered: $e');
    } finally {
      isUpdating.value = false;
    }
  }

  // ─────────────────────────────────────────────
  //  Mark notification seen
  // ─────────────────────────────────────────────

  Future<void> markNotificationSeen(String notifId) async {
    try {
      await _db
          .collection('notifications')
          .doc(notifId)
          .update({'seen': true});
    } catch (e) {
      debugPrint('markSeen: $e');
    }
  }

  // ─────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────

  void _err(String msg) => Get.snackbar('Error', msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFF5252),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 4));

  void _ok(String msg) => Get.snackbar('✅ Done', msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF00C853),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3));
}