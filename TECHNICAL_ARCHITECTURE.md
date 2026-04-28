# Technical Architecture - Rejection Email System

## System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     ADMIN DASHBOARD                             │
│                  (officer_details_page.dart)                    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Officer Details View                                     │  │
│  │ ├─ Officer Name: John Doe                               │  │
│  │ ├─ Email: john@example.com                              │  │
│  │ ├─ Phone: +91-1234567890                                │  │
│  │ └─ Status: Pending                                      │  │
│  │                                                          │  │
│  │ [Approve] [Reject] [Close]                              │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────┬──────────────────────────────────────────────┘
                 │ Admin clicks [Reject]
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│               REJECTION DIALOG                                  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Enter rejection reason:                                  │  │
│  │                                                          │  │
│  │ [Background check failed - criminal record]   ⬚         │  │
│  │                                                          │  │
│  │                           [Cancel] [Reject]              │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────┬──────────────────────────────────────────────┘
                 │ Admin confirms rejection
                 ▼
        _rejectOfficer() Called
                 │
    ┌────────────┴────────────┬──────────────────┐
    ▼                          ▼                  ▼
 DELETE               DELETE               SEND EMAIL
 Firestore           Firebase Auth        via SMTP
    │                    │                  │
    ├─ officers doc   ├─ auth user      ├─ EmailService
    └─ All data       └─ credentials    └─ Gmail SMTP
                                           │
                                    ┌──────┴──────┐
                                    ▼             ▼
                              OFFICER EMAIL  LOGS
                              john@ex...     "Rejection
                                             email sent"
                                    │
                                    ▼
                          ┌─────────────────────┐
                          │ Professional Email  │
                          │ HTML Formatted      │
                          │ Rejection Reason    │
                          │ Re-apply Info       │
                          └─────────────────────┘
                                    │
                                    ▼
                        ┌───────────────────────┐
                        │ OFFICER INBOX         │
                        │ ├─ Subject: "Applic.. │
                        │ └─ Status: Unread     │
                        └───────────────────────┘
                                    │
                                    ▼
                        Officer Reads Email
                                    │
                                    ▼
                        Officer Re-registers
                        (Same email/phone OK)
```

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FIREBASE BACKEND                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────  ┌─────────────────────────────────┐  │
│  │ Firestore Database     │ Firebase Auth                   │  │
│  │                        │                                 │  │
│  │ /officers/{uid}        │ Users:                          │  │
│  │ ├─ name                │ ├─ UID: XXX                     │  │
│  │ ├─ email       ────────┼─ Email: john@ex.com            │  │
│  │ ├─ phone               │ └─ Verified: true              │  │
│  │ ├─ status              │                                 │  │
│  │ └─ admin_comment       │ ✋ ON REJECTION:                │  │
│  │                        │    Delete this user             │  │
│  │ ✋ ON REJECTION:        │                                 │  │
│  │    Delete this doc     │                                 │  │
│  └──────────────────────  └─────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                            ▲
                            │
                            │ (After deletion)
                            │
                            │
        ┌───────────────────┴─────────────────┐
        │   Re-registration Allowed           │
        │   ├─ Same email OK ✓               │
        │   ├─ Same phone OK ✓               │
        │   └─ New UID created               │
        └──────────────────────────────────────┘
```

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER LAYER                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  lib/screens/                                                    │
│  └─ officer_details_page.dart                                   │
│     ├─ _rejectOfficer()                                          │
│     │  ├─ Collects officer email & name                         │
│     │  ├─ Calls Firestore delete                                │
│     │  ├─ Calls Auth delete                                     │
│     │  └─ Calls EmailService.sendRejectionEmail()               │
│     └─ _showRejectDialog()                                      │
│        └─ UI for entering rejection reason                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                   SERVICE LAYER                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  lib/services/                                                   │
│  └─ email_service.dart                                          │
│     ├─ sendRejectionEmail()                                     │
│     │  ├─ Creates Message object                                │
│     │  ├─ Sets HTML template                                    │
│     │  ├─ Connects to Gmail SMTP                                │
│     │  └─ Sends email & returns status                          │
│     ├─ _buildRejectionEmailHtml()                               │
│     │  ├─ Professional HTML template                            │
│     │  ├─ Personalized content                                  │
│     │  └─ Responsive design                                     │
│     └─ sendApprovalEmail()                                      │
│        └─ Similar structure for approvals                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                   EXTERNAL SERVICES                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Google Gmail SMTP                                              │
│  ├─ Host: smtp.gmail.com                                        │
│  ├─ Port: 587 (TLS)                                             │
│  ├─ Auth: emailAddress + appPassword                            │
│  └─ Returns: Success/Failure                                    │
│                                                                  │
│  Officer Email Client                                           │
│  ├─ Receives email                                              │
│  ├─ Displays HTML                                               │
│  └─ Officer takes action                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Sequence Diagram

