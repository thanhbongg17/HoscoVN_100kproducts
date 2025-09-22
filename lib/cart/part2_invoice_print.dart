// -----------------------------------------------------------------------------
// part2_invoice_print.dart
// PHẦN 2: Thông tin ĐƠN (logo, tên cửa hàng, sđt, địa chỉ, mã đơn, ngày HĐ,
// thời gian tạo, nhân viên, tổng giá trị đơn, % giảm giá, tiền giảm, tổng cần
// thanh toán, hình thức thanh toán) + In PDF trên mobile.
// - Import PHẦN 1 để dùng kiểu InvoiceItem.
// -----------------------------------------------------------------------------

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/date_symbol_data_local.dart';


import 'part1_cart_items.dart'; // dùng InvoiceItem
import 'package:pdf/widgets.dart' show PdfGoogleFonts;


// =========================== MODEL ĐƠN/HÓA ĐƠN ============================
class Invoice {
  // Cửa hàng
  final String tenCuaHang;
  final String soDienThoai;
  final String diaChi;
  final Uint8List? logoBytes;

  // Đơn
  final String maDon;
  final DateTime ngayHoaDon; // ngày hóa đơn
  final DateTime thoiGianTao; // thời gian tạo
  final String nhanVien;
  final List<InvoiceItem> items;

  // Giảm giá toàn đơn
  final double? giamGiaPhanTram; // %
  final double? giamGiaTien;     // VND

  // Thanh toán
  final String hinhThucThanhToan;

  const Invoice({
    required this.tenCuaHang,
    required this.soDienThoai,
    required this.diaChi,
    this.logoBytes,
    required this.maDon,
    required this.ngayHoaDon,
    required this.thoiGianTao,
    required this.nhanVien,
    required this.items,
    this.giamGiaPhanTram,
    this.giamGiaTien,
    required this.hinhThucThanhToan,
  });

  double get tongGiaTriDon => _round(items.fold(0.0, (s, it) => s + it.thanhTien));

  double get tienGiamDon {
    if (giamGiaTien != null) return _round(giamGiaTien!);
    final pct = (giamGiaPhanTram ?? 0) / 100.0;
    return _round(tongGiaTriDon * pct);
  }

  double get tongCanThanhToan => _round((tongGiaTriDon - tienGiamDon).clamp(0.0, double.infinity));
}

// =============================== IN ẤN PDF ================================
Future<void> printInvoice(Invoice invoice) async {
  try { await initializeDateFormatting('vi_VN'); } catch (_) {}
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async {
      try {
        return await _buildInvoicePdf(invoice, format: PdfPageFormat.a5);
      } catch (e, st) {
        debugPrint('PDF build error: $e\n$st');
        // Fallback PDF: chỉ dùng ASCII để không cần font ngoài
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a5,
            build: (_) => pw.Center(
              child: pw.Text(
                'PDF build error: $e\nCheck fonts & assets in pubspec.yaml',
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),
        );
        return doc.save();
      }
    },
  );
}


