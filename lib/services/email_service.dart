import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // Gmail credentials - IMPORTANT: Use environment variables or secure storage in production
  static const String adminEmail = "akashaj20047@gmail.com"; // CHANGE THIS
  static const String appPassword =
      "wkkz gfgq wdab ipmj"; // CHANGE THIS (Gmail App Password)

  /// Send officer approval email
  static Future<bool> sendApprovalEmail({
    required String to,
    required String officerId,
    required int badgeNumber,
  }) async {
    try {
      print("🔧 Approval email config: From=$adminEmail, To=$to");
      final smtpServer = gmail(adminEmail, appPassword);

      final message = Message()
        ..from = const Address(adminEmail, "SafeHeaven Admin")
        ..recipients.add(to)
        ..subject = "Officer Application Approved ✓"
        ..html = _buildApprovalEmailHtml(officerId, badgeNumber)
        ..text = "Congratulations! Your application is approved.\n"
            "Your Officer ID: $officerId\n"
            "Your Badge Number: $badgeNumber\n\n"
            "Use this Officer ID to login.";

      await send(message, smtpServer);
      print("✅ Approval email sent → $to");
      return true;
    } catch (e, stackTrace) {
      print("❌ Failed to send approval email: $e");
      print("Stack trace: $stackTrace");
      try {
        await FirebaseFirestore.instance.collection('email_logs').add({
          'type': 'approval',
          'to': to,
          'officerId': officerId,
          'badgeNumber': badgeNumber,
          'error': e.toString(),
          'stack': stackTrace.toString(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (logErr) {
        print("Failed to log approval email error: $logErr");
      }
      return false;
    }
  }

  /// Send officer rejection email
  static Future<bool> sendRejectionEmail({
    required String to,
    required String officerName,
    required String rejectionReason,
  }) async {
    try {
      print("🔧 Rejection email config: From=$adminEmail, To=$to");
      final smtpServer = gmail(adminEmail, appPassword);

      // Simple plain-text rejection message per request
      final plainText = "Your application is rejected.\n"
          "Reason : $rejectionReason\n\n"
          "Update your application by checking the status button.\n\n"
          "Use this Officer ID to login.";

      final message = Message()
        ..from = const Address(adminEmail, "SafeHeaven Admin")
        ..recipients.add(to)
        ..subject = "Application Rejected - SafeHeaven"
        ..text = plainText
        ..html = "<pre>${plainText.replaceAll('<', '&lt;')}</pre>";

      await send(message, smtpServer);
      print("✅ Rejection email sent → $to");
      return true;
    } catch (e, stackTrace) {
      print("❌ Failed to send rejection email: $e");
      print("Stack trace: $stackTrace");
      try {
        await FirebaseFirestore.instance.collection('email_logs').add({
          'type': 'rejection',
          'to': to,
          'officerName': officerName,
          'reason': rejectionReason,
          'error': e.toString(),
          'stack': stackTrace.toString(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (logErr) {
        print("Failed to log rejection email error: $logErr");
      }
      return false;
    }
  }

  /// Build HTML for approval email
  static String _buildApprovalEmailHtml(String officerId, int badgeNumber) {
    return """
    <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #27ae60;">✓ Congratulations!</h2>
          <p>Your officer application has been <strong>approved</strong> by SafeHeaven Admin.</p>
          
          <div style="background-color: #f0f7f4; padding: 15px; border-left: 4px solid #27ae60; margin: 20px 0;">
            <p><strong>Officer ID:</strong> <span style="font-size: 18px; color: #27ae60;">$officerId</span></p>
            <p><strong>Badge Number:</strong> <span style="font-size: 18px; color: #27ae60;">$badgeNumber</span></p>
          </div>
          
          <p>Please use your Officer ID to login to the SafeHeaven application.</p>
          
          <p style="color: #7f8c8d; font-size: 12px; margin-top: 30px;">
            This is an automated email. Please do not reply to this email.
          </p>
        </div>
      </body>
    </html>
    """;
  }

  /// Build HTML for rejection email
  static String _buildRejectionEmailHtml(String officerName, String reason) {
    return """
    <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #e74c3c;">Application Status Update</h2>
          <p>Dear <strong>$officerName</strong>,</p>
          
          <p>Thank you for applying to become an officer at <strong>SafeHeaven</strong>.</p>
          
          <p style="color: #c0392b; font-weight: bold;">Unfortunately, your application has been reviewed and rejected.</p>
          
          <div style="background-color: #fadbd8; padding: 15px; border-left: 4px solid #e74c3c; margin: 20px 0;">
            <p><strong>Reason for Rejection:</strong></p>
            <p>$reason</p>
          </div>
          
          <p>You are welcome to re-apply at any time. You can use the same email address and phone number to register again.</p>
          
          <p style="color: #7f8c8d; margin-top: 30px;">
            If you have any questions, please contact our support team.
          </p>
          
          <p style="color: #7f8c8d; font-size: 12px; margin-top: 30px; border-top: 1px solid #ecf0f1; padding-top: 20px;">
            This is an automated email. Please do not reply to this email.
          </p>
        </div>
      </body>
    </html>
    """;
  }
}
