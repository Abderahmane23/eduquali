import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../repositories/contracts_repository.dart';

/// Une ligne de facture, quelle qu'en soit l'origine.
///
/// Échéance de contrat, achat d'un cours vidéo, promotion : le professeur et
/// la famille veulent une seule liasse, pas trois formats selon qui a
/// encaissé.
class InvoiceLine {
  const InvoiceLine({
    required this.label,
    required this.date,
    required this.amount,
    this.detail,
  });

  final String label;
  final DateTime date;
  final int amount;
  final String? detail;

  factory InvoiceLine.fromPayment(ContractPaymentItem payment) => InvoiceLine(
    label: payment.contractLabel,
    date: payment.dueOn,
    amount: payment.amount,
    detail: payment.status.label,
  );
}

/// Fabrique la facture PDF d'un compte.
///
/// Le PDF plutôt que l'écran : c'est ce qu'on transmet à un comptable, à une
/// direction, à une administration. Une capture d'écran ne s'archive pas.
abstract final class InvoicePdf {
  static Future<List<int>> build({
    required String accountName,
    required List<InvoiceLine> lines,
    String? subtitle,
    DateTime? issuedOn,
  }) async {
    final date = issuedOn ?? DateTime.now();
    final total = lines.fold<int>(0, (sum, l) => sum + l.amount);
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  AppConstants.appName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Facture du ${Fmt.date(date)}'),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            accountName,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if (subtitle != null) pw.Text(subtitle),
          pw.SizedBox(height: 18),

          if (lines.isEmpty)
            pw.Text('Aucun paiement sur la période.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Objet', 'Détail', 'Montant'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignments: {3: pw.Alignment.centerRight},
              data: [
                for (final line in lines)
                  [
                    Fmt.dateShort(line.date),
                    line.label,
                    line.detail ?? '',
                    Fmt.money(line.amount),
                  ],
              ],
            ),

          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Total  ${Fmt.money(total)}',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 26),
          pw.Text(
            'Document édité par ${AppConstants.appName}. Les montants sont '
            'exprimés en ${AppConstants.currency}.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return document.save();
  }

  /// Nom de fichier lisible, et sans surprise pour le système.
  static String fileName(DateTime date) =>
      'factures-${date.year}-${date.month.toString().padLeft(2, '0')}.pdf';
}
