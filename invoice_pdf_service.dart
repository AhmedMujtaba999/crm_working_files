import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models.dart';

class InvoicePdfService {
  /// Builds PDF bytes. Optionally embeds before/after photos.
  Future<List<int>> buildPdfBytes({
    required WorkItem item,
    required List<ServiceItem> services,
    required bool includePhotos,
  }) async {
    final pdf = pw.Document();

    final invNo = _invoiceNumber(item);
    final dateStr = DateFormat('y-MM-dd').format(item.createdAt);

    pw.ImageProvider? beforeImg;
    pw.ImageProvider? afterImg;

    if (includePhotos) {
      beforeImg = await _loadImageIfExists(item.beforePhotoPath);
      afterImg = await _loadImageIfExists(item.afterPhotoPath);
    }

    final totalFromServices = services.fold<double>(0, (sum, s) => sum + s.amount);
    final total = item.total > 0 ? item.total : totalFromServices;

    pdf.addPage(
      pw.Page(
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Work Item Invoice",
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text("Invoice: $invNo"),
              pw.Text("Date: $dateStr"),
              pw.SizedBox(height: 12),

              pw.Text("Customer", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(item.customerName),
              pw.Text("Phone: ${item.phone}"),
              if (item.email.trim().isNotEmpty) pw.Text("Email: ${item.email}"),
              if (item.address.trim().isNotEmpty) pw.Text("Address: ${item.address}"),

              pw.SizedBox(height: 14),
              pw.Text("Services", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text("Service", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text("Amount", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...services.map(
                    (s) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(s.name),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("\$${s.amount.toStringAsFixed(2)}"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text("Total: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text("\$${total.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),

              if (includePhotos && (beforeImg != null || afterImg != null)) ...[
                pw.SizedBox(height: 16),
                pw.Text("Photos", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),

                if (beforeImg != null) ...[
                  pw.Text("Before"),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    height: 180,
                    child: pw.Image(beforeImg, fit: pw.BoxFit.cover),
                  ),
                  pw.SizedBox(height: 12),
                ],

                if (afterImg != null) ...[
                  pw.Text("After"),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    height: 180,
                    child: pw.Image(afterImg, fit: pw.BoxFit.cover),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  String _invoiceNumber(WorkItem item) {
    final shortId = item.id.length >= 6 ? item.id.substring(0, 6).toUpperCase() : item.id.toUpperCase();
    final d = DateFormat('yyyyMMdd').format(item.createdAt);
    return "INV-$d-$shortId";
  }

  Future<pw.ImageProvider?> _loadImageIfExists(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    final f = File(path);
    if (!await f.exists()) return null;
    final bytes = await f.readAsBytes();
    return pw.MemoryImage(bytes);
  }
}
