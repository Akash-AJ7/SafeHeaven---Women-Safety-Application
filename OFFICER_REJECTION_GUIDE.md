# Officer Rejection & Auto-Delete Feature

## Overview
When an admin rejects an officer's application, the system now automatically:
1. **Deletes the officer's data** from Firestore database
2. **Attempts to delete the Firebase Auth account** (with limitations on client-side)
3. **Allows re-registration** with the same email and phone number

## Implementation Details

### Changes Made

#### 1. **Officer Details Page** (`lib/screens/officer_details_page.dart`)
- Updated `_rejectOfficer()` method to delete officer data instead of just updating status
- Added Firebase Auth account deletion attempt
- Added proper error handling for auth deletion failures

**Key Logic:**
```dart
// Delete from Firestore
await FirebaseFirestore.instance.collection('officers').doc(docId).delete();

// Attempt to delete from Firebase Auth
User? currentUser = FirebaseAuth.instance.currentUser;
if (currentUser?.uid == docId) {
  await currentUser?.delete();
}
```

#### 2. **Officer Registration** (`lib/screens/officer_register.dart`)
- Added duplicate email validation before registration
- Added duplicate phone number validation before registration
- These checks prevent multiple active applications with same email/phone

**Key Logic:**
```dart
// Check for duplicate email
QuerySnapshot emailCheck = await FirebaseFirestore.instance
    .collection("officers")
    .where("email", isEqualTo: email.text.trim())
    .get();

// Check for duplicate phone
QuerySnapshot phoneCheck = await FirebaseFirestore.instance
    .collection("officers")
    .where("phone", isEqualTo: fullPhone)
    .get();
```

## Important Considerations

### Client-Side Limitations
The Flutter app can only delete a Firebase Auth account for the **currently authenticated user**. When an admin (different user) rejects an officer, the auth account cannot be deleted directly from the client.

### Solution: Cloud Function (Recommended)

For proper admin-side deletion, you should create a Firebase Cloud Function:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.deleteRejectedOfficer = functions.firestore
  .document('officers/{docId}')
  .onDelete(async (snap, context) => {
    const docId = context.params.docId;
    
    try {
      // Delete user from Firebase Auth
      await admin.auth().deleteUser(docId);
      console.log(`Deleted auth user: ${docId}`);
    } catch (error) {
      console.error(`Could not delete auth user ${docId}:`, error);
      // Log this for manual handling if needed
    }
  });
```

**How to deploy:**
```bash
cd functions
npm install firebase-admin firebase-functions
firebase deploy --only functions
```

### Flow Diagram

```
Admin Reviews Officer Application
         |
         v
Admin Clicks "Reject"
         |
         v
Dialog: Enter Rejection Reason
         |
         v
_rejectOfficer() called with docId
         |
    +----+----+
    |         |
    v         v
Delete     Delete
from       Auth
Firestore  Account
    |         |
    +----+----+
         |
         v
Show Success Message
Officer Can Re-register
```

## Testing

### Test Scenario 1: Basic Rejection
1. Officer registers with email: `test@example.com` and phone: `+911234567890`
2. Admin views officer details
3. Admin clicks "Reject" and enters reason
4. Officer document is deleted from Firestore
5. Officer tries to register again with same email/phone ✅ **Should work now**

### Test Scenario 2: Duplicate Prevention
1. Officer A registers with `email@test.com`
2. Officer B tries to register with same `email@test.com`
3. System shows: "Email already registered for another officer" ✅ **Prevented**

## Database Structure
```
/officers/{uid}
├── uid: string
├── name: string
├── email: string
├── phone: string
├── pincode: number
├── status: "pending" | "approved" | "rejected"
├── officerId: string (empty if rejected)
├── admin_comment: string
├── createdAt: timestamp
├── approvedAt: timestamp (only if approved)
└── rejectedAt: timestamp (only if rejected)
```

**After rejection:** Entire document is deleted

## Security Considerations

1. **Email Verification**: Firebase Auth will prevent duplicate email creation
2. **Phone Validation**: Firestore queries check for duplicate phone numbers
3. **Admin Only**: Only admins can reject officers (implement in admin_officers.dart)
4. **Audit Trail**: Consider logging rejections for compliance

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| "Email already registered" | During new registration | Wait 30 seconds, retry (deletion might be pending) |
| "Phone number already registered" | During new registration | Same as above |
| Auth deletion fails | Different user deleting | Deploy Cloud Function |
| Firestore deletion fails | Permission issue | Check Firebase security rules |

## Future Enhancements

1. Add audit logging to track rejections
2. Send email notification to rejected officer with reason
3. Implement soft delete option (keep records for compliance)
4. Add appeal process for rejected officers
5. Schedule bulk cleanup of incomplete applications

---

**Last Updated:** 2026-01-21
**Version:** 1.0
