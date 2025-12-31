import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import 'models.dart';
import 'storage.dart';
import 'widgets.dart';
import 'theme.dart';

import 'pdf_preview_page.dart';
import 'services/photo_service.dart';
import 'services/invoice_pdf_service.dart';
import 'services/email_service.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final _photoService = PhotoService();
  final _pdfService = InvoicePdfService();
  final _emailService = EmailService();

  bool attachPhotos = true;
  bool sendEmail = false;

  WorkItem? _item;
  List<ServiceItem> _services = [];
  bool _loading = true;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  // ---------- Helpers ----------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _readWorkItemId() {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is String && args.trim().isNotEmpty) return args.trim();

    if (args is Map && args['id'] is String) {
      final id = (args['id'] as String).trim();
      if (id.isNotEmpty) return id;
    }

    return null;
  }

  Future<void> _init() async {
    final id = _readWorkItemId();
    if (id == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack("Missing Work Item ID.");
      return;
    }

    try {
      final item = await AppDb.instance.getWorkItem(id);
      final services = await AppDb.instance.listServices(id);

      if (!mounted) return;
      setState(() {
        _item = item;
        _services = services;
        _loading = false;
        sendEmail = (item == null) ? false : item.email.trim().isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack("Failed to load invoice: $e");
    }
  }

  // ---------- Photos ----------
  Future<void> _pickPhoto({required bool before}) async {
    if (_item == null) return;

    try {
      final savedPath = await _photoService.captureAndStore(
        workItemId: _item!.id,
        before: before,
        imageQuality: 75,
      );

      if (savedPath == null) return;

      final oldPath = before ? _item!.beforePhotoPath : _item!.afterPhotoPath;
      await _photoService.safeDeleteFile(oldPath);

      await AppDb.instance.updatePhotos(
        workItemId: _item!.id,
        beforePath: before ? savedPath : null,
        afterPath: before ? null : savedPath,
      );

      final fresh = await AppDb.instance.getWorkItem(_item!.id);
      if (!mounted) return;
      setState(() => _item = fresh);
    } catch (e) {
      _snack("Photo capture failed: $e");
    }
  }

  Future<void> _deletePhoto({required bool before}) async {
    if (_item == null) return;

    try {
      final oldPath = before ? _item!.beforePhotoPath : _item!.afterPhotoPath;
      await _photoService.safeDeleteFile(oldPath);

      // ✅ clear photo path properly
      await AppDb.instance.updatePhotos(
        workItemId: _item!.id,
        beforePath: before ? "" : null,
        afterPath: before ? null : "",
      );

      final fresh = await AppDb.instance.getWorkItem(_item!.id);
      if (!mounted) return;
      setState(() => _item = fresh);
    } catch (e) {
      _snack("Delete photo failed: $e");
    }
  }

  // ---------- PDF ----------
  String _pdfFileName() {
    final item = _item!;
    final shortId = item.id.length >= 6 ? item.id.substring(0, 6).toUpperCase() : item.id.toUpperCase();
    final d = DateFormat('yyyyMMdd').format(item.createdAt);
    return 'invoice_${d}_${shortId}.pdf';
  }

  Future<File> _savePdfToAppFiles(Uint8List bytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/work_items/${_item!.id}/invoices');
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('${dir.path}/${_pdfFileName()}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Uint8List> _buildPdfBytes() async {
    final bytesList = await _pdfService.buildPdfBytes(
      item: _item!,
      services: _services,
      includePhotos: attachPhotos,
    );
    return Uint8List.fromList(bytesList);
  }

  Future<void> _previewPdf() async {
    if (_item == null) return;

    try {
      final bytes = await _buildPdfBytes();
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewPage(
            title: "Invoice Preview",
            fileName: _pdfFileName(),
            pdfBytes: bytes,
          ),
        ),
      );
    } catch (e) {
      _snack("PDF preview failed: $e");
    }
  }

  Future<void> _sharePdf() async {
    if (_item == null) return;

    try {
      final bytes = await _buildPdfBytes();
      await Printing.sharePdf(bytes: bytes, filename: _pdfFileName());
    } catch (e) {
      _snack("Share failed: $e");
    }
  }

  Future<void> _savePdf() async {
    if (_item == null) return;

    try {
      final bytes = await _buildPdfBytes();
      final file = await _savePdfToAppFiles(bytes);
      _snack("Saved: ${file.path}");
    } catch (e) {
      _snack("Save failed: $e");
    }
  }

  // ---------- Email ----------
  Future<void> _sendEmailWithInvoice() async {
    if (_item == null) return;

    final bytes = await _buildPdfBytes();
    final pdfFile = await _savePdfToAppFiles(bytes);

    await _emailService.sendInvoiceEmail(
      item: _item!,
      pdfPath: pdfFile.path,
      attachPhotos: attachPhotos,
    );
  }

  // ---------- Complete ----------
  Future<bool> _confirmComplete() async {
    if (!mounted) return false;

    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Complete work item?"),
        content: Text(
          sendEmail
              ? "This will mark the work item as completed and open your email app to send the invoice."
              : "This will mark the work item as completed.",
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
              const SizedBox(width: 12),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Complete")),
            ],
          ),
        ],
      ),
    );

    return res ?? false;
  }

  Future<void> _showCompletedPrompt() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  "Completed Work Item",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _completeWorkItem() async {
    if (_item == null || _completing) return;

    final ok = await _confirmComplete();
    if (!ok) return;

    setState(() => _completing = true);

    try {
      if (sendEmail) {
        try {
          await _sendEmailWithInvoice();
        } catch (e) {
          _snack("Email failed: $e (Work item will still be completed)");
        }
      }

      await AppDb.instance.markCompleted(_item!.id);

      if (!mounted) return;
      await _showCompletedPrompt();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: {'tab': 1, 'workTab': 'completed'},
      );
    } catch (e) {
      _snack("Complete failed: $e");
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const GradientHeader(title: "Invoice Preview", showBack: true),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_item == null)
                    ? _errorState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _actionRow(),
                            const SizedBox(height: 12),
                            _invoiceCard(),
                            const SizedBox(height: 14),
                            _photoEmailSection(),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: GradientButton(
          text: _completing ? "Completing..." : "Complete Work Item",
          onTap: _completing ? () {} : _completeWorkItem,
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 10),
            const Text("Could not load invoice.", style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Go Back"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow() {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: (_item == null || _completing) ? null : _previewPdf,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(height: 4),
                    Text("Preview"),
                  ],
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: (_item == null || _completing) ? null : _sharePdf,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.share),
                    SizedBox(height: 4),
                    Text("Share"),
                  ],
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: (_item == null || _completing) ? null : _savePdf,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.download),
                    SizedBox(height: 4),
                    Text("Save"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoiceCard() {
    final dateText = DateFormat('EEEE, MMMM d, y').format(_item!.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primary2]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Work Item Invoice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(dateText, style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 14),
        const Text("Customer Details", style: TextStyle(color: AppColors.subText, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(_item!.customerName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 4),
        Text(_item!.phone),
        if (_item!.email.trim().isNotEmpty) Text(_item!.email),
        if (_item!.address.trim().isNotEmpty) Text(_item!.address),
        const Divider(height: 26),
        const Text("Services", style: TextStyle(color: AppColors.subText, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (_services.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text("No services added.", style: TextStyle(color: Colors.grey)),
          )
        else
          ..._services.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                    const SizedBox(width: 12),
                    Text("\$${s.amount.toStringAsFixed(2)}"),
                  ],
                ),
              )),
        const Divider(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Total Amount", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(
              "\$${_item!.total.toStringAsFixed(2)}",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.primary),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _photoEmailSection() {
    final beforePath = (_item!.beforePhotoPath != null && _item!.beforePhotoPath!.isNotEmpty) ? _item!.beforePhotoPath : null;
    final afterPath = (_item!.afterPhotoPath != null && _item!.afterPhotoPath!.isNotEmpty) ? _item!.afterPhotoPath : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Checkbox(
              value: attachPhotos,
              onChanged: _completing ? null : (v) => setState(() => attachPhotos = v ?? true),
            ),
            const Expanded(
              child: Text("Attach Before/After Photos", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        if (attachPhotos) ...[
          const SizedBox(height: 10),
          _photoBox(
            title: "Before Photo",
            path: beforePath,
            onCapture: () => _pickPhoto(before: true),
            onDelete: () => _deletePhoto(before: true),
          ),
          const SizedBox(height: 12),
          _photoBox(
            title: "After Photo",
            path: afterPath,
            onCapture: () => _pickPhoto(before: false),
            onDelete: () => _deletePhoto(before: false),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Checkbox(
              value: sendEmail,
              onChanged: _completing || _item!.email.trim().isEmpty ? null : (v) => setState(() => sendEmail = v ?? false),
            ),
            const Expanded(child: Text("Send Email", style: TextStyle(fontWeight: FontWeight.w900))),
          ],
        ),
        if (_item!.email.trim().isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              "No customer email on file — add an email to enable sending.",
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ]),
    );
  }

  Widget _photoBox({
    required String title,
    required String? path,
    required VoidCallback onCapture,
    required VoidCallback onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.subText, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Stack(
          children: [
            InkWell(
              onTap: _completing ? null : onCapture,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  color: AppColors.bg,
                ),
                child: path == null
                    ? const Center(child: Icon(Icons.camera_alt_outlined, color: Colors.grey))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(File(path), fit: BoxFit.cover),
                      ),
              ),
            ),
            if (path != null)
              Positioned(
                right: 10,
                top: 10,
                child: InkWell(
                  onTap: _completing ? null : onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
