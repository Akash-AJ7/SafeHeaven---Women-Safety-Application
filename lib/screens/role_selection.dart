import 'package:flutter/material.dart';

class RoleSelection extends StatelessWidget {
  const RoleSelection({super.key});

  Widget _roleCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required String loginRoute,
    required String registerRoute,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color,
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // LOGIN
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, loginRoute);
                  },
                  child: const Text("Login"),
                ),

                // REGISTER
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, registerRoute);
                  },
                  child: const Text("Register"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choose Your Role")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // USER
            _roleCard(
              context: context,
              title: "User",
              icon: Icons.person,
              color: Colors.pink,
              loginRoute: "/user/login",
              registerRoute: "/user/register",
            ),

            // OFFICER
            _roleCard(
              context: context,
              title: "Officer",
              icon: Icons.security,
              color: Colors.orange,
              loginRoute: "/officer/login",
              registerRoute: "/officer/register",
            ),

            // OFFICER STATUS CHECK
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, "/officer/status");
              },
              icon: const Icon(Icons.badge),
              label: const Text("Check Officer Status"),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48)),
            ),

            // ADMIN
            _roleCard(
              context: context,
              title: "Admin",
              icon: Icons.admin_panel_settings,
              color: Colors.deepPurple,
              loginRoute: "/admin/login",
              registerRoute: "/admin/register",
            ),
          ],
        ),
      ),
    );
  }
}
