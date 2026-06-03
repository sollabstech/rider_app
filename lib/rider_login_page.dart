// lib/pages/rider_login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:rider/rider_auth_controller.dart';



class RiderLoginPage extends StatelessWidget {
  const RiderLoginPage({super.key});

  static const Color _primary  = Color(0xFF4361EE);
  static const Color _accent   = Color(0xFF3A0CA3);
  static const Color _bg       = Color(0xFFF6F7FB);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF8A8FA8);

  @override
  Widget build(BuildContext context) {
    final c = Get.find<RiderAuthController>();

    return Scaffold(
      backgroundColor: _bg,
      body: Obx(() {
        // Show full-screen loader while restoring session
        if (c.isLoading.value && c.currentRider.value == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _primary),
                SizedBox(height: 16),
                Text('Checking session...',
                    style: TextStyle(color: _textGrey, fontSize: 14)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              // ── Hero top section ─────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 52,
                  bottom: 52,
                  left: 24,
                  right: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4361EE), Color(0xFF3A0CA3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(40)),
                ),
                child: Column(
                  children: [
                    // App icon
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5),
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Rider Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in with credentials\ngiven by your admin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Login card ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Back 👋',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter your login details below',
                        style: TextStyle(
                            fontSize: 13, color: _textGrey),
                      ),
                      const SizedBox(height: 28),

                      // ── Username ──────────────────────────
                      _label('Username'),
                      const SizedBox(height: 8),
                      _inputField(
                        controller: c.usernameCtrl,
                        hint: 'Enter your username',
                        icon: Icons.alternate_email_rounded,
                        formatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9_.]'))
                        ],
                        action: TextInputAction.next,
                      ),

                      const SizedBox(height: 20),

                      // ── Password ──────────────────────────
                      _label('Password'),
                      const SizedBox(height: 8),
                      Obx(() => _passwordField(c)),

                      const SizedBox(height: 30),

                      // ── Login button ──────────────────────
                      Obx(() => SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: c.isLoading.value
                              ? null
                              : c.login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            disabledBackgroundColor:
                            _primary.withOpacity(0.5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(16)),
                          ),
                          child: c.isLoading.value
                              ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5))
                              : const Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded,
                                  color: Colors.white,
                                  size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight:
                                  FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),

                      const SizedBox(height: 22),

                      // ── Info note ─────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFE8EAF0)),
                        ),
                        child: const Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 17, color: _textGrey),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your username and password were created by the admin when they registered you. Contact your admin if you cannot log in.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _textGrey,
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Widgets ─────────────────────────────────────

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: _textDark,
      letterSpacing: 0.2,
    ),
  );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    List<TextInputFormatter>? formatters,
    TextInputAction action = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      inputFormatters: formatters,
      textInputAction: action,
      style: const TextStyle(
          fontSize: 14,
          color: _textDark,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        const TextStyle(color: _textGrey, fontSize: 13),
        prefixIcon: Icon(icon, color: _primary, size: 18),
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Color(0xFFE8EAF0), width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
            const BorderSide(color: _primary, width: 1.5)),
      ),
    );
  }

  Widget _passwordField(RiderAuthController c) {
    return TextField(
      controller: c.passwordCtrl,
      obscureText: !c.showPassword.value,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => c.login(),
      style: const TextStyle(
          fontSize: 14,
          color: _textDark,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Enter your password',
        hintStyle:
        const TextStyle(color: _textGrey, fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: _primary, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            c.showPassword.value
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: _textGrey,
            size: 20,
          ),
          onPressed: () =>
          c.showPassword.value = !c.showPassword.value,
        ),
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Color(0xFFE8EAF0), width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
            const BorderSide(color: _primary, width: 1.5)),
      ),
    );
  }
}