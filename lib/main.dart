import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// ---------------- SCREENS ----------------

// Welcome + Role
import 'screens/welcome_screen.dart';
import 'screens/role_selection.dart';

// User Screens
import 'screens/user_login.dart';
import 'screens/user_register.dart';
import 'screens/user_dashboard.dart';
import 'screens/user_alert.dart';
import 'screens/user_alert_status.dart';

// Officer Screens
import 'screens/officer_login.dart';
import 'screens/officer_register.dart';
import 'screens/officer_home.dart';
import 'screens/officer_status_check.dart';
import 'screens/officer_approval_page.dart';
import 'screens/officer_details_page.dart';
import 'screens/officer_update.dart';

// Admin Screens
import 'screens/admin_login.dart';
import 'screens/admin_register.dart';
import 'screens/admin_dashboard.dart';
import 'screens/admin_pending_cases.dart';
import 'screens/admin_alerts.dart';
import 'screens/admin_users.dart';
import 'screens/admin_officers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SafeHeavenApp());
}

class SafeHeavenApp extends StatelessWidget {
  const SafeHeavenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "SafeHeaven",

      // Initial Screen
      initialRoute: "/",

      // -------------------------- ROUTES --------------------------
      routes: {
        "/": (context) => const WelcomeScreen(),
        "/role": (context) => const RoleSelection(),

        // ---------------- USER ROUTES ----------------
        "/user/login": (context) => const UserLogin(),
        "/user/register": (context) => const UserRegister(),

        // UserDashboard requires arguments → handled dynamically below.
        "/user/dashboard": (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          return UserDashboard(uid: args?["uid"]);
        },

        "/user/alert": (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          return UserAlertPage(
            userId: args?["userId"],
            userName: args?["userName"],
            phone: args?["phone"],
          );
        },

        "/user/alert/status": (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          return UserAlertStatus(userId: args?["userId"]);
        },

        // ---------------- OFFICER ROUTES ----------------
        "/officer/login": (context) => const OfficerLogin(),
        "/officer/register": (context) => const OfficerRegister(),
        "/officer/wait": (context) => const OfficerWaitPage(),
        "/officer/status": (context) => const OfficerStatusCheck(),

        "/officer/home": (context) {
          return const OfficerHome();
        },

        "/officer/approval": (context) => const OfficerApprovalPage(),
        "/officer/details": (context) => const OfficerDetailsPage(),
        "/officer/update": (context) => const OfficerUpdatePage(),

        // ---------------- ADMIN ROUTES ----------------
        "/admin/login": (context) => const AdminLogin(),
        "/admin/register": (context) => const AdminRegister(),
        "/admin/dashboard": (context) => const AdminDashboard(),
        "/admin/alerts": (context) => const AdminAlertsScreen(),
        "/admin/pending_cases": (context) => const AdminPendingCases(),
        "/admin/users": (context) => const AdminUsersScreen(),
        "/admin/officers": (context) => const AdminOfficersScreen(),
      },

      // Fallback if route not found
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("Page Not Found")),
            body: Center(
              child: Text("No route found for ${settings.name}"),
            ),
          ),
        );
      },
    );
  }
}
