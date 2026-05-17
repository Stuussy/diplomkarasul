import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/medical_record.dart';

class MedicalRecordPdfBuilder {
  static Future<Uint8List> build(MedicalRecord record) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();

    final theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
    );

    final doc = pw.Document(theme: theme);

    final clinicName = record.clinic?.name ?? 'Dental AI';
    final clinicAddress = [record.clinic?.city, record.clinic?.address]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(', ');
    final clinicPhone = record.clinic?.contacts?.phone;
    final patientName = record.patient?.fullName ?? '—';
    final patientPhone = record.patient?.phone;
    final doctorName = record.doctor?.fullName ?? '—';
    final doctorSpec = record.doctor?.specialties.join(', ') ?? '';
    final dateStr = _formatDate(record.createdAt);
    final timeStr = _formatTime(record.createdAt);
    final receiptNo = record.id.length >= 6
        ? record.id.substring(record.id.length - 6).toUpperCase()
        : record.id.toUpperCase();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
        build: (context) => [
          _header(clinicName, clinicAddress, clinicPhone, receiptNo, dateStr),
          pw.SizedBox(height: 18),
          _patientDoctorBlock(
            patientName: patientName,
            patientPhone: patientPhone,
            doctorName: doctorName,
            doctorSpec: doctorSpec,
            dateStr: dateStr,
            timeStr: timeStr,
          ),
          pw.SizedBox(height: 16),
          _section('Заключение / Услуга', record.title),
          if (record.description != null && record.description!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _section('Описание и рекомендации', record.description!),
          ],
          if (record.tags.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _tagsRow(record.tags),
          ],
          if (record.toothMap.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Зубная карта'),
            pw.SizedBox(height: 6),
            _toothChartBlock(record.toothMap),
            pw.SizedBox(height: 8),
            _toothLegend(),
          ],
          pw.SizedBox(height: 18),
          _receiptBlock(record, clinicName: clinicName, receiptNo: receiptNo, dateStr: dateStr),
          pw.SizedBox(height: 22),
          _signatureBlock(doctorName),
          pw.SizedBox(height: 18),
          _footer(),
        ],
      ),
    );

    return doc.save();
  }

  // ---- Building blocks ----

  static pw.Widget _header(
    String clinicName,
    String address,
    String? phone,
    String receiptNo,
    String dateStr,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColor.fromInt(0xFF0A4DD3), PdfColor.fromInt(0xFF2E8BFF)],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 44,
            height: 44,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'D',
              style: pw.TextStyle(
                color: const PdfColor.fromInt(0xFF0A4DD3),
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  clinicName,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (address.isNotEmpty)
                  pw.Text(
                    address,
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                  ),
                if (phone != null && phone.isNotEmpty)
                  pw.Text(
                    'Тел.: $phone',
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Медицинская карта',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '№ $receiptNo',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'от $dateStr',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _patientDoctorBlock({
    required String patientName,
    String? patientPhone,
    required String doctorName,
    required String doctorSpec,
    required String dateStr,
    required String timeStr,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _infoCard(
            title: 'Пациент',
            lines: [
              patientName,
              if (patientPhone != null && patientPhone.isNotEmpty) patientPhone,
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _infoCard(
            title: 'Врач',
            lines: [doctorName, if (doctorSpec.isNotEmpty) doctorSpec],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _infoCard(
            title: 'Дата приёма',
            lines: ['$dateStr', timeStr],
          ),
        ),
      ],
    );
  }

  static pw.Widget _infoCard({required String title, required List<String> lines}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF4F7FB),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 8,
              color: const PdfColor.fromInt(0xFF6B7A8F),
              letterSpacing: 0.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          ...lines.map(
            (line) => pw.Text(
              line,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 3,
          height: 14,
          color: const PdfColor.fromInt(0xFF0A4DD3),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _section(String title, String body) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFBFCFE),
            border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.6),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(body, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        ),
      ],
    );
  }

  static pw.Widget _tagsRow(List<String> tags) {
    return pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags
          .map(
            (tag) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFEAF2FF),
                borderRadius: pw.BorderRadius.circular(20),
              ),
              child: pw.Text(
                tag,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: const PdfColor.fromInt(0xFF0A4DD3),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _toothChartBlock(List<ToothMark> toothMap) {
    String statusFor(String arch, int index) {
      final match = toothMap.where((t) => t.arch == arch && t.index == index);
      return match.isEmpty ? 'none' : match.first.status;
    }

    pw.Widget arch(String archName, {required bool flip}) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: List.generate(14, (i) {
          final num = i + 1;
          final pos = num <= 7 ? 8 - num : num - 7;
          final w = pos >= 6
              ? 18.0
              : pos >= 4
                  ? 16.0
                  : pos == 3
                      ? 14.0
                      : 13.0;
          final status = statusFor(archName, num);
          return pw.Container(
            margin: pw.EdgeInsets.symmetric(horizontal: num == 7 ? 4 : 1.5),
            child: pw.Column(
              children: flip
                  ? [_toothShape(w, status, flip: true), pw.SizedBox(height: 1), pw.Text('$num', style: const pw.TextStyle(fontSize: 6))]
                  : [pw.Text('$num', style: const pw.TextStyle(fontSize: 6)), pw.SizedBox(height: 1), _toothShape(w, status, flip: false)],
            ),
          );
        }),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFBFCFE),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.6),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          arch('upper', flip: false),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 3,
            color: const PdfColor.fromInt(0xFFFFB2A6),
            margin: const pw.EdgeInsets.symmetric(horizontal: 8),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 3,
            color: const PdfColor.fromInt(0xFFFFB2A6),
            margin: const pw.EdgeInsets.symmetric(horizontal: 8),
          ),
          pw.SizedBox(height: 4),
          arch('lower', flip: true),
        ],
      ),
    );
  }

  static pw.Widget _toothShape(double width, String status, {required bool flip}) {
    final colors = _statusColors(status);
    final crown = pw.Container(
      width: width,
      height: 14,
      decoration: pw.BoxDecoration(
        color: colors.$1,
        border: pw.Border.all(color: colors.$2, width: 0.6),
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(2),
          topRight: pw.Radius.circular(2),
          bottomLeft: pw.Radius.circular(6),
          bottomRight: pw.Radius.circular(6),
        ),
      ),
    );
    final root = pw.Container(
      width: width * 0.55,
      height: 8,
      decoration: pw.BoxDecoration(
        color: colors.$1,
        border: pw.Border.all(color: colors.$2, width: 0.5),
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(4),
          topRight: pw.Radius.circular(4),
        ),
      ),
    );
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: flip ? [crown, root] : [root, crown],
    );
  }

  static (PdfColor, PdfColor) _statusColors(String status) {
    switch (status) {
      case 'issue':
        return (const PdfColor.fromInt(0xFFFFD7C6), const PdfColor.fromInt(0xFFE36A45));
      case 'treated':
        return (const PdfColor.fromInt(0xFFCFEDE3), const PdfColor.fromInt(0xFF2C9B85));
      case 'missing':
        return (const PdfColor.fromInt(0xFFE0E5EA), const PdfColor.fromInt(0xFF8A99A3));
      case 'healthy':
        return (PdfColors.white, const PdfColor.fromInt(0xFFC8D2DE));
      default:
        return (const PdfColor.fromInt(0xFFF6F8FB), const PdfColor.fromInt(0xFFD5DCE6));
    }
  }

  static pw.Widget _toothLegend() {
    pw.Widget item(String label, PdfColor fill, PdfColor outline) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 9,
            height: 9,
            decoration: pw.BoxDecoration(
              color: fill,
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: outline, width: 0.6),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        ],
      );
    }

    return pw.Row(
      children: [
        item('Здоров', PdfColors.white, const PdfColor.fromInt(0xFFC8D2DE)),
        pw.SizedBox(width: 12),
        item('Лечение', const PdfColor.fromInt(0xFFCFEDE3), const PdfColor.fromInt(0xFF2C9B85)),
        pw.SizedBox(width: 12),
        item('Проблема', const PdfColor.fromInt(0xFFFFD7C6), const PdfColor.fromInt(0xFFE36A45)),
        pw.SizedBox(width: 12),
        item('Отсутствует', const PdfColor.fromInt(0xFFE0E5EA), const PdfColor.fromInt(0xFF8A99A3)),
      ],
    );
  }

  static pw.Widget _receiptBlock(
    MedicalRecord record, {
    required String clinicName,
    required String receiptNo,
    required String dateStr,
  }) {
    final price = record.price;
    final priceStr = '${_formatPrice(price)} ₸';
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFF0A4DD3), width: 0.8),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0A4DD3),
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(9),
                topRight: pw.Radius.circular(9),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'КВИТАНЦИЯ ОБ ОПЛАТЕ',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.Text(
                  '№ $receiptNo · $dateStr',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                _receiptRow('Клиника', clinicName),
                _receiptRow('Услуга', record.title),
                _receiptRow('Способ оплаты', 'Наличный / безналичный расчёт'),
                pw.Divider(color: const PdfColor.fromInt(0xFFE2E8F0)),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'ИТОГО К ОПЛАТЕ',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      priceStr,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF0A4DD3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _receiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF6B7A8F)),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureBlock(String doctorName) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                height: 50,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF6B7A8F), width: 0.6),
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Подпись врача', style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF6B7A8F))),
              pw.Text(doctorName, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        pw.Container(
          width: 110,
          height: 70,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(color: const PdfColor.fromInt(0xFF0A4DD3), width: 1.2),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'М.П.',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF0A4DD3),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Dental AI',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: const PdfColor.fromInt(0xFF0A4DD3),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _footer() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Документ сформирован автоматически в системе Dental AI',
            style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF6B7A8F)),
          ),
          pw.Text(
            _formatDate(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF6B7A8F)),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';

  static String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  static String _formatPrice(double value) {
    final intValue = value.round();
    final str = intValue.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(' ');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}
