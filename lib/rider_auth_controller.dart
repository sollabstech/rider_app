// lib/controllers/rider_auth_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════
//  Rider Model
// ═══════════════════════════════════════════════

class RiderModel {
  final String id;
  final String name;
  final String phone;
  final String bikeName;
  final String branchName;
  final String username;
  final String status;

  RiderModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.bikeName,
    required this.branchName,
    required this.username,
    required this.status,
  });

  factory RiderModel.fromMap(Map<String, dynamic> map) => RiderModel(
    id:          map['id']          ?? '',
    name:        map['name']        ?? '',
    phone:       map['phone']       ?? '',
    bikeName:    map['bikeName']    ?? '',
    branchName:  map['branchName']  ?? '',
    username:    map['username']    ?? '',
    status:      map['status']      ?? 'available',
  );
}

// ═══════════════════════════════════════════════
//  Auth Controller
// ═══════════════════════════════════════════════

class RiderAuthController extends GetxController {
  final _db = FirebaseFirestore.instance;

  // ── State ──────────────────────────────────────
  final Rx<RiderModel?> currentRider = Rx<RiderModel?>(null);
  final RxBool isLoggedIn   = false.obs;
  final RxBool isLoading    = false.obs;
  final RxBool showPassword = false.obs;

  // ── Form controllers ───────────────────────────
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  // SharedPreferences keys
  static const String _keyRiderId  = 'rider_id';
  static const String _keyUsername = 'rider_username';

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  @override
  void onClose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.onClose();
  }

  // ─────────────────────────────────────────────
  //  Auto-login — restore saved session
  // ─────────────────────────────────────────────

  Future<void> _restoreSession() async {
    isLoading.value = true;
    try {
      final prefs    = await SharedPreferences.getInstance();
      final savedId  = prefs.getString(_keyRiderId);

      if (savedId == null || savedId.isEmpty) {
        isLoading.value = false;
        return;
      }

      // Fetch fresh rider data
      final doc = await _db.collection('riders').doc(savedId).get();
      if (doc.exists && doc.data() != null) {
        currentRider.value = RiderModel.fromMap(doc.data()!);
        isLoggedIn.value   = true;
        Get.offAllNamed('/home');
      }
    } catch (e) {
      debugPrint('Session restore error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────
  //  Login
  //  1. Query Firestore riders where username matches
  //  2. Compare password field
  //  3. Save session on match
  // ─────────────────────────────────────────────

  Future<void> login() async {
    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _err('Please enter username and password');
      return;
    }

    isLoading.value = true;
    try {
      // Step 1: find rider by username
      final snap = await _db
          .collection('riders')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        _err('No rider found with this username');
        return;
      }

      final data = snap.docs.first.data();

      // Step 2: check password matches what admin saved
      if (data['password'] != password) {
        _err('Incorrect password. Please try again.');
        return;
      }

      // Step 3: build rider model and save session
      final rider = RiderModel.fromMap(data);
      currentRider.value = rider;
      isLoggedIn.value   = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRiderId,  rider.id);
      await prefs.setString(_keyUsername, rider.username);

      // Clear form fields
      usernameCtrl.clear();
      passwordCtrl.clear();

      Get.offAllNamed('/home');
    } catch (e) {
      _err('Login failed. Check your connection and try again.');
      debugPrint('Login error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────
  //  Logout
  // ─────────────────────────────────────────────

  Future<void> logout() async {
    try {
      // Mark rider offline in Firestore
      if (currentRider.value != null) {
        await _db
            .collection('riders')
            .doc(currentRider.value!.id)
            .update({'status': 'offline'});
      }
    } catch (e) {
      debugPrint('Logout Firestore update error: $e');
    }

    // Clear local session
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRiderId);
    await prefs.remove(_keyUsername);

    currentRider.value = null;
    isLoggedIn.value   = false;
    Get.offAllNamed('/login');
  }

  // ─────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────

  void _err(String msg) => Get.snackbar(
    'Error',
    msg,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: const Color(0xFFFF5252),
    colorText: Colors.white,
    margin: const EdgeInsets.all(16),
    borderRadius: 12,
    duration: const Duration(seconds: 4),
  );
}