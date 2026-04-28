import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfficerLogin extends StatefulWidget {
  const OfficerLogin({super.key});

  @override
  State<OfficerLogin> createState() => _OfficerLoginState();
}

class _OfficerLoginState extends State<OfficerLogin> {
  final officerId = TextEditingController();
  final password = TextEditingController();
  bool loading = false;

  loginOfficer() async {
    if (officerId.text.isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter all fields")));
      return;
    }

    setState(() => loading = true);

    try {
      // Get officer data using officerId
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection("officers")
          .where("officerId", isEqualTo: officerId.text.trim())
          .get();

      if (snap.docs.isEmpty) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Officer ID not found")));
        return;
      }

      var data = snap.docs.first.data() as Map;
      String email = data["email"];

      // Login using officer email
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password.text.trim(),
      );

      Navigator.pushReplacementNamed(context, "/officer/home",
          arguments: {"name": data["name"], "officerId": officerId.text.trim()});

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Login Failed: $e")));
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Officer Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: officerId,
              decoration: const InputDecoration(labelText: "Officer ID"),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : loginOfficer,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Login"),
            )
          ],
        ),
      ),
    );
  }
}
