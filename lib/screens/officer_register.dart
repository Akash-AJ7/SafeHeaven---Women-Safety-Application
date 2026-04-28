import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfficerRegister extends StatefulWidget {
  const OfficerRegister({super.key});

  @override
  State<OfficerRegister> createState() => _OfficerRegisterState();
}

class _OfficerRegisterState extends State<OfficerRegister> {
  final name = TextEditingController();
  final email = TextEditingController();
  final countryCode = TextEditingController(text: "+91"); // Default to India
  final mobileNumber = TextEditingController();
  final otp = TextEditingController();
  final password = TextEditingController();
  final pincode = TextEditingController();

  bool proofUploaded = false;
  bool photoUploaded = false;
  bool loading = false;
  String? verificationId;
  bool otpSent = false;

  Future sendOTP() async {
    if (countryCode.text.isEmpty || mobileNumber.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter country code and mobile number")),
      );
      return;
    }

    String phoneNumber = "${countryCode.text}${mobileNumber.text}";

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification
        await FirebaseAuth.instance.signInWithCredential(credential);
        setState(() => otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone verified automatically")),
        );
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification failed: ${e.message}")),
        );
      },
      codeSent: (String verId, int? resendToken) {
        setState(() {
          verificationId = verId;
          otpSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP sent to your phone")),
        );
      },
      codeAutoRetrievalTimeout: (String verId) {
        verificationId = verId;
      },
    );
  }

  Future verifyAndRegisterOfficer() async {
    if (otp.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter OTP")),
      );
      return;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otp.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      // Phone verified, now sign out and register with email/password
      await FirebaseAuth.instance.signOut();

      // Now register the officer with email/password
      await registerOfficer();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("OTP Verification Failed: $e")));
    }
  }

  registerOfficer() async {
    if (name.text.isEmpty ||
        email.text.isEmpty ||
        mobileNumber.text.isEmpty ||
        password.text.isEmpty ||
        pincode.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Fill all fields")));
      return;
    }

    int? officerPincode = int.tryParse(pincode.text);
    if (officerPincode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid pincode")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      String fullPhone = "${countryCode.text}${mobileNumber.text}";

      // Check if email already exists (across all statuses)
      QuerySnapshot emailCheck = await FirebaseFirestore.instance
          .collection("officers")
          .where("email", isEqualTo: email.text.trim())
          .get();

      if (emailCheck.docs.isNotEmpty) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Email already registered for another officer")),
        );
        return;
      }

      // Check if phone already exists (across all statuses)
      QuerySnapshot phoneCheck = await FirebaseFirestore.instance
          .collection("officers")
          .where("phone", isEqualTo: fullPhone)
          .get();

      if (phoneCheck.docs.isNotEmpty) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Phone number already registered for another officer")),
        );
        return;
      }

      // Firebase Auth
      UserCredential user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: email.text.trim(), password: password.text.trim());

      String uid = user.user!.uid;

      // Store officer info
      await FirebaseFirestore.instance.collection("officers").doc(uid).set({
        "uid": uid,
        "name": name.text.trim(),
        "email": email.text.trim(),
        "phone": fullPhone,
        "pincode": officerPincode,
        "status": "pending",
        "officerId": "",
        "createdAt": DateTime.now(),
      });

      Navigator.pushReplacementNamed(context, "/officer/wait");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Application submitted")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [
      TextField(
          controller: name,
          decoration: const InputDecoration(labelText: "Full Name")),
      TextField(
          controller: email,
          decoration: const InputDecoration(labelText: "Email")),
      TextField(
        controller: password,
        obscureText: true,
        decoration: const InputDecoration(labelText: "Password"),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: countryCode,
              decoration: const InputDecoration(labelText: "Country Code"),
              keyboardType: TextInputType.phone,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: TextField(
              controller: mobileNumber,
              decoration: const InputDecoration(labelText: "Mobile Number"),
              keyboardType: TextInputType.phone,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      TextField(
        controller: pincode,
        decoration: const InputDecoration(labelText: "Pincode"),
        keyboardType: TextInputType.number,
      ),
    ];

    if (otpSent) {
      children.add(const SizedBox(height: 20));
      children.add(TextField(
        controller: otp,
        decoration: const InputDecoration(labelText: "Enter OTP"),
        keyboardType: TextInputType.number,
      ));
    }

    children.add(const SizedBox(height: 20));
    children.add(ElevatedButton(
      onPressed: () => setState(() => proofUploaded = true),
      child: Text(proofUploaded ? "ID Proof Uploaded ✓" : "Upload ID Proof"),
    ));
    children.add(ElevatedButton(
      onPressed: () => setState(() => photoUploaded = true),
      child: Text(photoUploaded ? "Photo Added ✓" : "Add Photo"),
    ));
    children.add(const SizedBox(height: 20));
    children.add(ElevatedButton(
      onPressed:
          loading ? null : (otpSent ? verifyAndRegisterOfficer : sendOTP),
      child: loading
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(otpSent ? "Verify & Submit Application" : "Send OTP"),
    ));

    return Scaffold(
      appBar: AppBar(title: const Text("Officer Register")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: children),
      ),
    );
  }
}

class OfficerWaitPage extends StatelessWidget {
  const OfficerWaitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Please Wait")),
      body: const Center(
        child: Text(
          "Your application is submitted.\nAdmin will review it soon.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
