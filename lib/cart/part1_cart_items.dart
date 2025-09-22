// -----------------------------------------------------------------------------
// part1_cart_items.dart
// PHẦN 1: Giỏ hàng sản phẩm (mã, tên, ĐVT, giá bán, %CK, tiền CK, VAT, thành tiền, ghi chú)
// - Độc lập, KHÔNG import Phần 2. Trả dữ liệu ra List<InvoiceItem> để Phần 2 dùng.
// - Cung cấp CartController + CartWidget (UI) + ItemFormPage (thêm/sửa dòng hàng).
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ============================ MODEL DÒNG HÀNG =============================
class InvoiceItem {
  final String ma;             // Mã hàng
  final String ten;            // Tên hàng
  final String dvt;            // Đơn vị tính
  final double giaBan;         // Giá bán (đơn giá)
  final double? chietKhauPhanTram; // % chiết khấu ở dòng
  final double? chietKhauTien;     // tiền chiết khấu ở dòng
  final double? vatPhanTram;       // VAT % ở dòng
  final String? ghiChu;            // ghi chú hàng

  const InvoiceItem({
    required this.ma,
    required this.ten,
    required this.dvt,
    required this.giaBan,
    this.chietKhauPhanTram,
    this.chietKhauTien,
    this.vatPhanTram,
    this.ghiChu,
  });

  double get tienChietKhauItem {
    if (chietKhauTien != null) return _round(chietKhauTien!);
    final pct = (chietKhauPhanTram ?? 0) / 100.0;
    return _round(giaBan * pct);
  }

  double get giaSauCKTruocVAT => _round(giaBan - tienChietKhauItem);

  double get tienVATItem {
    final vatPct = (vatPhanTram ?? 0) / 100.0;
    return _round(giaSauCKTruocVAT * vatPct);
  }

  double get thanhTien => _round(giaSauCKTruocVAT + tienVATItem);
}

// ============================= CART CONTROLLER ============================
class CartController extends ChangeNotifier {
  final List<InvoiceItem> items;
  CartController({List<InvoiceItem>? initialItems}) : items = [...?initialItems];

  final money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  double get subtotal => items.fold(0.0, (s, it) => s + it.thanhTien);

  void addItem(InvoiceItem it) {
    items.add(it);
    notifyListeners();
  }

  void updateItem(int index, InvoiceItem it) {
    items[index] = it;
    notifyListeners();
  }

  void removeAt(int index) {
    items.removeAt(index);
    notifyListeners();
  }

  void clear() {
    items.clear();
    notifyListeners();
  }
}

// ================================ CART UI =================================
/// CartWidget độc lập, giao tiếp qua callback [onProceed].
/// Ứng dụng của bạn sẽ chuyển sang PHẦN 2 khi nhận được [items].
class CartWidget extends StatefulWidget {
  final List<InvoiceItem>? initialItems;
  final void Function(List<InvoiceItem> items) onProceed;

  const CartWidget({super.key, this.initialItems, required this.onProceed});

  @override
  State<CartWidget> createState() => _CartWidgetState();
}