Future<Uint8List> _buildInvoicePdf(Invoice invoice, {required PdfPageFormat format}) async {
  // Font có dấu TV
  // final fontRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  // final fontBold    = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  // final fontItalic  = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Italic.ttf'));
  //
  // final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold, italic: fontItalic);
  // Font có dấu TV (không cần assets)
  final fontRegular = await PdfGoogleFonts.robotoRegular();
  final fontBold    = await PdfGoogleFonts.robotoBold();
  final fontItalic  = await PdfGoogleFonts.robotoItalic();

  final theme = pw.ThemeData.withFont(
    base: fontRegular, bold: fontBold, italic: fontItalic,
  );

  final doc = pw.Document();
  final dateFmt = DateFormat('dd/MM/yyyy', 'vi_VN');
  final timeFmt = DateFormat('HH:mm', 'vi_VN');

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        theme: theme,
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      build: (context) => [
        _header(invoice, dateFmt, timeFmt),
        pw.SizedBox(height: 10),
        _itemsTable(invoice),
        pw.SizedBox(height: 10),
        _totalsBlock(invoice),
        pw.SizedBox(height: 14),
        pw.Divider(),
        pw.Center(child: pw.Text('Cảm ơn Quý khách! Hẹn gặp lại.', style: const pw.TextStyle(fontSize: 11))),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _header(Invoice invoice, DateFormat dateFmt, DateFormat timeFmt) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (invoice.logoBytes != null)
            pw.Container(
              width: 52,
              height: 52,
              margin: const pw.EdgeInsets.only(right: 12),
              child: pw.Image(pw.MemoryImage(invoice.logoBytes!), fit: pw.BoxFit.contain),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(invoice.tenCuaHang, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('SĐT: ${invoice.soDienThoai}', style: const pw.TextStyle(fontSize: 11)),
                pw.Text('Đ/c: ${invoice.diaChi}', style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _meta('Mã đơn', invoice.maDon),
          _meta('Ngày HĐ', dateFmt.format(invoice.ngayHoaDon)),
          _meta('Tạo lúc', timeFmt.format(invoice.thoiGianTao)),
          _meta('Nhân viên', invoice.nhanVien),
          _meta('Thanh toán', invoice.hinhThucThanhToan),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Divider(thickness: 1),
    ],
  );
}

pw.Widget _meta(String label, String value) => pw.Expanded(
  child: pw.Padding(
    padding: const pw.EdgeInsets.only(right: 6, bottom: 2),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  ),
);

pw.Widget _itemsTable(Invoice invoice) {
  final money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  final headers = <String>['Mã', 'Tên hàng', 'ĐVT', 'Giá bán', '% CK', 'Tiền CK', 'VAT', 'Thành tiền', 'Ghi chú'];

  final data = invoice.items.map((it) => [
    it.ma,
    it.ten,
    it.dvt,
    money.format(it.giaBan),
    _fmtPct(it.chietKhauPhanTram),
    money.format(it.tienChietKhauItem),
    _fmtPct(it.vatPhanTram),
    money.format(it.thanhTien),
    it.ghiChu ?? '',
  ]).toList();

  final widths = <int, pw.TableColumnWidth>{
    0: const pw.FlexColumnWidth(1.2),
    1: const pw.FlexColumnWidth(2.6),
    2: const pw.FlexColumnWidth(1.1),
    3: const pw.FlexColumnWidth(1.6),
    4: const pw.FlexColumnWidth(1.0),
    5: const pw.FlexColumnWidth(1.6),
    6: const pw.FlexColumnWidth(1.0),
    7: const pw.FlexColumnWidth(1.8),
    8: const pw.FlexColumnWidth(2.2),
  };

  return pw.Table.fromTextArray(
    headers: headers,
    data: data,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellStyle: const pw.TextStyle(fontSize: 10),
    cellAlignment: pw.Alignment.centerLeft,
    columnWidths: widths,
    cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
    border: pw.TableBorder.symmetric(outside: const pw.BorderSide(color: PdfColors.grey400)),
  );
}

pw.Widget _totalsBlock(Invoice invoice) {
  final money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  pw.Widget line(String label, String value, {bool bold = false}) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    ],
  );

  final rows = <pw.Widget>[
    line('Tổng giá trị đơn', money.format(invoice.tongGiaTriDon)),
  ];
  if (invoice.giamGiaPhanTram != null) {
    rows.add(line('% giảm giá', _fmtPct(invoice.giamGiaPhanTram)));
  }
  rows.add(line('Tiền giảm', money.format(invoice.tienGiamDon)));
  rows.add(pw.Divider());
  rows.add(line('TỔNG CẦN THANH TOÁN', money.format(invoice.tongCanThanhToan), bold: true));

  return pw.Container(
    alignment: pw.Alignment.centerRight,
    child: pw.ConstrainedBox(
      constraints: const pw.BoxConstraints(maxWidth: 260),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: rows),
    ),
  );
}

