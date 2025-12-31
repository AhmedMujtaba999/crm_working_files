import 'dart:io';
import 'package:flutter_email_sender/flutter_email_sender.dart';

import '../models.dart';

class EmailService {
  Future<void> sendInvoiceEmail({
    required WorkItem item,
    required String pdfPath,
    required bool attachPhotos,
  }) async {
    final emailAddr = item.email.trim();
    if (emailAddr.isEmpty) {
      throw Exception("Customer email is empty.");
    }

    // Basic email format validation to catch obvious problems early
    final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRe.hasMatch(emailAddr)) {
      throw Exception("Customer email is not a valid email address: $emailAddr");
    }

    final attachments = <String>[pdfPath];

    if (attachPhotos) {
      if (item.beforePhotoPath != null && item.beforePhotoPath!.trim().isNotEmpty) {
        final f = File(item.beforePhotoPath!);
        if (await f.exists()) attachments.add(f.path);
      }
      if (item.afterPhotoPath != null && item.afterPhotoPath!.trim().isNotEmpty) {
        final f = File(item.afterPhotoPath!);
        if (await f.exists()) attachments.add(f.path);
      }
    }

    final email = Email(
      body: "Hi ${item.customerName},\n\nPlease find attached your invoice.\n\nThanks,\nPoolPro CRM",
      subject: "Invoice - ${item.customerName}",
      recipients: [emailAddr],
      attachmentPaths: attachments,
    );

    await FlutterEmailSender.send(email);
  }
}
