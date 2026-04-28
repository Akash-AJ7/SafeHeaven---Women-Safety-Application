# Quick Start: Email Rejection Feature

## ⚡ 5-Minute Setup

### Step 1: Get Gmail App Password (2 min)
1. Open [myaccount.google.com/security](https://myaccount.google.com/security)
2. Click "App passwords" 
3. Select: Mail + Windows/Mac/Linux
4. Copy the 16-character password

### Step 2: Update Credentials (1 min)
Open `lib/services/email_service.dart` and update:
```dart
static const String adminEmail = "your-gmail@gmail.com";
static const String appPassword = "abcd efgh ijkl mnop"; // Your 16-char password
```

### Step 3: Test (2 min)
1. Register a test officer with your email
2. As admin, go to officer details
3. Click "Reject" and enter a test reason
4. Check your email inbox

## 🎯 What Happens When Officer is Rejected

| Step | Action |
|------|--------|
| 1 | Officer data deleted from Firestore |
| 2 | Firebase Auth account deleted |
| 3 | Rejection email sent to officer |
| 4 | Officer can re-register with same email/phone |

## 📧 Email Sent to Officer

```
Subject: Application Status Update - SafeHeaven

Dear [Officer Name],

Thank you for applying to become an officer at SafeHeaven.

Unfortunately, your application has been reviewed and rejected.

Reason for Rejection:
[The reason you entered]

You are welcome to re-apply at any time with the same credentials.
```

## ✅ Checklist

- [ ] Gmail account has 2-Step Verification enabled
- [ ] Generated App Password (16 characters)
- [ ] Updated credentials in email_service.dart
- [ ] Tested with a test officer account
- [ ] Verified email received in inbox
- [ ] Verified officer data was deleted
- [ ] Tested re-registration with same email/phone

## 🔧 File Locations

| File | Purpose |
|------|---------|
| `lib/services/email_service.dart` | Email service (UPDATE CREDENTIALS HERE) |
| `lib/screens/officer_details_page.dart` | Rejection logic (already integrated) |
| `EMAIL_SERVICE_GUIDE.md` | Detailed configuration guide |
| `REJECTION_EMAIL_FEATURE.md` | Feature documentation |

## 🐛 Quick Troubleshooting

**Email not sending?**
- Check Gmail credentials are correct
- Verify 2-Step Verification is enabled
- Try regenerating App Password

**Officer still exists after rejection?**
- Check browser's offline mode
- Try refreshing the page
- Check Firestore console directly

**Getting "Authentication failed"?**
- Copy App Password exactly (includes spaces)
- It should be 16 characters: `xxxx xxxx xxxx xxxx`

## 📱 Integration Complete

The rejection email feature is now:
- ✅ Fully implemented
- ✅ Ready to test
- ✅ Waiting for Gmail credentials

**Next: Update credentials → Test → Deploy**

---

For detailed documentation, see [EMAIL_SERVICE_GUIDE.md](EMAIL_SERVICE_GUIDE.md)
