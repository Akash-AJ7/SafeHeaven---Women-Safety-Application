import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserRegister extends StatefulWidget {
  const UserRegister({super.key});

  @override
  State<UserRegister> createState() => _UserRegisterState();
}

class _UserRegisterState extends State<UserRegister> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final countryCode = TextEditingController(text: "+91"); // Default to India
  final mobileNumber = TextEditingController();
  final otp = TextEditingController();
  final pincode = TextEditingController();
  XFile? pickedImage;

  String? verificationId;
  bool otpSent = false;

  Future pickPhoto() async {
    final picker = ImagePicker();
    XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => pickedImage = file);
    }
  }

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

  Future verifyOTP() async {
    if (otp.text.isEmpty || verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter OTP")),
      );
      return;
    }

    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId!,
      smsCode: otp.text,
    );

    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone verified")),
      );
      // Now proceed with registration
      await registerUser();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OTP verification failed: $e")),
      );
    }
  }

  Future registerUser() async {
    if (name.text.isEmpty ||
        email.text.isEmpty ||
        pass.text.isEmpty ||
        mobileNumber.text.isEmpty ||
        pincode.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all fields")),
      );
      return;
    }

    int? userPincode = int.tryParse(pincode.text);
    if (userPincode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid pincode")),
      );
      return;
    }

    try {
      // Auth with email/password
      UserCredential userCred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: pass.text.trim(),
      );

      String uid = userCred.user!.uid;

      // Upload photo (optional)
      String photoUrl = "";
      if (pickedImage != null) {
        final ref =
            FirebaseStorage.instance.ref().child("users/$uid/profile.jpg");
        await ref.putFile(File(pickedImage!.path));
        photoUrl = await ref.getDownloadURL();
      }

      // Store user record
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "uid": uid,
        "name": name.text.trim(),
        "email": email.text.trim(),
        "phone": "${countryCode.text}${mobileNumber.text}",
        "pincode": userPincode,
        "photo": photoUrl,
        "role": "user",
        "createdAt": DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registered Successfully")));

      Navigator.pushReplacementNamed(context, "/user/login");
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Registration Failed: $e")));
    }
  }

  Future verifyAndRegister() async {
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

      // Now register the user with email/password
      await registerUser();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("OTP Verification Failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [
      GestureDetector(
        onTap: pickPhoto,
        child: CircleAvatar(
          radius: 45,
          backgroundImage:
              pickedImage != null ? FileImage(File(pickedImage!.path)) : null,
          child: pickedImage == null
              ? const Icon(Icons.camera_alt, size: 40)
              : null,
        ),
      ),
      const SizedBox(height: 20),
      TextField(
          controller: name,
          decoration: const InputDecoration(labelText: "Name")),
      TextField(
          controller: email,
          decoration: const InputDecoration(labelText: "Email")),
      TextField(
        controller: pass,
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
      onPressed: otpSent ? verifyAndRegister : sendOTP,
      child: Text(otpSent ? "Verify & Register" : "Send OTP"),
    ));

    return Scaffold(
      appBar: AppBar(title: const Text("User Register")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: children),
      ),
    );
  }
}
