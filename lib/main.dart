// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rider/rider_auth_controller.dart';
import 'package:rider/rider_home_page.dart';
import 'package:rider/rider_login_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const RiderApp());
}

class RiderApp extends StatelessWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Delivery Rider',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4361EE),
        ),
        useMaterial3: true,
      ),
      // Put auth controller globally so it persists across routes
      initialBinding: BindingsBuilder(() {
        Get.put(RiderAuthController(), permanent: true);
      }),
      initialRoute: '/login',
      getPages: [
        GetPage(
          name: '/login',
          page: () => const RiderLoginPage(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/home',
          page: () => const RiderHomePage(),
          transition: Transition.fadeIn,
          middlewares: [AuthMiddleware()],
        ),
      ],
    );
  }
}

// Redirect to login if not authenticated
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<RiderAuthController>();
    if (!auth.isLoggedIn.value && route == '/home') {
      return const RouteSettings(name: '/login');
    }
    return null;
  }
}