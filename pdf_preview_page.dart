import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfPreviewPage extends StatelessWidget {
  const PdfPreviewPage({
    super.key,
    required this.title,
    required this.fileName,
    required this.pdfBytes,
  });

  final String title;
  final String fileName;
  final Uint8List pdfBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (format) async => pdfBytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
      // actions: [
      //     PdfPreviewAction(
      //       icon: Icon(Icons.file_download),
      //       onPressed: (context, build, pageFormat) async {
      //         final bytes = await build(pageFormat);
      //         await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      //       },
      //     ),
      //   ],
      // ),
      ),
    );
  }
}