String _fmtPct(num? v) => v == null ? '-' : '${_round(v.toDouble())}%';

double _round(double v) => (v * 100).roundToDouble() / 100.0;

// Parse number helper (chấp nhận dấu , hoặc .)
double? _parseDoubleOrNull(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

// ============================== CHECKOUT UI ===============================
/// Nhận [items] từ PHẦN 1 để nhập meta đơn & in hóa đơn.
class CheckoutPage extends StatefulWidget {
  final List<InvoiceItem> items;
  final Uint8List? logoBytes;

  // Giá trị mặc định thuận tiện
  final String? defaultStoreName;
  final String? defaultPhone;
  final String? defaultAddress;
  final String? defaultNhanVien;

  const CheckoutPage({
    super.key,
    required this.items,
    this.logoBytes,
    this.defaultStoreName,
    this.defaultPhone,
    this.defaultAddress,
    this.defaultNhanVien,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController tenCuaHang;
  late final TextEditingController soDienThoai;
  late final TextEditingController diaChi;
  late final TextEditingController maDon;
  late final TextEditingController nhanVien;
  late final TextEditingController giamGiaPct;
  late final TextEditingController giamGiaTien;
  String hinhThucThanhToan = 'Tiền mặt';

  @override
  void initState() {
    super.initState();
    tenCuaHang = TextEditingController(text: widget.defaultStoreName ?? 'Cửa hàng SOD');
    soDienThoai = TextEditingController(text: widget.defaultPhone ?? '0901 234 567');
    diaChi = TextEditingController(text: widget.defaultAddress ?? '123 Đường ABC, Q.1, TP.HCM');
    maDon = TextEditingController(text: _suggestOrderCode());
    nhanVien = TextEditingController(text: widget.defaultNhanVien ?? 'Thành');
    giamGiaPct = TextEditingController();
    giamGiaTien = TextEditingController();
  }

  @override
  void dispose() {
    tenCuaHang.dispose(); soDienThoai.dispose(); diaChi.dispose(); maDon.dispose(); nhanVien.dispose();
    giamGiaPct.dispose(); giamGiaTien.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final subtotal = widget.items.fold(0.0, (s, it) => s + it.thanhTien);

    return Scaffold(
      appBar: AppBar(title: const Text('Bước 2: Xác nhận & In')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('Thông tin cửa hàng', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _tf(tenCuaHang, label: 'Tên cửa hàng', required: true),
            _tf(soDienThoai, label: 'Số điện thoại', required: true),
            _tf(diaChi, label: 'Địa chỉ', required: true),
            const SizedBox(height: 12),
            const Text('Thông tin đơn', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _tf(maDon, label: 'Mã đơn', required: true),
            _tf(nhanVien, label: 'Nhân viên', required: true),
            Row(children: [
              Expanded(child: _tf(giamGiaPct, label: '% giảm giá (toàn đơn)', keyboard: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _tf(giamGiaTien, label: 'Tiền giảm (VND)', keyboard: TextInputType.number)),
            ]),
            _hint('Chỉ nhập **một** trong hai trường giảm giá (ưu tiên Tiền giảm).'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: hinhThucThanhToan,
              decoration: const InputDecoration(labelText: 'Hình thức thanh toán', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Tiền mặt', child: Text('Tiền mặt')),
                DropdownMenuItem(value: 'Chuyển khoản', child: Text('Chuyển khoản')),
                DropdownMenuItem(value: 'QR', child: Text('QR')),
                DropdownMenuItem(value: 'Thẻ', child: Text('Thẻ')),
              ],
              onChanged: (v) => setState(() => hinhThucThanhToan = v ?? 'Tiền mặt'),
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tổng giá trị đơn (từ Bước 1): ${money.format(subtotal)}'),
                  Text('Ước tính Tổng cần thanh toán (sau giảm): ${money.format(_estimateTotal(subtotal))}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _onPrint,
              icon: const Icon(Icons.print),
              label: const Text('In hoá đơn'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------ actions ------------------------------
  Future<void> _onPrint() async {
    if (!_formKey.currentState!.validate()) return;

    final giamTien = _parseDoubleOrNull(giamGiaTien.text);
    final giamPct = giamTien != null ? null : _parseDoubleOrNull(giamGiaPct.text);

    final invoice = Invoice(
      tenCuaHang: tenCuaHang.text.trim(),
      soDienThoai: soDienThoai.text.trim(),
      diaChi: diaChi.text.trim(),
      logoBytes: widget.logoBytes,
      maDon: maDon.text.trim(),
      ngayHoaDon: DateTime.now(),
      thoiGianTao: DateTime.now(),
      nhanVien: nhanVien.text.trim(),
      items: widget.items,
      giamGiaPhanTram: giamPct == null ? null : giamPct.clamp(0, 100).toDouble(),
      giamGiaTien: giamTien == null ? null : giamTien.clamp(0, double.infinity).toDouble(),
      hinhThucThanhToan: hinhThucThanhToan,
    );

    await printInvoice(invoice);
  }

  // ------------------------------ helpers ------------------------------
  double _estimateTotal(double subtotal) {
    final giamTien = _parseDoubleOrNull(giamGiaTien.text);
    if (giamTien != null) return (subtotal - giamTien).clamp(0.0, double.infinity).toDouble();
    final pct = _parseDoubleOrNull(giamGiaPct.text) ?? 0;
    return subtotal - subtotal * (pct / 100.0);
  }

  String _suggestOrderCode() {
    final now = DateTime.now();
    return 'HD${DateFormat('yyMMdd-HHmm').format(now)}';
  }

  Widget _tf(TextEditingController c, {required String label, bool required = false, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) return 'Bắt buộc';
          if (keyboard == TextInputType.number && v != null && v.trim().isNotEmpty) {
            if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Sai định dạng số';
          }
          return null;
        },
      ),
    );
  }

  Widget _hint(String s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(s, style: const TextStyle(color: Colors.grey)),
  );

  Widget _card({required Widget child}) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );
}

// ========================== STANDALONE TEST ==========================
// Chạy riêng file này:
// flutter run -t lib/part2_invoice_print.dart
// ========================== STANDALONE TEST ==========================
// flutter run -t lib/part2_invoice_print.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN'); // nạp dữ liệu locale VI

  final demoItems = <InvoiceItem>[
    InvoiceItem(ma: 'SP001', ten: 'Bút bi TL-079', dvt: 'cây', giaBan: 6500, chietKhauPhanTram: 10, vatPhanTram: 8, ghiChu: 'Mực xanh'),
    InvoiceItem(ma: 'SP002', ten: 'Tập 200 trang', dvt: 'quyển', giaBan: 23000, chietKhauTien: 2000, vatPhanTram: 8),
    InvoiceItem(ma: 'SP010', ten: 'Kéo 8"', dvt: 'cái', giaBan: 32000, vatPhanTram: 8),
  ];

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
    home: CheckoutPage(items: demoItems),
  ));
}


// ============================== GHI CHÚ ASSETS =============================
// pubspec.yaml cần thêm:
// dependencies:
//   pdf: ^3.11.0
//   printing: ^5.13.4
//   intl: ^0.19.0
// flutter:
//   assets:
//     - assets/logo.png
//     - assets/fonts/Roboto-Regular.ttf
//     - assets/fonts/Roboto-Bold.ttf
//     - assets/fonts/Roboto-Italic.ttf
// Nếu in khổ cuộn 80mm: thay PdfPageFormat.a5 bằng PdfPageFormat.roll80 trong print.