class _CartWidgetState extends State<CartWidget> {
  late final CartController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = CartController(initialItems: widget.initialItems);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final money = ctrl.money;
        return Scaffold(
          appBar: AppBar(title: const Text('Bước 1: Giỏ hàng')),
          body: ctrl.items.isEmpty
              ? const Center(child: Text('Chưa có sản phẩm. Nhấn “+” để thêm.'))
              : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: ctrl.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = ctrl.items[i];
              return ListTile(
                title: Text('${it.ma} • ${it.ten}'),
                subtitle: Text(
                  'ĐVT: ${it.dvt} | Giá: ${money.format(it.giaBan)} | VAT: ${_fmtPct(it.vatPhanTram)}\n'
                      '%CK: ${_fmtPct(it.chietKhauPhanTram)} | Tiền CK: ${money.format(it.tienChietKhauItem)}'
                      '${it.ghiChu == null ? '' : '\nGhi chú: ${it.ghiChu}'}',
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money.format(it.thanhTien),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final edited = await Navigator.push<InvoiceItem>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ItemFormPage(original: it),
                              ),
                            );
                            if (edited != null) ctrl.updateItem(i, edited);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => ctrl.removeAt(i),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final item = await Navigator.push<InvoiceItem>(
                context,
                MaterialPageRoute(builder: (_) => const ItemFormPage()),
              );
              if (item != null) ctrl.addItem(item);
            },
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('TẠM TÍNH: ' + money.format(ctrl.subtotal),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  FilledButton.icon(
                    onPressed: ctrl.items.isEmpty
                        ? null
                        : () => widget.onProceed(List<InvoiceItem>.unmodifiable(ctrl.items)),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Bước 2'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================= ITEM FORM PAGE ============================
class ItemFormPage extends StatefulWidget {
  final InvoiceItem? original;
  const ItemFormPage({super.key, this.original});

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController ma;
  late final TextEditingController ten;
  late final TextEditingController dvt;
  late final TextEditingController giaBan;
  late final TextEditingController ckPct;
  late final TextEditingController ckTien;
  late final TextEditingController vatPct;
  late final TextEditingController ghiChu;

  @override
  void initState() {
    super.initState();
    final it = widget.original;
    ma = TextEditingController(text: it?.ma ?? '');
    ten = TextEditingController(text: it?.ten ?? '');
    dvt = TextEditingController(text: it?.dvt ?? '');
    giaBan = TextEditingController(text: it?.giaBan.toString() ?? '');
    ckPct = TextEditingController(text: it?.chietKhauPhanTram?.toString() ?? '');
    ckTien = TextEditingController(text: it?.chietKhauTien?.toString() ?? '');
    vatPct = TextEditingController(text: it?.vatPhanTram?.toString() ?? '');
    ghiChu = TextEditingController(text: it?.ghiChu ?? '');
  }

  @override
  void dispose() {
    ma.dispose(); ten.dispose(); dvt.dispose(); giaBan.dispose();
    ckPct.dispose(); ckTien.dispose(); vatPct.dispose(); ghiChu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.original == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _tf(ma, label: 'Mã hàng', required: true),
            _tf(ten, label: 'Tên hàng', required: true),
            _tf(dvt, label: 'Đơn vị tính', required: true),
            _tf(giaBan, label: 'Giá bán', required: true, keyboard: TextInputType.number),
            Row(children: [
              Expanded(child: _tf(ckPct, label: '% chiết khấu', keyboard: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _tf(ckTien, label: 'Tiền chiết khấu', keyboard: TextInputType.number)),
            ]),
            _hint('Điền **một** trong hai trường CK: % hoặc tiền (để trống trường còn lại).'),
            _tf(vatPct, label: 'Thuế VAT (%)', keyboard: TextInputType.number),
            _tf(ghiChu, label: 'Ghi chú (tuỳ chọn)'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final ckPctVal = _parseDoubleOrNull(ckPct.text);
                  final ckTienVal = _parseDoubleOrNull(ckTien.text);
                  final vatVal = _parseDoubleOrNull(vatPct.text);
                  final item = InvoiceItem(
                    ma: ma.text.trim(),
                    ten: ten.text.trim(),
                    dvt: dvt.text.trim(),
                    giaBan: _parseDouble(giaBan.text),
                    chietKhauPhanTram: ckPctVal?.clamp(0, 100),
                    chietKhauTien: ckTienVal?.clamp(0, double.infinity),
                    vatPhanTram: vatVal?.clamp(0, 100),
                    ghiChu: ghiChu.text.trim().isEmpty ? null : ghiChu.text.trim(),
                  );
                  Navigator.pop(context, item);
                }
              },
              icon: const Icon(Icons.check),
              label: Text(widget.original == null ? 'Thêm vào giỏ' : 'Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------- helpers ----------------------
  Widget _tf(TextEditingController c, {required String label, bool required = false, TextInputType? keyboard}) {
    return TextFormField(
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
    );
  }

  Widget _hint(String s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(s, style: const TextStyle(color: Colors.grey)),
  );
}

// ============================== UTILS ===============================
String _fmtPct(num? v) => v == null ? '-' : '${_round(v.toDouble())}%';

double _parseDouble(String s) => double.parse(s.trim().replaceAll(',', '.'));

double? _parseDoubleOrNull(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

double _round(double v) => (v * 100).roundToDouble() / 100.0;
////////////////////////run app
// ========================== STANDALONE TEST ==========================
// Chạy riêng file này:
// flutter run -t lib/part1_cart_items.dart
void main() {
  runApp(const _CartStandaloneApp());
}

class _CartStandaloneApp extends StatelessWidget {
  const _CartStandaloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: CartWidget(
        onProceed: (items) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _CartPreview(items: items),
          ));
        },
      ),
    );
  }
}

class _CartPreview extends StatelessWidget {
  final List<InvoiceItem> items;
  const _CartPreview({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final subtotal = items.fold(0.0, (s, it) => s + it.thanhTien);
    return Scaffold(
      appBar: AppBar(title: const Text('Xem nhanh giỏ hàng')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Số dòng: ${items.length}'),
          const SizedBox(height: 6),
          Text(
            'Tạm tính: ${money.format(subtotal)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
