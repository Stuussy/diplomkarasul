import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/treatment_plan.dart';

class TreatmentPlanPdfBuilder {
  static Future<Uint8List> build(TreatmentPlan plan) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();

    final theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
    );

    final doc = pw.Document(theme: theme);

    final patientName = plan.patient?.fullName ?? '—';
    final patientPhone = plan.patient?.phone;
    final doctorName = plan.doctor?.fullName ?? '—';
    final doctorSpec = plan.doctor?.specialties.join(', ') ?? '';
    final dateStr = plan.createdAt != null ? _formatDate(plan.createdAt!) : _formatDate(DateTime.now());
    final planNo = plan.id.length >= 6
        ? plan.id.substring(plan.id.length - 6).toUpperCase()
        : plan.id.toUpperCase();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
        build: (context) => [
          // 1. Header
          _header(planNo, dateStr),
          pw.SizedBox(height: 18),
          // 2. Patient/Doctor block
          _patientDoctorBlock(
            patientName: patientName,
            patientPhone: patientPhone,
            doctorName: doctorName,
            doctorSpec: doctorSpec,
            dateStr: dateStr,
          ),
          pw.SizedBox(height: 16),
          // 3. Diagnosis
          if (plan.diagnosis.isNotEmpty) ...[
            _section('Диагноз', plan.diagnosis),
            pw.SizedBox(height: 12),
          ],
          // 4. AI note
          if (plan.aiGenerated) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFF4E0),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFFFB347), width: 0.6),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 6,
                    height: 6,
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFFB347),
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'Этот план составлен с помощью ИИ и проверен врачом.',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: const PdfColor.fromInt(0xFF8A6000),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          // 5. Steps table
          _sectionTitle('Этапы лечения'),
          pw.SizedBox(height: 8),
          _stepsTable(plan.steps),
          pw.SizedBox(height: 14),
          // 6. Summary row
          _summaryRow(plan),
          pw.SizedBox(height: 16),
          // 7. Recommendations
          if (plan.summary.isNotEmpty) ...[
            _section('Рекомендации', plan.summary),
            pw.SizedBox(height: 16),
          ],
          // 8. Signature
          _signatureBlock(doctorName),
          pw.SizedBox(height: 18),
          // 9. Footer
          _footer(),
        ],
      ),
    );

    return doc.save();
  }

  // ---- Building blocks ----

  static pw.Widget _header(String planNo, String dateStr) {
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
                  'Dental AI',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Стоматологическая клиника',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'ПЛАН ЛЕЧЕНИЯ',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '№ $planNo',
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
            title: 'Дата составления',
            lines: [dateStr],
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

  static pw.Widget _stepsTable(List<TreatmentStep> steps) {
    const headerBg = PdfColor.fromInt(0xFF0A4DD3);
    const rowAlt = PdfColor.fromInt(0xFFF4F8FE);

    pw.Widget headerCell(String text) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );

    pw.Widget cell(String text, {bool bold = false, pw.Alignment align = pw.Alignment.centerLeft}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: align,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FixedColumnWidth(46),
        4: const pw.FixedColumnWidth(70),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: headerBg),
          children: [
            headerCell('№'),
            headerCell('Процедура'),
            headerCell('Описание'),
            headerCell('Срок'),
            headerCell('Цена'),
          ],
        ),
        // Data rows
        ...steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : rowAlt,
            ),
            children: [
              cell('${step.order}', align: pw.Alignment.center),
              cell(step.procedure, bold: true),
              cell(step.description.isNotEmpty ? step.description : '—'),
              cell('${step.durationDays} дн.', align: pw.Alignment.center),
              cell('${_formatPrice(step.price)} ₸', align: pw.Alignment.centerRight),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _summaryRow(TreatmentPlan plan) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _infoCard(
            title: 'Общая стоимость',
            lines: ['${_formatPrice(plan.totalCost)} ₸'],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _infoCard(
            title: 'Общий срок',
            lines: ['${plan.totalDurationDays} дней'],
          ),
        ),
      ],
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
              pw.Text('Подпись врача',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF6B7A8F))),
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
