# Soft Rejection Feature - Officer Re-submission Support

## Overview

The **Soft Rejection** feature allows admins to reject officer applications **without permanently deleting data**. This is useful for cases where officers need to fix minor issues (like unclear photos) and resubmit their applications.

## How It Works

### Before (Hard Rejection - REMOVED)
```
Admin Rejects Officer
        ↓
Data Deleted from Database
        ↓
Auth Account Deleted
        ↓
Email Sent to Officer
        ↓
Officer Cannot Use Same Email/Phone
```

### After (Soft Rejection - NEW)
```
Admin Rejects Officer with Reason
        ↓
Status Updated to "rejected"
        ↓
Admin Comment Saved (reason visible to officer)
        ↓
Data Preserved in Database
        ↓
Auth Account Preserved
        ↓
NO Email Sent
        ↓
Officer Can Resubmit with Same Email/Phone
```

## What Happens on Soft Rejection

| Item | Status |
|------|--------|
| **Officer Document** | ✅ Kept in Firestore |
| **Firebase Auth Account** | ✅ Kept in Firebase Auth |
| **Officer Status** | ❌ Changed to "rejected" |
| **Admin Comment** | ✅ Saved with rejection reason |
| **Email to Officer** | ❌ NOT sent |
| **Re-registration** | ✅ Can use same email/phone |
| **Data Visible to Admin** | ✅ All data still visible |

## Common Rejection Reasons (No Email)

- ❌ Photo is not clear
- ❌ ID proof quality too low
- ❌ Incomplete documents
- ❌ Missing information
- ❌ Wrong document format
- ❌ Handwriting not readable

## Officer Resubmission Flow

```
Officer Sees Status: REJECTED
        ↓
Reads Admin Comment
        ↓
Fixes Issues
        ↓
Re-registers with Same Email/Phone
        ↓
CAN SUCCEED (Data was kept)
        ↓
New Application Submitted
        ↓
Admin Reviews Again
```

## Database Changes During Soft Rejection

### Before Rejection
```javascript
/officers/{uid}
{
  "uid": "abc123xyz",
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "+91-9994425477",
  "pincode": 621105,
  "status": "pending",
  "officerId": "",
  "createdAt": "2026-01-21T10:30:00Z"
}
```

### After Soft Rejection
```javascript
/officers/{uid}
{
  "uid": "abc123xyz",
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "+91-9994425477",
  "pincode": 621105,
  "status": "rejected",              // ← Changed
  "officerId": "",                   // ← Cleared
  "admin_comment": "photo is not clear",  // ← Added
  "rejectedAt": "2026-01-21T11:45:00Z",  // ← Timestamp
  "createdAt": "2026-01-21T10:30:00Z"    // ← Preserved
}
```

## Admin Panel Display

When viewing a rejected officer:

```
═══════════════════════════════════
    REJECTED OFFICER DETAILS
═══════════════════════════════════

Status: REJECTED (Red label)

Officer ID: [empty]

Email: john@example.com

Phone: +91-9994425477

Pincode: 621105

Registration Date: N/A

Admin Comment: "photo is not clear"

═══════════════════════════════════
```

## Officer Status Check Flow

### Officer Sees Rejection
```
1. Officer logs into app
2. Goes to "Status Check"
3. Sees: Status = REJECTED
4. Sees: Reason = "photo is not clear"
5. Option: Re-register with fixes
```

### Officer Resubmits
```
1. Officer fixes photo
2. Clicks "Re-register"
3. Uses same email + phone
4. System accepts (data was kept)
5. New application submitted
6. Status becomes "pending" again
```

## Code Implementation

### Rejection Method
```dart
Future<void> _rejectOfficer(String docId, Map data, String reason) async {
  await FirebaseFirestore.instance
    .collection('officers')
    .doc(docId)
    .update({
      'status': 'rejected',
      'officerId': '',
      'admin_comment': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  
  // Data is preserved
  // No email sent
  // No auth deletion
}
```

## Key Differences from Hard Rejection

