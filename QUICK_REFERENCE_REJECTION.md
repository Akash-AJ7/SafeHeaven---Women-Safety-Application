# Quick Reference: Soft Rejection

## What Happens When Admin Rejects Officer?

```
ADMIN REJECTS WITH REASON
    ↓
DATABASE UPDATED
├─ Status: pending → rejected ✓
├─ Admin Comment: saved ✓
├─ Timestamp: recorded ✓
└─ Email: john@example.com (KEPT)

NOT DELETED:
├─ Officer data (KEPT)
├─ Firebase Auth (KEPT)
├─ Phone number (KEPT)
└─ All documents (KEPT)

NO EMAIL SENT ✓
```

## What Officer Sees

```
STATUS PAGE:
┌─────────────────────┐
│ Status: REJECTED ❌ │
├─────────────────────┤
│ Reason:             │
│ "photo is not clear"│
├─────────────────────┤
│ [Re-register Now]   │
└─────────────────────┘
```

## Officer's Next Steps

```
1. Read rejection reason
        ↓
2. Fix the issue (e.g., take better photo)
        ↓
3. Click "Re-register"
        ↓
4. Use SAME email & phone
        ↓
5. Resubmit new documents
        ↓
6. Back to "pending" status
```

## Key Points

✅ **Data Kept** - Officer info preserved in database  
✅ **No Email** - Officer checks status in app  
✅ **Can Resubmit** - Same email/phone allowed  
✅ **Comment Saved** - Officer sees what to fix  
✅ **Fast Process** - No account recreation needed  

## Why This Approach?

| Situation | Solution |
|-----------|----------|
| Photo not clear | ✓ Officer can retake & resubmit |
| Document missing | ✓ Officer can add & resubmit |
| Low quality ID | ✓ Officer can get better copy & resubmit |

## What Changed

| Feature | Before | Now |
|---------|--------|-----|
| Data deleted | ✗ Yes | ✓ No |
| Email sent | ✓ Yes | ✗ No |
| Re-registration | ✗ Need new email | ✓ Same email OK |
| Admin comment | ✓ Saved | ✓ Saved |

## Database Fields Updated

```
BEFORE REJECTION:
{
  status: "pending",
  admin_comment: ""
}

AFTER REJECTION:
{
  status: "rejected",
  admin_comment: "photo is not clear",
  rejectedAt: "2026-01-21T11:45:00Z"
}
```

## Code

```dart
// In officer_details_page.dart
await FirebaseFirestore.instance
  .collection('officers')
  .doc(docId)
  .update({
    'status': 'rejected',
    'officerId': '',
    'admin_comment': reason,
    'rejectedAt': FieldValue.serverTimestamp(),
  });
```

## Testing

1. Register officer
2. Admin rejects: "photo is not clear"
3. Check Firestore - data should be there ✓
4. Officer re-registers with same email ✓
5. New application submitted ✓

---

**Status:** ✅ Active  
**Updated:** January 21, 2026
