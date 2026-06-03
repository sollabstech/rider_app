// lib/pages/rider_home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:rider/rider_auth_controller.dart';
import 'package:rider/rider_home_controller.dart';

class RiderHomePage extends StatelessWidget {
  const RiderHomePage({super.key});

  static const Color _primary  = Color(0xFF4361EE);
  static const Color _accent   = Color(0xFF3A0CA3);
  static const Color _bg       = Color(0xFFF6F7FB);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF8A8FA8);
  static const Color _green    = Color(0xFF00C853);
  static const Color _orange   = Color(0xFFFF9800);
  static const Color _teal     = Color(0xFF00BCD4);
  static const Color _red      = Color(0xFFFF5252);
  static const Color _mapColor = Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    final auth  = Get.find<RiderAuthController>();
    final c     = Get.put(RiderHomeController());
    final rider = auth.currentRider.value!;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [

          // ── AppBar ──────────────────────────────────────
          SliverAppBar(
            backgroundColor: _primary,
            expandedHeight: 170,
            pinned: true,
            automaticallyImplyLeading: false,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            actions: [
              // Notification bell with unseen badge
              Obx(() => Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                        Icons.notifications_rounded,
                        color: Colors.white),
                    onPressed: () => _showNotifSheet(c),
                  ),
                  if (c.unseenCount > 0)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        width: 17, height: 17,
                        decoration: const BoxDecoration(
                            color: _red,
                            shape: BoxShape.circle),
                        child: Center(
                          child: Text('${c.unseenCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight:
                                  FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              )),
              // Logout
              IconButton(
                icon: const Icon(Icons.logout_rounded,
                    color: Colors.white),
                onPressed: () => _confirmLogout(auth),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4361EE), Color(0xFF3A0CA3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 80, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor:
                              Colors.white.withOpacity(0.2),
                              child: Text(
                                rider.name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hi, ${rider.name.split(' ').first}!',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${rider.bikeName}  ·  ${rider.branchName}',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withOpacity(0.75),
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Obx(() =>
                                _statusBadge(c.riderStatus.value)),
                            const SizedBox(width: 10),
                            Obx(() => _gpsBadge(c.gpsEnabled)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Quick Stats ─────────────────────────────
                Obx(() => Row(
                  children: [
                    _statCard(
                      icon: Icons.receipt_long_rounded,
                      label: 'Active\nOrders',
                      value: '${c.myOrders.length}',
                      color: _teal,
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      icon: Icons.notifications_rounded,
                      label: 'Unseen\nAlerts',
                      value: '${c.unseenCount}',
                      color: _orange,
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      icon: Icons.gps_fixed_rounded,
                      label: 'GPS\nStatus',
                      value: c.gpsEnabled ? 'ON' : 'OFF',
                      color: c.gpsEnabled
                          ? _green
                          : Colors.grey,
                    ),
                  ],
                )),

                const SizedBox(height: 28),

                // ── Active Orders heading ───────────────────
                const Text('My Active Orders',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textDark)),
                const SizedBox(height: 12),

                Obx(() {
                  if (c.myOrders.isEmpty) {
                    return _emptyOrders();
                  }
                  return Column(
                    children: c.myOrders
                        .map((o) => _orderCard(o, c))
                        .toList(),
                  );
                }),

                const SizedBox(height: 28),

                // ── Recent Notifications ────────────────────
                Row(
                  children: [
                    const Text('Recent Notifications',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textDark)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showNotifSheet(c),
                      child: const Text('See all',
                          style: TextStyle(
                              fontSize: 12,
                              color: _primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Obx(() {
                  final recent = c.notifications.take(4).toList();
                  if (recent.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: const Center(
                        child: Text('No notifications yet',
                            style: TextStyle(color: _textGrey)),
                      ),
                    );
                  }
                  return Column(
                    children: recent
                        .map((n) => _notifTile(n, c))
                        .toList(),
                  );
                }),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Order Card — with client info, address,
  //  [View Map] and [Mark as Delivered] buttons
  // ─────────────────────────────────────────────

  Widget _orderCard(RiderOrder order, RiderHomeController c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _teal.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
              color: _teal.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [

          // ── Header: client + amount ─────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: _teal, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client name
                      Text(order.clientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: _textDark)),
                      const SizedBox(height: 3),
                      // Amount
                      Text(
                        '₹${order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 14,
                            color: _green,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                // Assign method badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: order.assignMethod == 'auto'
                        ? _teal.withOpacity(0.15)
                        : _primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        order.assignMethod == 'auto'
                            ? Icons.gps_fixed_rounded
                            : Icons.person_pin_rounded,
                        size: 11,
                        color: order.assignMethod == 'auto'
                            ? _teal : _primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        order.assignMethod == 'auto'
                            ? 'Auto GPS' : 'Manual',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: order.assignMethod == 'auto'
                                ? _teal : _primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Delivery Address ─────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EAF0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _mapColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: _mapColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Delivery Address',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _textGrey)),
                      const SizedBox(height: 4),
                      Text(
                        order.fullAddress,
                        style: const TextStyle(
                            fontSize: 13,
                            color: _textDark,
                            fontWeight: FontWeight.w500,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── GPS status strip ─────────────────────────
          Obx(() {
            final pos = c.currentPos.value;
            if (pos == null) return const SizedBox(height: 8);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded,
                      size: 13, color: _green),
                  const SizedBox(width: 5),
                  Text(
                    'Your location: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: _green,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 14),

          // ── Action Buttons ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [

                // Button 1: View on Map
                Expanded(
                  child: GestureDetector(
                    onTap: () => c.openMapToAddress(order),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: _mapColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _mapColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text('View on Map',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              Text('Open directions',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Button 2: Mark as Delivered
                Expanded(
                  child: Obx(() => GestureDetector(
                    onTap: c.isUpdating.value
                        ? null
                        : () => _confirmDeliver(order, c),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: c.isUpdating.value
                            ? _green.withOpacity(0.5)
                            : _green,
                        borderRadius:
                        BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          c.isUpdating.value
                              ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                              CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5))
                              : const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.white,
                              size: 20),
                          const SizedBox(width: 8),
                          const Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text('Delivered',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                      FontWeight.w700,
                                      fontSize: 13)),
                              Text('Mark as done',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Notification Tile
  // ─────────────────────────────────────────────

  Widget _notifTile(
      RiderNotification n, RiderHomeController c) {
    final isNew    = !n.seen;
    final isAssign = n.type == 'assigned' || n.type == 'auto_assigned';

    return GestureDetector(
      onTap: () { if (isNew) c.markNotificationSeen(n.id); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isNew
              ? _primary.withOpacity(0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isNew
                ? _primary.withOpacity(0.2)
                : const Color(0xFFE8EAF0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: isAssign
                    ? _teal.withOpacity(0.12)
                    : _orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isAssign
                    ? Icons.delivery_dining_rounded
                    : Icons.campaign_rounded,
                color: isAssign ? _teal : _orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.message,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isNew
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    '₹${n.amount.toStringAsFixed(0)}  ·  ${n.address}',
                    style: const TextStyle(
                        fontSize: 11, color: _textGrey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isNew)
              Container(
                width: 9, height: 9,
                margin: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                    color: _primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Dialogs & Sheets
  // ─────────────────────────────────────────────

  void _confirmDeliver(
      RiderOrder order, RiderHomeController c) {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22)),
      title: const Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: _green, size: 26),
          SizedBox(width: 10),
          Text('Confirm Delivery',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      content: Text(
        'Mark order for "${order.clientName}" as delivered?\n\nYour status will reset to Available.',
        style: const TextStyle(
            color: _textGrey, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
            onPressed: Get.back,
            child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: () { Get.back(); c.markDelivered(order); },
          style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.check_rounded,
              color: Colors.white, size: 18),
          label: const Text('Delivered',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  void _showNotifSheet(RiderHomeController c) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.notifications_rounded,
                    color: _primary, size: 22),
                SizedBox(width: 10),
                Text('All Notifications',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textDark)),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            Obx(() {
              if (c.notifications.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_off_rounded,
                            size: 44, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('No notifications yet',
                            style: TextStyle(
                                color: _textGrey,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }
              return ConstrainedBox(
                constraints:
                const BoxConstraints(maxHeight: 420),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: c.notifications.length,
                  itemBuilder: (_, i) =>
                      _notifTile(c.notifications[i], c),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _confirmLogout(RiderAuthController auth) {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22)),
      title: const Row(
        children: [
          Icon(Icons.logout_rounded, color: _red, size: 24),
          SizedBox(width: 10),
          Text('Log Out',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      content: const Text(
        'You will be marked as Offline.\nAre you sure?',
        style: TextStyle(
            color: _textGrey, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
            onPressed: Get.back,
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { Get.back(); auth.logout(); },
          style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text('Log Out',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  // ─────────────────────────────────────────────
  //  Helper Widgets
  // ─────────────────────────────────────────────

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'busy':    color = _orange; label = '🚴  On Delivery'; break;
      case 'offline': color = Colors.grey; label = '⚫  Offline'; break;
      default:        color = _green;  label = '🟢  Available';
    }
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _gpsBadge(bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? _green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: enabled
                ? _green.withOpacity(0.4)
                : Colors.grey.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled
                ? Icons.gps_fixed_rounded
                : Icons.gps_off_rounded,
            size: 13,
            color: enabled ? _green : Colors.grey,
          ),
          const SizedBox(width: 5),
          Text(
            enabled ? 'GPS Live' : 'GPS Off',
            style: TextStyle(
                color: enabled ? _green : Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: _textGrey)),
          ],
        ),
      ),
    );
  }

  Widget _emptyOrders() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_rounded, size: 54, color: Colors.grey),
          SizedBox(height: 12),
          Text('No active orders right now',
              style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
          SizedBox(height: 4),
          Text('You will be notified when assigned',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}