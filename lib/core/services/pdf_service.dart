import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart';
import 'package:prepvault_ai/features/summary/models/summary_model.dart';

class PdfService {
  
  // ===========================================================================
  // 1️⃣ CONSTANTS & COLORS
  // ===========================================================================
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF6366F1);
  static const PdfColor accentColor = PdfColor.fromInt(0xFFEEF2FF);
  static const PdfColor successColor = PdfColor.fromInt(0xFF22C55E);
  static const PdfColor errorColor = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor darkText = PdfColor.fromInt(0xFF1E293B);

  // ===========================================================================
  // 2️⃣ QUIZ REPORT GENERATION
  // ===========================================================================
  static Future<void> generateQuizReport(List<QuizQuestion> questions, int score, int total) async {
      debugPrint("🖨️ [PDF] Generating Quiz Result Report...");
      
      final pdf = pw.Document();
      final fontRegular = await PdfGoogleFonts.openSansRegular();
      final fontBold = await PdfGoogleFonts.openSansBold();
      final percentage = (score / total) * 100;

      pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("PrepVault AI", style: pw.TextStyle(color: primaryColor, fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text("Quiz Report", style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
            ],
          ),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: accentColor,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: primaryColor, width: 1),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildScoreStat("Total Questions", "$total", fontBold),
                _buildScoreStat("Your Score", "$score", fontBold),
                _buildScoreStat("Percentage", "${percentage.toStringAsFixed(1)}%", fontBold, 
                  color: percentage >= 50 ? successColor : errorColor),
              ],
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Text("Detailed Analysis", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          ...questions.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final q = entry.value;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 15),
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Q$index: ${q.question}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  if (q.options.isNotEmpty)
                    ...List.generate(q.options.length, (optIdx) {
                      final isCorrect = optIdx == q.correctAnswerIndex;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 6, height: 6,
                              decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: isCorrect ? successColor : PdfColors.grey400),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Text(
                              q.options[optIdx],
                              style: pw.TextStyle(
                                color: isCorrect ? successColor : darkText,
                                fontWeight: isCorrect ? pw.FontWeight.bold : pw.FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          }),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Quiz_Report.pdf');
  }

  // ===========================================================================
  // 3️⃣ SUMMARY DOCUMENT GENERATION
  // ===========================================================================
  static Future<void> generateSummaryDocument(SummaryModel data) async {
      debugPrint("🖨️ [PDF] Generating Summary Document...");
      
      final pdf = pw.Document();
      final fontRegular = await PdfGoogleFonts.openSansRegular();
      final fontBold = await PdfGoogleFonts.openSansBold();
      
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(40), theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold)),
          build: (context) => [
            pw.Header(level: 0, child: pw.Text("EXECUTIVE SUMMARY", style: pw.TextStyle(color: primaryColor, fontSize: 14, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),
            pw.Text(data.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Text(data.summaryMarkdown.replaceAll('#', '').replaceAll('*', ''), style: const pw.TextStyle(fontSize: 12, lineSpacing: 5)),
          ],
        ),
      );
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Summary.pdf');
  }

  // ===========================================================================
  // 4️⃣ MCQ EXAM PAPER (Updated to accept orgName)
  // ===========================================================================
  static Future<void> generateExamPaper(
    List<QuizQuestion> questions, 
    String topic, 
    {String? orgName, bool withAnswers = false} // 🔥 ADDED orgName BACK
  ) async {
    // If no options (Theory), delegate to Theory Generator
    if (questions.isNotEmpty && questions.first.options.isEmpty) {
      return generateTheoryPaper(questions, topic, orgName: orgName, withAnswers: withAnswers);
    }
    
    // ... (Agar aapko MCQ logic chahiye to purana wala use karein, 
    // main yahan focus Theory/Integration par kar raha hu. 
    // Agar Dashboard MCQ call kar raha hai, to main niche basic implementation de raha hu)

    debugPrint("🖨️ [PDF] Generating MCQ Exam Paper...");
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    final headerTitle = (orgName != null && orgName.isNotEmpty) ? orgName.toUpperCase() : "PrepVault AI - EXAM PORTAL";

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(40), theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold)),
        build: (context) => [
           pw.Center(child: pw.Column(children: [
             pw.Text(headerTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor)),
             pw.Text("Topic: $topic"),
           ])),
           pw.SizedBox(height: 20),
           // Basic Loop for MCQs if needed...
           ...questions.asMap().entries.map((e) => pw.Text("Q${e.key+1}: ${e.value.question}")),
        ]
      )
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'MCQ_Paper.pdf');
  }

  // ===========================================================================
  // 5️⃣ THEORY EXAM PAPER (For Question Set)
  // ===========================================================================
  static Future<void> generateTheoryPaper(
    List<QuizQuestion> questions, 
    String topic, 
    {String? orgName, bool withAnswers = false} // 🔥 Added orgName here too
  ) async {
    
    debugPrint("🖨️ [PDF] Generating Theory Exam Paper (Solved: $withAnswers)...");
    
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    // 🔥 Dynamic Header Title
    final headerTitle = (orgName != null && orgName.isNotEmpty) 
        ? orgName.toUpperCase() 
        : "PrepVault AI - THEORY EXAM";

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        build: (context) => [
          // --- HEADER ---
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(headerTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.SizedBox(height: 5),
                pw.Text("Topic: $topic", style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                if (withAnswers)
                  pw.Text("(Teacher's Key & Solutions)", style: pw.TextStyle(fontSize: 10, color: successColor, fontWeight: pw.FontWeight.bold)),
              ],
            )
          ),
          pw.SizedBox(height: 20),

          // --- STUDENT DETAILS (Only if Unsolved) ---
          if (!withAnswers) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Name: __________________________"),
                  pw.Text("Marks Obtained: ____ / ${questions.length * 5}"),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text("Instructions: Answer all questions in detail.", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            pw.Divider(),
          ],

          // --- QUESTIONS LOOP ---
          ...questions.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final q = entry.value;
            final marks = q.marks ?? 5; 

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 25),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Question Header
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Q$index: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Expanded(child: pw.Text(q.question, style: const pw.TextStyle(fontSize: 12))),
                      pw.SizedBox(width: 10),
                      pw.Text("[$marks Marks]", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 10),

                  // 🔥 SOLVED MODE: Show Model Answer
                  if (withAnswers)
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        border: pw.Border(left: pw.BorderSide(color: successColor, width: 3)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Model Answer:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: successColor)),
                          pw.SizedBox(height: 4),
                          pw.Text(q.answer ?? "Answer not provided.", style: const pw.TextStyle(fontSize: 10, color: darkText)),
                        ],
                      ),
                    )
                  
                  // 📝 UNSOLVED MODE: Show Lines for writing
                  else
                    pw.Container(
                      height: 100, // Space for writing
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                        children: List.generate(4, (_) => pw.Divider(color: PdfColors.grey300, thickness: 0.5)),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: withAnswers ? 'Theory_Key.pdf' : 'Theory_Exam.pdf');
  }

  // Helper Widget
  static pw.Widget _buildScoreStat(String label, String value, pw.Font font, {PdfColor? color}) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: color ?? primaryColor)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ],
    );
  }
}