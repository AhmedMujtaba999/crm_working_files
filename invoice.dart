import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _photoService = PhotoService(); // still used for before/after capture
  final _pdfService = InvoicePdfService();
  final _emailService = EmailService();

  final _picker = ImagePicker();

  bool attachPhotos = true;
  bool sendEmail = false;

  WorkItem? _item;
  List<ServiceItem> _services = [];
  bool _loading = true;
  bool _completing = false;

  bool _readOnly = false;

  // ✅ NEW: extra photos list (supports > 10 photos)
  static const int _maxExtraPhotos = 20;
  List<String> _extraPhotos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

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

        _readOnly = (item != null && item.status == 'completed');

        // enable email checkbox only if email exists
        sendEmail = (item == null) ? false : item.email.trim().isNotEmpty;
      });

      // ✅ load persisted extra photos from json manifest
      await _loadExtraPhotos();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack("Failed to load invoice: $e");
    }
  }

  // ---------- Paths / Storage for extra photos ----------
  Future<Directory> _photosDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/work_items/${_item!.id}/photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _extraPhotosManifest() async {
    final dir = await _photosDir();
    return File('${dir.path}/extra_photos.json');
  }

  Future<void> _loadExtraPhotos() async {
    if (_item == null) return;

    try {
      final manifest = await _extraPhotosManifest();
      if (!await manifest.exists()) {
        if (!mounted) return;
        setState(() => _extraPhotos = []);
        return;
      }

      final raw = await manifest.readAsString();
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        if (!mounted) return;
        setState(() => _extraPhotos = []);
        return;
      }

      // keep only existing files, avoid broken paths
      final valid = <String>[];
      for (final v in decoded) {
        if (v is String && v.trim().isNotEmpty) {
          final f = File(v);
          if (await f.exists()) valid.add(v);
        }
      }

      if (!mounted) return;
      setState(() => _extraPhotos = valid.take(_maxExtraPhotos).toList());
    } catch (e) {
      // don’t crash UI if manifest gets corrupted
      if (!mounted) return;
      setState(() => _extraPhotos = []);
      _snack("Could not load extra photos: $e");
    }
  }

  Future<void> _persistExtraPhotos() async {
    if (_item == null) return;
    try {
      final manifest = await _extraPhotosManifest();
      await manifest.writeAsString(jsonEncode(_extraPhotos), flush: true);
    } catch (e) {
      _snack("Saving photo list failed: $e");
    }
  }

  Future<String> _storePickedFile(XFile x) async {
    final dir = await _photosDir();

    // derive extension if possible
    String ext = '';
    final name = x.name;
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      ext = name.substring(dot); // includes ".jpg"
    }
    if (ext.isEmpty) ext = ".jpg";

    final ts = DateTime.now().millisecondsSinceEpoch;
    final out = File('${dir.path}/extra_$ts$ext');

    final bytes = await x.readAsBytes();
    await out.writeAsBytes(bytes, flush: true);

    return out.path;
  }

  // ---------- Photos (Before/After existing) ----------
  Future<void> _pickPhoto({required bool before}) async {
    if (_item == null) return;
    if (_readOnly) return;

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
    if (_readOnly) return;

    try {
      final oldPath = before ? _item!.beforePhotoPath : _item!.afterPhotoPath;
      await _photoService.safeDeleteFile(oldPath);

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

  // ---------- NEW: Extra Photos (multi) ----------
  bool get _extraLimitReached => _extraPhotos.length >= _maxExtraPhotos;

  Future<void> _addExtraFromCamera() async {
    if (_item == null) return;
    if (_readOnly || _completing) return;
    if (_extraLimitReached) {
      _snack("Max $_maxExtraPhotos extra photos reached.");
      return;
    }

    try {
      final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
      if (x == null) return;

      final path = await _storePickedFile(x);

      if (!mounted) return;
      setState(() {
        _extraPhotos.add(path);
        if (_extraPhotos.length > _maxExtraPhotos) {
          _extraPhotos = _extraPhotos.take(_maxExtraPhotos).toList();
        }
      });

      await _persistExtraPhotos();
    } catch (e) {
      _snack("Camera add failed: $e");
    }
  }

  Future<void> _addExtraFromGallery() async {
    if (_item == null) return;
    if (_readOnly || _completing) return;
    if (_extraLimitReached) {
      _snack("Max $_maxExtraPhotos extra photos reached.");
      return;
    }

    try {
      final picks = await _picker.pickMultiImage(imageQuality: 75);
      if (picks.isEmpty) return;

      final remaining = _maxExtraPhotos - _extraPhotos.length;
      final toAdd = picks.take(remaining).toList();

      final newPaths = <String>[];
      for (final x in toAdd) {
        final p = await _storePickedFile(x);
        newPaths.add(p);
      }

      if (!mounted) return;
      setState(() => _extraPhotos.addAll(newPaths));

      await _persistExtraPhotos();

      if (picks.length > remaining) {
        _snack("Added $remaining photo(s). Max $_maxExtraPhotos reached.");
      }
    } catch (e) {
      _snack("Gallery add failed: $e");
    }
  }

  Future<void> _removeExtraPhoto(String path) async {
    if (_item == null) return;
    if (_readOnly || _completing) return;

    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }

      if (!mounted) return;
      setState(() => _extraPhotos.remove(path));

      await _persistExtraPhotos();
    } catch (e) {
      _snack("Remove failed: $e");
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
    // ✅ Try new signature first (supports extra photos), fallback to old
    try {
      final dynamic svc = _pdfService;
      final bytesList = await svc.buildPdfBytes(
        item: _item!,
        services: _services,
        includePhotos: attachPhotos,
        extraPhotoPaths: _extraPhotos,
      );
      return Uint8List.fromList(List<int>.from(bytesList));
    } catch (_) {
      final bytesList = await _pdfService.buildPdfBytes(
        item: _item!,
        services: _services,
        includePhotos: attachPhotos,
      );
      return Uint8List.fromList(bytesList);
    }
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

    // ✅ Try new signature first (supports extra photos), fallback to old
    try {
      final dynamic es = _emailService;
      await es.sendInvoiceEmail(
        item: _item!,
        pdfPath: pdfFile.path,
        attachPhotos: attachPhotos,
        extraPhotoPaths: _extraPhotos,
      );
    } catch (_) {
      await _emailService.sendInvoiceEmail(
        item: _item!,
        pdfPath: pdfFile.path,
        attachPhotos: attachPhotos,
      );
    }
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
    if (_readOnly) return;

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
          GradientHeader(title: _readOnly ? "Invoice" : "Invoice Preview", showBack: true),
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
      bottomNavigationBar: _readOnly
          ? null
          : SafeArea(
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
    final createdText = DateFormat('EEE, MMM d, y • h:mm a').format(_item!.createdAt);
    final completedText = (_item!.completedAt == null)
        ? null
        : DateFormat('EEE, MMM d, y • h:mm a').format(_item!.completedAt!);

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
            Text(_readOnly ? "Invoice" : "Work Item Invoice", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text("Activated: $createdText", style: const TextStyle(color: Colors.white70)),
            if (completedText != null) ...[
              const SizedBox(height: 2),
              Text("Completed: $completedText", style: const TextStyle(color: Colors.white70)),
            ],
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

    final disabled = _completing || _readOnly;

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
            Expanded(
              child: Text(
                "Attach Photos (Before/After + Extra)",
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),

        if (attachPhotos) ...[
          const SizedBox(height: 10),

          // Before/After
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

          const SizedBox(height: 14),
          const Text("Additional Photos", style: TextStyle(color: AppColors.subText, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: disabled ? null : _addExtraFromCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text("Camera"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: disabled ? null : _addExtraFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text("Gallery"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            "${_extraPhotos.length} / $_maxExtraPhotos selected",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),

          _extraPhotos.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("No extra photos added.", style: TextStyle(color: Colors.grey)),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _extraPhotos.map((p) => _extraThumb(p)).toList(),
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

  Widget _extraThumb(String path) {
    final disabled = _completing || _readOnly;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        ),
        if (!disabled)
          Positioned(
            right: 6,
            top: 6,
            child: InkWell(
              onTap: () => _removeExtraPhoto(path),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  Widget _photoBox({
    required String title,
    required String? path,
    required VoidCallback onCapture,
    required VoidCallback onDelete,
  }) {
    final disabled = _completing || _readOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.subText, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Stack(
          children: [
            InkWell(
              onTap: disabled ? null : onCapture,
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
            if (path != null && !_readOnly)
              Positioned(
                right: 10,
                top: 10,
                child: InkWell(
                  onTap: disabled ? null : onDelete,
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
