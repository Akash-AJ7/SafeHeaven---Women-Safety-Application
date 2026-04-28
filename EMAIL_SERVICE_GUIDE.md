# Email Service Configuration Guide

## Overview
The email service has been integrated into SafeHeaven to automatically send rejection notifications to officers when their application is rejected by an admin.

## What Happens When an Officer is Rejected?

1. **Data Deleted**: Officer's data is removed from Firestore
2. **Auth Account Deleted**: Firebase Auth account is removed
3. **Email Sent**: Rejection email is automatically sent to the officer's registered email address
4. **Re-registration Allowed**: Officer can re-register with the same email and phone number

## Configuration

### Step 1: Set Up Gmail App Password

Since Gmail no longer allows direct password authentication, you need to create an **App Password**:

1. Go to [Google Account Security](https://myaccount.google.com/security)
2. Enable **2-Step Verification** (if not already enabled)
3. Go to **App passwords** (Search for it in the security page)
4. Select **App**: Mail and **Device**: Windows/Mac/Linux
5. Generate the password
6. Copy the generated 16-character password

### Step 2: Update Email Service Credentials

Edit [lib/services/email_service.dart](lib/services/email_service.dart) and update:

```dart
static const String adminEmail = "your-email@gmail.com"; // Your Gmail address
static const String appPassword = "xxxx xxxx xxxx xxxx"; // Your 16-character app password
```

**Example:**
```dart
static const String adminEmail = "safeheaven.admin@gmail.com";
static const String appPassword = "abcd efgh ijkl mnop";
```

### Step 3: Verify Credentials Are Secure

For production:
- Store credentials in environment variables or Firebase Remote Config
- Never commit credentials to version control
- Use different credentials for dev/staging/production

## Email Templates

### Rejection Email Format

When an officer is rejected, they receive:

**Subject:** Application Status Update - SafeHeaven

**Plain Text:**
```
Dear [Officer Name],

Thank you for applying to become an officer at SafeHeaven.

Unfortunately, your application has been reviewed and rejected.

Reason: [Rejection Reason from Admin]

You can re-apply at any time with the same email and phone number.

Best regards,
SafeHeaven Admin Team
```

**HTML Template:**
- Professional branded email
- Red accent color for clarity
- Clear rejection reason displayed
- Instructions for re-applying
- Professional footer

## Usage Examples

### Send Rejection Email
```dart
bool emailSent = await EmailService.sendRejectionEmail(
  to: 'officer@example.com',
  officerName: 'John Doe',
  rejectionReason: 'Background check failed',
);
```

### Send Approval Email (Already implemented)
```dart
bool emailSent = await EmailService.sendApprovalEmail(
  to: 'officer@example.com',
  officerId: 'OF-123456',
  badgeNumber: 42,
);
```

## Troubleshooting

### Email Not Sending?

| Issue | Solution |
|-------|----------|
| "Authentication failed" | Check email and app password are correct |
| "Invalid sender address" | Verify the Gmail address matches the one in EmailService |
| "Connection timeout" | Ensure internet connection is stable |
| "SMTP server error" | Try again in a few minutes |

### Check Logs

Check Flutter console/terminal for error messages:
```
Email sent → officer@example.com
// OR
Failed to send rejection email: [error details]
```

## Email Service Methods

### EmailService.sendRejectionEmail()
Sends rejection notification to officer

**Parameters:**
- `to` (String): Officer's email address
- `officerName` (String): Officer's full name
- `rejectionReason` (String): Reason for rejection

**Returns:** `Future<bool>` - True if sent successfully

### EmailService.sendApprovalEmail()
Sends approval notification to officer

**Parameters:**
- `to` (String): Officer's email address
- `officerId` (String): Generated officer ID
- `badgeNumber` (int): Generated badge number

**Returns:** `Future<bool>` - True if sent successfully

## Testing

### Test Email Sending

1. Register a test officer with your personal email
2. As admin, reject the officer with a test reason
3. Check your email inbox for the rejection notification
4. Verify the reason and formatting

### Test Re-registration

1. After rejection, try registering again with same email/phone
2. Should be able to complete registration successfully

## Production Deployment

Before going live:

1. ✅ Test email sending with real Gmail account
2. ✅ Verify credentials are secure (not in source code)
3. ✅ Test email delivery times (usually < 1 minute)
4. ✅ Configure fallback email service if needed
5. ✅ Set up email monitoring/logs
6. ✅ Test with various email providers (Gmail, Outlook, etc.)

## Advanced Configuration

### Custom Email Templates

To customize email templates, edit the HTML builders in EmailService:

- `_buildRejectionEmailHtml()` - Customize rejection email appearance
- `_buildApprovalEmailHtml()` - Customize approval email appearance

### Change Email Provider

To use a different email service (SendGrid, SES, etc.):

1. Install the appropriate package in `pubspec.yaml`
2. Create new methods in EmailService
3. Update imports in officer_details_page.dart

## Security Best Practices

1. **Never hardcode credentials** in production
2. **Use Firebase Cloud Functions** for better security
3. **Store credentials in secure backend** 
4. **Rotate app passwords** regularly
5. **Monitor email sending logs** for suspicious activity
6. **Implement rate limiting** on email sending

## Integration Points

Email service is currently integrated in:
- [lib/screens/officer_details_page.dart](lib/screens/officer_details_page.dart) - Rejection emails

Can be integrated in:
- officer_approval_page.dart - Approval emails
- user_alert.dart - Alert notifications
- admin notifications

---

**Last Updated:** 2026-01-21  
**Version:** 1.0
