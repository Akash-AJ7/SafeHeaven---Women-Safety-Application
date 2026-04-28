import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class OfficerUpdatePage extends StatefulWidget {
  const OfficerUpdatePage({super.key});

  @override
  State<OfficerUpdatePage> createState() => _OfficerUpdatePageState();
}

class _OfficerUpdatePageState extends State<OfficerUpdatePage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final pincode = TextEditingController();

  File? idProofImage;
  File? photoImage;
  bool uploading = false;
  String uid = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get passed arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      uid = args['uid'] ?? '';
      name.text = args['name'] ?? '';
      email.text = args['email'] ?? '';
      phone.text = args['phone'] ?? '';
      pincode.text = args['pincode']?.toString() ?? '';
    }
  }

  Future<void> pickIdProof() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => idProofImage = File(pickedFile.path));
    }
  }

  Future<void> pickPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => photoImage = File(pickedFile.path));
    }
  }

  Future<void> submitUpdate() async {
    if (name.text.isEmpty || phone.text.isEmpty || pincode.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (idProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload ID proof")),
      );
      return;
    }

    if (photoImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please take a photo")),
      );
      return;
    }

    setState(() => uploading = true);

    try {
      // Update officer data in Firestore
      await FirebaseFirestore.instance.collection('officers').doc(uid).update({
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'pincode': int.parse(pincode.text),
        'status': 'pending', // Change back to pending for re-review
        'admin_comment': '', // Clear previous comment
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => uploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Application updated successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    pincode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Update Application")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Email display (non-editable)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Email (Cannot Change)",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email.text,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Name field
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Phone display (non-editable)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Mobile Number (Cannot Change)",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone.text,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pincode field
              TextField(
                controller: pincode,
                decoration: const InputDecoration(
                  labelText: "Pincode",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),

              // ID Proof upload
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("ID Proof",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  image: idProofImage != null
                      ? DecorationImage(
                          image: FileImage(idProofImage!), fit: BoxFit.cover)
                      : null,
                ),
                child: idProofImage == null
                    ? Center(
                        child: ElevatedButton.icon(
                          onPressed: pickIdProof,
                          icon: const Icon(Icons.upload),
                          label: const Text("Upload ID Proof"),
                        ),
                      )
                    : null,
              ),
              if (idProofImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: pickIdProof,
                      child: const Text("Change ID Proof"),
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Photo upload
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Photo",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  image: photoImage != null
                      ? DecorationImage(
                          image: FileImage(photoImage!), fit: BoxFit.cover)
                      : null,
                ),
                child: photoImage == null
                    ? Center(
                        child: ElevatedButton.icon(
                          onPressed: pickPhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text("Take Photo"),
                        ),
                      )
                    : null,
              ),
              if (photoImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: pickPhoto,
                      child: const Text("Retake Photo"),
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: uploading ? null : submitUpdate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: uploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          "Submit Updated Application",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
