import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

/// Renders QR [data] to PNG bytes on a white, padded canvas (scannable on any
/// background, ready to print or write to a tag). Uses qr_flutter's painter
/// directly — no widget tree / RepaintBoundary needed.
Future<Uint8List> qrPng(String data, {double module = 512, double pad = 28}) async {
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: true,
  );
  final full = module + pad * 2;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, full, full));
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, full, full),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  canvas.translate(pad, pad);
  painter.paint(canvas, ui.Size(module, module));
  final picture = recorder.endRecording();
  final image = await picture.toImage(full.round(), full.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

/// One labelled QR to place on a print sheet.
class StickPrintItem {
  StickPrintItem({required this.png, required this.title, this.sub = ''});
  final Uint8List png;
  final String title;
  final String sub;
}

/// Builds a print-ready A4 PDF with a grid of labelled QR codes (e.g. to cut out
/// and stick onto tags). Returns the PDF bytes.
Future<Uint8List> sticksPdf(List<StickPrintItem> items) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final it in items)
              pw.Container(
                width: 150,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(pw.MemoryImage(it.png), width: 138, height: 138),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      it.title,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (it.sub.isNotEmpty)
                      pw.Text(
                        it.sub,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 6.5),
                        maxLines: 2,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
