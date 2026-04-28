# Officer Update Feature - Resubmission System

## Overview

Officers who have been rejected can now resubmit their applications with the same email and phone number through a dedicated "Update Application" feature.

## User Flow

```
OFFICER STATUS CHECK
        │
        ├─ Approved: No Update button
        │           (Final status)
        │
        ├─ Rejected: Show rejection reason
        │   + "Update Application" button
        │   (Officer can resubmit)
        │
        └─ Pending: Show pending message
                    (No update button)
```

## Features

### 1. Officer Status Check Screen (Enhanced)

**What's new:**
- Beautiful status cards with icons
- Clear visual hierarchy
- "Update Application" button only for rejected status
- Shows rejection reason

**Status Display:**

| Status | Display | Button |
|--------|---------|--------|
| **Approved** | Green card with check icon | ❌ None |
| **Rejected** | Red card with reason + icon | ✅ Update |
| **Pending** | Orange card with loading icon | ❌ None |
| **Error** | Grey card with error icon | ❌ None |
| **Not Found** | Grey card with not found icon | ❌ None |

### 2. Officer Update Page (New)

New screen at `/officer/update` where rejected officers can:

**Editable Fields:**
- ✏️ Full Name (can edit)
- ✏️ Pincode (can edit)

**Read-Only Fields:**
- 🔒 Email (cannot change - same email)
- 🔒 Phone (cannot change - same phone)

**New Uploads Required:**
- 📸 ID Proof (gallery)
- 📷 Photo (camera)

## Workflow Diagram

```
REJECTED OFFICER CHECKS STATUS
        ↓
Sees rejection reason: "photo is not clear"
        ↓
Clicks "Update Application"
        ↓
OFFICER UPDATE PAGE OPENS
        ├─ Email: i4@gmail.com (locked)
        ├─ Phone: +91-9994425477 (locked)
        ├─ Name: [Can edit]
        ├─ Pincode: [Can edit]
        ├─ ID Proof: [Upload new]
        └─ Photo: [Take new photo]
        ↓
Officer fixes issues and submits
        ↓
Status changed back to "pending"
        ↓
Admin reviews again
```

## Database Updates on Resubmission

**Before Update:**
```javascript
{
  uid: "abc123xyz",
  name: "John Doe",
  email: "john@example.com",
  phone: "+91-9994425477",
  status: "rejected",
  admin_comment: "photo is not clear",
  rejectedAt: "2026-01-21T11:45:00Z"
}
```

**After Update Submitted:**
```javascript
{
  uid: "abc123xyz",           // ← Preserved
  name: "John Doe Updated",   // ← May be updated
  email: "john@example.com",  // ← Fixed (cannot change)
  phone: "+91-9994425477",    // ← Fixed (cannot change)
  pincode: 621106,            // ← May be updated
  status: "pending",          // ← Changed back to pending
  admin_comment: "",          // ← Cleared
  rejectedAt: "2026-01-21T11:45:00Z",  // ← Preserved
  updatedAt: "2026-01-21T12:30:00Z"    // ← New timestamp
}
```

## Officer Update Screen UI

```
┌─────────────────────────────────┐
│     UPDATE APPLICATION          │
├─────────────────────────────────┤
│ Email (Cannot Change)           │
│ i4@gmail.com                    │ 🔒 Locked
├─────────────────────────────────┤
│ Full Name                       │
│ [John Doe          ]            │ ✏️ Editable
├─────────────────────────────────┤
│ Mobile (Cannot Change)          │
│ +91-9994425477                  │ 🔒 Locked
├─────────────────────────────────┤
│ Pincode                         │
│ [621105            ]            │ ✏️ Editable
├─────────────────────────────────┤
│ ID Proof                        │
│ ┌──────────────────────────┐   │
│ │  [Upload ID Proof]       │   │ 📸 Gallery
│ └──────────────────────────┘   │
├─────────────────────────────────┤
│ Photo                           │
│ ┌──────────────────────────┐   │
│ │  [Take Photo]            │   │ 📷 Camera
│ └──────────────────────────┘   │
├─────────────────────────────────┤
│  [Submit Updated Application]   │ 🔵 Blue button
└─────────────────────────────────┘
```

## Locked Fields Explanation

### Why Email Cannot Be Changed?
```
Reason: Email is the primary identifier for auth
└─ Changing email would create new Firebase Auth account
└─ Previous rejection history would be lost
└─ Officer should use same email to show continuity
```

### Why Phone Cannot Be Changed?
```
Reason: Phone is linked to the officer record
└─ Changing phone would break audit trail
└─ Admin needs to know it's the same officer reapplying
└─ Prevents fraud (different person using same email)
```

## Code Implementation

### Officer Status Check (Enhanced)
```dart
if (status == "rejected") ...[
  Container(
    // Beautiful red card with rejection details
    child: Column(
      children: [
        Text("Rejected"),
        Text("Reason: $reason"),
        ElevatedButton(
          onPressed: _resubmitApplication,
          label: "Update Application",
        ),
      ],
    ),
  ),
],
```

