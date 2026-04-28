import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String? selectedPincode;
  List<String> pincodes = [];
  bool showAllUsers = true; // Show all users by default

  @override
  void initState() {
    super.initState();
    fetchPincodes();
  }

  Future fetchPincodes() async {
    QuerySnapshot snap =
        await FirebaseFirestore.instance.collection("users").get();
    Set<int> pincodeSet = {};
    for (var doc in snap.docs) {
      dynamic pincodeData = doc["pincode"];
      int? pin;
      if (pincodeData is int) {
        pin = pincodeData;
      } else if (pincodeData is String) {
        pin = int.tryParse(pincodeData);
      }
      if (pin != null) {
        pincodeSet.add(pin);
      }
    }
    setState(() {
      pincodes = pincodeSet.map((p) => p.toString()).toList()..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Users"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Toggle between View All and Filter by Pincode (styled like officers)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip("View All Users", "all"),
                      const SizedBox(width: 8),
                      _filterChip("Filter by Pincode", "pincode"),
                    ],
                  ),
                ),
                // Pincode Dropdown (shown only when filtering)
                if (!showAllUsers)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: DropdownButtonFormField<String>(
                      value: selectedPincode,
                      hint: const Text("Select Pincode"),
                      items: pincodes.map((pin) {
                        return DropdownMenuItem(
                          value: pin,
                          child: Text(pin),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedPincode = value;
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: showAllUsers
                  ? FirebaseFirestore.instance.collection("users").snapshots()
                  : (selectedPincode == null
                      ? const Stream.empty()
                      : FirebaseFirestore.instance
                          .collection("users")
                          .where("pincode",
                              isEqualTo: int.parse(selectedPincode!))
                          .snapshots()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  String message = showAllUsers
                      ? "No registered users found"
                      : (selectedPincode == null
                          ? "Select a pincode to view users"
                          : "No users in this pincode");
                  return Center(child: Text(message));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var user = snapshot.data!.docs[index];
                    var data = user.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade300,
                          child: Text(
                            (data["name"] ?? "U").toString()[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          data["name"] ?? "No Name",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              "Email: ${data['email'] ?? 'N/A'}",
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              "Phone: ${data['phone'] ?? 'N/A'}",
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              "Pincode: ${data['pincode'] ?? 'N/A'}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    bool isSelected = (value == 'all' && showAllUsers) ||
        (value == 'pincode' && !showAllUsers);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (value == 'all') {
            showAllUsers = true;
            selectedPincode = null;
          } else {
            showAllUsers = false;
          }
        });
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: Colors.blue.shade300,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