```
Admin                Officer Details      Email Service      Gmail SMTP        Officer
 │                      Page                │                 │                 │
 ├─ Clicks Reject ─────────────────────────>│                 │                 │
 │                                          │                 │                 │
 │<─ Shows Rejection Dialog ─────────────────┤                 │                 │
 │                                          │                 │                 │
 ├─ Enters Reason ────────────────────────────>│                 │                 │
 │                                          │                 │                 │
 ├─ Confirms Rejection ────────────────────────>│                 │                 │
 │                                          │                 │                 │
 │<─ Set Processing ────────────────────────────┤                 │                 │
 │                                          │                 │                 │
 │        ┌─ Delete from Firestore ──────────────┤                 │                 │
 │        ├─ Delete from Auth ──────────────────┤                 │                 │
 │        │                                 │                 │                 │
 │        └─ Call sendRejectionEmail() ──────────────────────>│                 │
 │                                          │                 │                 │
 │                                          ├─ Create Message ─────────────────>│
 │                                          │   Subject: "Status Update"        │
 │                                          │   Body: HTML + Text               │
 │                                          │   To: officer@email.com           │
 │                                          │                 │                 │
 │                                          │                 ├─ Verify Auth ──┐
 │                                          │                 │<─ OK ──────────┘
 │                                          │                 │                 │
 │                                          │                 ├─ Send Email ──>│
 │                                          │                 │                 │
 │                                          │<───── Success ───┤                 │
 │                                          │                 │                 │
 │<─ Show Success Message ────────────────────┤                 │                 │
 │   "Email sent to officer@email.com"     │                 │                 │
 │                                          │                 │                 │
 └─ Close Officer Details                   │                 │    Officer     │
                                            │                 │   Receives     │
                                            │                 │    Email       │
                                            │                 │        │       │
                                            │                 │        └──────>│
                                            │                 │               │
                                            │                 │<─ Officer ─────┘
                                            │                 │  reads email
```

## Error Handling Flow

```
┌──────────────────────┐
│ _rejectOfficer()     │
└──────┬───────────────┘
       │
       ▼
   TRY BLOCK
       │
    ┌──┴──────────────────────┬──────────────┐
    ▼                          ▼              ▼
 Delete          Delete      Email
Firestore        Auth       Service
    │                │          │
    ├─OK─┘           │          │
    │                │          │
    ├─ERROR──────────┼─────────>│ Catch Exception
    │                │          │
    │                ├─OK─┘     │
    │                │          │
    │                ├─ERROR────┤ Log Error
    │                │  (Expected) │
    │                │          │
    │                ▼          ▼
    │            (Continue)  Email
    │                        Fails
    │                          │
    └──────────┬───────────────┘
               │
               ▼
           SHOW RESULT
               │
    ┌──────────┴──────────┐
    ▼                     ▼
 Success             Error
   │                  │
   ├─ "Email sent"    ├─ "Officer data deleted"
   │                  │
   └─ Navigate Back   └─ Show Error Message
```

## Database State Changes

```
BEFORE REJECTION:
┌─ Firestore /officers/{uid}
│  ├─ name: "John Doe"
│  ├─ email: "john@example.com"
│  ├─ phone: "+91-1234567890"
│  ├─ status: "pending"
│  └─ createdAt: 2026-01-21T10:30:00Z
│
├─ Firebase Auth
│  └─ User{uid, email: john@example.com}


DURING REJECTION:
┌─ EmailService sends rejection email
│  ├─ To: john@example.com
│  ├─ Subject: "Application Status Update"
│  └─ Body: HTML + rejection reason
│
├─ Firestore delete operation
│ └─ officers/{uid} → DELETED
│
└─ Firebase Auth delete operation
   └─ User{john@example.com} → DELETED


AFTER REJECTION:
┌─ Firestore /officers/
│  └─ (no record for this UID)
│
├─ Firebase Auth
│  └─ (no user with john@example.com)
│
├─ Officer's Email
│  └─ Rejection notification received
│
└─ Re-registration Status
   ├─ Email: john@example.com ✓ Available
   └─ Phone: +91-1234567890 ✓ Available
```

---

This architecture ensures:
- ✅ Clean separation of concerns
- ✅ Proper error handling
- ✅ Professional email delivery
- ✅ Complete data cleanup
- ✅ Seamless re-registration
