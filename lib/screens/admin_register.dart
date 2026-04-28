import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRegister extends StatefulWidget {
  const AdminRegister({super.key});

  @override
  State<AdminRegister> createState() => _AdminRegisterState();
}

class _AdminRegisterState extends State<AdminRegister> {
  final name = TextEditingController();
  final adminId = TextEditingController();
  final password = TextEditingController();

  bool loading = false;

  Future registerAdmin() async {
    if (name.text.isEmpty || adminId.text.isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    setState(() => loading = true);

    await FirebaseFirestore.instance
        .collection("admins")
        .doc(adminId.text.trim())
        .set({
      "name": name.text.trim(),
      "adminId": adminId.text.trim(),
      "password": password.text.trim(),
      "createdAt": DateTime.now(),
    });

    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Admin Registered Successfully")),
    );

    Navigator.pushReplacementNamed(context, "/admin/login");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Register")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "Full Name"),
            ),
            TextField(
              controller: adminId,
              decoration: const InputDecoration(labelText: "Admin ID"),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : registerAdmin,
              child: loading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : const Text("Register"),
            )
          ],
        ),
      ),
    );
  }
}
