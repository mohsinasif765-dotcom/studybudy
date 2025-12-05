// ❌ import 'dart:typed_data'; // Yeh line hata di
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:studybudy_ai/features/quiz/models/quiz_model.dart';
import 'package:studybudy_ai/features/summary/models/summary_model.dart';

class PdfService {
  
  // 🎨 COLORS
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF6366F1); // Indigo
  static const PdfColor accentColor = PdfColor.fromInt(0xFFEEF2FF);  // Light Blue
  static const PdfColor successColor = PdfColor.fromInt(0xFF22C55E); // Green
  static const PdfColor errorColor = PdfColor.fromInt(0xFFEF4444);   // Red
  static const PdfColor darkText = PdfColor.fromInt(0xFF1E293B);

  // ==========================================
  // 1. 🎓 QUIZ REPORT (Student Result)
  // ==========================================
  static Future<void> generateQuizReport(List<QuizQuestion> questions, int score, int total) async {
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
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("StudyBuddy AI", style: pw.TextStyle(color: primaryColor, fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text("Quiz Report", style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
            ],
          ),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 20),

          // Score Card
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

          // Detailed Analysis
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
                  
                  // Options List
                  ...List.generate(q.options.length, (optIdx) {
                    final isCorrect = optIdx == q.correctAnswerIndex;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 6, height: 6,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              color: isCorrect ? successColor : PdfColors.grey400
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            q.options[optIdx],
                            style: pw.TextStyle(
                              color: isCorrect ? successColor : darkText,
                              fontWeight: isCorrect ? pw.FontWeight.bold : pw.FontWeight.normal,
                            ),
                          ),
                          if (isCorrect) 
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 5),
                              child: pw.Text("(Correct Answer)", style: pw.TextStyle(color: successColor, fontSize: 8)),
                            )
                        ],
                      ),
                    );
                  }),
                  
                  pw.SizedBox(height: 5),
                  pw.Text("Explanation: ${q.explanation}", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
                ],
              ),
            );
          }),
          
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Center(child: pw.Text("Generated by StudyBuddy AI", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Quiz_Result.pdf');
  }

  // ==========================================
  // 2. 📄 SUMMARY DOCUMENT (Executive Summary)
  // ==========================================
  static Future<void> generateSummaryDocument(SummaryModel data) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("EXECUTIVE SUMMARY", style: pw.TextStyle(color: primaryColor, letterSpacing: 2, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text(data.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              // Emoji removed or replaced if causing font issues, usually needs specialized font
              // pw.Text(data.emoji, style: const pw.TextStyle(fontSize: 30)), 
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: pw.BoxDecoration(color: accentColor, borderRadius: pw.BorderRadius.circular(4)), child: pw.Text("Read Time: ${data.readingTime}", style: const pw.TextStyle(fontSize: 10, color: primaryColor))),
              pw.SizedBox(width: 10),
              pw.Text(DateTime.now().toString().split(' ')[0], style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          ),
          pw.Divider(thickness: 2, color: primaryColor),
          pw.SizedBox(height: 20),

          // Key Points
          pw.Text("Key Takeaways", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          ...data.keyPoints.map((point) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("• ", style: pw.TextStyle(color: primaryColor, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Expanded(child: pw.Text(point, style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
          )),
          
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 20),

          // Full Summary
          pw.Text("Detailed Summary", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text(
            data.summaryMarkdown.replaceAll('#', '').replaceAll('*', ''), 
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 5, color: PdfColors.grey800),
            textAlign: pw.TextAlign.justify
          ),

          // Footer
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("StudyBuddy AI - Smart Learning", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text("Page ${context.pageNumber} of ${context.pagesCount}", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ],
          )
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Summary_${data.title}.pdf');
  }

  // ==========================================
  // 3. 📝 EXAM PAPER (Teacher Mode - Blank)
  // ==========================================
  static Future<void> generateExamPaper(List<QuizQuestion> questions, String topic) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    // --- PAGE 1: QUESTION PAPER ---
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        build: (context) => [
          // Header
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text("STUDYBUDDY AI - EXAM PORTAL", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.SizedBox(height: 5),
                pw.Text("Topic: $topic", style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              ],
            )
          ),
          pw.SizedBox(height: 20),

          // Student Details
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Name: __________________________"),
                    pw.Text("Date: ________________"),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Roll No: _______________________"),
                    pw.Text("Max Marks: ${questions.length}"),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Text("Instructions: Select the correct option for each question.", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          pw.Divider(),
          pw.SizedBox(height: 10),

          // Questions (No Answers Marked)
          ...questions.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final q = entry.value;

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Q$index: ${q.question}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.SizedBox(height: 8),
                  
                  pw.Wrap(
                    spacing: 20,
                    runSpacing: 5,
                    children: List.generate(q.options.length, (optIdx) {
                      final optionLabel = ['A', 'B', 'C', 'D'][optIdx];
                      return pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            width: 12, height: 12,
                            margin: const pw.EdgeInsets.only(right: 5),
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              border: pw.Border.all(color: PdfColors.black),
                            ),
                          ),
                          pw.Text("$optionLabel) ${q.options[optIdx]}", style: const pw.TextStyle(fontSize: 11)),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    // --- PAGE 2: TEACHER'S ANSWER KEY ---
    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text("TEACHER'S ANSWER KEY", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: errorColor))),
              pw.SizedBox(height: 10),
              pw.Text("Keep this page confidential.", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              pw.SizedBox(height: 20),
              
              pw.Wrap(
                spacing: 20,
                runSpacing: 10,
                children: questions.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final q = entry.value;
                  final correctOption = ['A', 'B', 'C', 'D'][q.correctAnswerIndex];
                  
                  return pw.Container(
                    width: 80,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      color: accentColor
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text("Q$index", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(correctOption, style: pw.TextStyle(color: primaryColor, fontWeight: pw.FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Exam_Paper_$topic.pdf');
  }

  // Helper Widget for Stats
  static pw.Widget _buildScoreStat(String label, String value, pw.Font font, {PdfColor? color}) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: color ?? primaryColor)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ],
    );
  }
}