### Update Application Navigation
```dart
void _resubmitApplication() async {
  final user = FirebaseAuth.instance.currentUser;
  final data = await fetchOfficerData(user.uid);
  
  Navigator.pushNamed(
    context,
    '/officer/update',
    arguments: {
      'uid': user.uid,
      'email': data['email'],
      'phone': data['phone'],
      'name': data['name'],
      'pincode': data['pincode'],
    },
  );
}
```

### Officer Update Page
```dart
class OfficerUpdatePage extends StatefulWidget {
  // Receives arguments from status check
  // Email and phone are read-only
  // Name and pincode are editable
  // Photo and ID proof require new uploads
  
  Future<void> submitUpdate() {
    // Updates officer record
    // Changes status back to "pending"
    // Clears admin comment
    // Adds updatedAt timestamp
  }
}
```

## File Locations

**New Files:**
- [lib/screens/officer_update.dart](lib/screens/officer_update.dart) - Update application screen

**Modified Files:**
- [lib/screens/officer_status_check.dart](lib/screens/officer_status_check.dart) - Enhanced status display
- [lib/main.dart](lib/main.dart) - Added /officer/update route

## Testing Scenario

### Step 1: Officer Registers
```
Officer A registers with:
├─ Email: test@gmail.com
├─ Phone: +91-1234567890
├─ Name: John Smith
└─ Photo: unclear.jpg
```

### Step 2: Admin Rejects
```
Admin reviews and rejects:
└─ Reason: "photo is not clear"
```

### Step 3: Officer Checks Status
```
Officer logs in and checks status:
├─ Sees: Status = Rejected
├─ Sees: Reason = "photo is not clear"
└─ Clicks: "Update Application"
```

### Step 4: Officer Updates
```
Officer Update Page Opens:
├─ Email: test@gmail.com (locked) 🔒
├─ Phone: +91-1234567890 (locked) 🔒
├─ Name: [John Smith] (editable)
├─ Pincode: [123456] (editable)
├─ ID Proof: [Upload] (required)
└─ Photo: [Clear photo] (required)

Officer:
1. Takes clear photo
2. Submits update
```

### Step 5: Admin Reviews Again
```
Officer record updated:
├─ Status: pending (changed back)
├─ Admin comment: "" (cleared)
├─ Updated photo: clear.jpg (new)
└─ updatedAt: timestamp
```

## Key Features

✅ **Same Email & Phone** - Officer resubmits with same credentials  
✅ **Clear UI** - Beautiful status cards with icons  
✅ **Locked Fields** - Email and phone cannot be changed  
✅ **Simple Process** - One click from status check to update  
✅ **Complete History** - All previous data preserved  
✅ **New Uploads** - Officer uploads fresh photo and documents  

## Routes

| Route | Purpose | Arguments |
|-------|---------|-----------|
| `/officer/status` | Check application status | None |
| `/officer/update` | Resubmit application | uid, email, phone, name, pincode |

## Error Handling

**What If User Logs Out?**
```
Officer tries to update but session expired
└─ Show message: "Please login again"
└─ Redirect to login
```

**What If Officer Not Found?**
```
Officer data cannot be fetched
└─ Show error: "Officer record not found"
└─ Close update screen
```

**What If Update Fails?**
```
Network error or Firestore error
└─ Show error message
└─ Officer can retry
```

## Advantages

✅ **Officer Friendly** - Easy resubmission process  
✅ **Prevents Fraud** - Locked email prevents account switching  
✅ **Clear Feedback** - Rejection reason shown  
✅ **Quick Process** - No need to register again  
✅ **Admin Efficient** - All data in one place  
✅ **Audit Trail** - Complete history preserved  

## Status Flow with Updates

```
         ┌──────────────┐
         │   pending    │
         │ (Initial App)│
         └──────┬───────┘
                │
        Approve │  Reject
                │  │
         ┌──────▼─ │
         │ approved  │Update
         │          │ │
         └──────────┘ │
                      │
                  ┌───▼────────┐
                  │  rejected  │
                  │(Can Update)│
                  └───┬────────┘
                      │ Officer Updates
                      │
                  ┌───▼────────┐
                  │  pending   │
                  │ (New App)  │
                  └────────────┘
```

## Field Validation

**Name:**
- Required
- Min 2 characters
- Max 50 characters

**Pincode:**
- Required
- Numeric only
- 5-6 digits

**ID Proof:**
- Required
- Image file
- Max 5MB

**Photo:**
- Required
- Image file
- Taken with camera
- Max 5MB

## Success Message Flow

```
Officer submits update
        ↓
Validation passed
        ↓
Firestore update successful
        ↓
Show: "Application updated successfully"
        ↓
Navigate back to status check
        ↓
Refresh to show new status
```

---

**Implementation Date:** January 21, 2026  
**Status:** ✅ Ready  
**Version:** 1.0