| Feature | Soft Rejection | Hard Rejection |
|---------|---|---|
| **Data Deleted** | ❌ No | ✅ Yes |
| **Auth Deleted** | ❌ No | ✅ Yes |
| **Email Sent** | ❌ No | ✅ Yes |
| **Re-registration** | ✅ Same email/phone | ❌ Different email required |
| **Admin Comment** | ✅ Saved & Visible | ✅ Visible |
| **Officer Can Resubmit** | ✅ Yes | ❌ No (data deleted) |
| **Use Case** | Minor issues | Major issues |

## Scenario Examples

### Example 1: Unclear Photo
```
Admin: "Photo is not clear"
Result: Soft Rejection
Officer Action: Retake photo, resubmit
Email Sent: NO
```

### Example 2: Incomplete Documents
```
Admin: "Missing certificate"
Result: Soft Rejection
Officer Action: Upload missing docs, resubmit
Email Sent: NO
```

### Example 3: Quality Issues
```
Admin: "ID proof quality too low"
Result: Soft Rejection
Officer Action: Get better quality proof, resubmit
Email Sent: NO
```

## Officer Re-registration Process

### Step 1: Officer Sees Rejection
Officer logs in and sees their application is rejected with reason visible.

### Step 2: Officer Fixes Issues
Officer corrects the issues mentioned in the admin comment.

### Step 3: Officer Re-registers
```
Registration Form
├─ Full Name: [Prefilled]
├─ Email: same@email.com ✓ Allowed
├─ Phone: +91-9994425477 ✓ Allowed
├─ Password: [New or same]
├─ Pincode: [Same]
├─ Photo: [Better quality]
├─ ID Proof: [Better quality]
└─ Submit
```

### Step 4: New Application
- New application submitted
- Status changed back to "pending"
- Goes to admin review queue again

## Admin Panel Behavior

### Viewing Rejected Officer
- ✅ All original data visible
- ✅ Can see rejection reason
- ✅ Can see rejection timestamp
- ✅ Can see all previous documents
- ✅ Can see if officer has resubmitted

### Options for Admin
- Review again (if resubmitted)
- Approve or reject again
- Delete officer (if needed for compliance)

## Benefits of Soft Rejection

✅ **Officer Friendly** - Clear feedback without losing data  
✅ **Reduced Friction** - No need for new email/phone  
✅ **Better UX** - Officer knows exactly what to fix  
✅ **Admin Flexibility** - Can see full history  
✅ **Compliance** - Data preserved for records  
✅ **Efficiency** - Faster resubmission process  

## Status Flow

```
     ┌──────────────────────────────┐
     │      pending                 │
     │ (Initial Application)        │
     └──────────┬─────────────────┬─┘
                │                 │
        Approve │                 │ Reject
                │                 │
         ┌──────▼────┐      ┌─────▼──────┐
         │ approved  │      │ rejected   │
         │ (Final)   │      │ (Can retry)│
         └───────────┘      └─────┬──────┘
                                  │ Re-register
                                  │
                            ┌─────▼──────┐
                            │  pending   │
                            │ (New App)  │
                            └────────────┘
```

## Rejection Reasons Field

The `admin_comment` field stores the rejection reason:

```dart
// Admin enters this in the rejection dialog:
"photo is not clear"

// Stored in Firestore as:
admin_comment: "photo is not clear"

// Officer can see this in status check
// Shows as: "Reason: photo is not clear"
```

## No Email Notification

Unlike previous implementation:
- ❌ Officer does NOT receive email
- ❌ Officer must check status in app
- ✅ Officer sees rejection reason in app
- ✅ Officer can resubmit immediately

## Future Enhancements

Optional features that could be added:
1. Allow officer to provide feedback before resubmitting
2. Automatic email after specific days (if not resubmitted)
3. Support ticket system for officer questions
4. Admin approval preview before sending rejection
5. Bulk rejection operations
6. Rejection reason templates

## Testing Checklist

- [ ] Admin can reject officer with custom reason
- [ ] Officer data remains in Firestore
- [ ] Officer status shows "rejected" with red badge
- [ ] Admin comment is visible in officer details
- [ ] Officer can re-register with same email/phone
- [ ] No email is sent to officer
- [ ] Officer can check status in app
- [ ] Officer sees rejection reason in status check

---

**Implementation Date:** January 21, 2026  
**Status:** ✅ Active  
**Version:** 2.0 (Updated from Hard Rejection)
