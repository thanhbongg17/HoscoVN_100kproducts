import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'task3_api.dart';
import 'package:notifications_app/task3/task3_media_page.dart';
import 'package:flutter/rendering.dart';

class Task3DemoPage extends StatefulWidget {
  const Task3DemoPage({super.key});

  @override
  State<Task3DemoPage> createState() => _Task3DemoPageState();
}

class _Task3DemoPageState extends State<Task3DemoPage> {
  final api = Task3Api();
  final ScrollController _scrollController = ScrollController();

  int _pageSeq = 0;   // guard cho load page
  int _stockSeq = 0;  // guard cho stock
  int page = 1;
  bool isLoadingMore = false;
  bool hasNext = true; // còn trang sau không
  final List<Map<String, dynamic>> data = [];

  // tồn kho theo id + debounce scroll
  final Map<int, int> _stocks = {}; // id -> stock
  Timer? _debounce;
  static const double _itemExtent = 96.0; // chiều cao mỗi item (cố định để tính viewport)
  static const int _prefetch = 8;         // prefetch thêm vài item phía dưới
  static const int _debounceMs = 120;     // debounce khi cuộn

  @override
  void initState() {
    super.initState();
    _loadPage(); // tải trang đầu
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    // Nạp sớm khi kéo xuống và sắp hết nội dung
    if (hasNext && !isLoadingMore && pos.userScrollDirection == ScrollDirection.reverse) {
      if (pos.extentAfter < _itemExtent * 6) {
        _loadPage();
      }
    }

    // Debounce stock cho viewport hiện tại
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), _fetchVisibleStock);
  }


  Future<void> _loadPage() async {
    // 1) Guard sớm
    if (!hasNext || isLoadingMore || !mounted) return;

    // 2) Đánh dấu request “mới nhất” + bật loading (1 lần)
    final mySeq = ++_pageSeq;
    setState(() => isLoadingMore = true);

    List<Map<String, dynamic>>? items;
    try {
      items = await api.loadPageCancellable(page).catchError((e) {
        if (e is DioException && CancelToken.isCancel(e)) return null; // bị hủy do lướt nhanh
        throw e;
      });
    } finally {
      // 3) Nếu widget đã dispose hoặc có request mới hơn → dừng
      if (!mounted || mySeq != _pageSeq) return;

      // 4) GỘP mọi thay đổi state vào 1 lần setState
      setState(() {
        isLoadingMore = false;

        if (items == null) {
          // bị hủy -> không đổi gì thêm
          return;
        }

        if (items!.isEmpty) {
          hasNext = false;                 // trang cuối
        } else {
          data.addAll(items!);             // append data
          page++;                          // sang trang kế
        }
      });

      // 5) Sau khi frame đã render, mới fetch stock cho viewport
      if (mounted && (items?.isNotEmpty ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fetchVisibleStock());
      }
    }
  }



  Future<void> _fetchVisibleStock() async {
    if (!mounted || data.isEmpty) return;

    // Hủy request stock trước đó (nếu người dùng vừa lướt tiếp)
    api.cancelStockRequests();
    final mySeq = ++_stockSeq;

    final vpHeight = MediaQuery.of(context).size.height;
    final first = (_scrollController.offset / _itemExtent)
        .floor()
        .clamp(0, data.length - 1);
    final visibleCount = (vpHeight / _itemExtent).ceil() + _prefetch;
    final last = (first + visibleCount).clamp(0, data.length - 1);

    final ids = <int>[];
    for (int i = first; i <= last; i++) {
      ids.add((data[i]['id'] as num).toInt());
    }
    if (ids.isEmpty) return;

    try {
      final map = await api.loadStockForVisibleIds(ids).catchError((e) {
        if (e is DioException && CancelToken.isCancel(e)) return null;
        throw e;
      });

      if (!mounted || mySeq != _stockSeq || map == null) return;

      setState(() {
        _stocks.addAll(map);
      });
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    api.cancelAll(); // hủy cả page & stock requests đang bay
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = data.length + (isLoadingMore ? 1 : 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Task3 – Infinite Scroll')),
      body: data.isEmpty && isLoadingMore
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        controller: _scrollController,
        itemExtent: _itemExtent, // RẤT QUAN TRỌNG để tính viewport nhanh
        itemCount: totalCount,
        cacheExtent: _itemExtent * 12,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        itemBuilder: (context, i) {
          if (i >= data.length) {
            // loader cuối danh sách
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final p = data[i];
          final id = (p['id'] as num).toInt();

          final imageUrl = p['imageUrl'] as String?;
          final videoUrl = p['videoUrl'] as String?;


          final stock = _stocks[id];

          return Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(width: 0.5, color: Color(0x14000000)),
              ),
            ),
            child: ListTile(
              key: ValueKey('product_$id'),
              leading: imageUrl != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  cacheWidth: (56 * MediaQuery.of(context).devicePixelRatio).round(),
                  cacheHeight: (56 * MediaQuery.of(context).devicePixelRatio).round(),
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, err, __) {
                    debugPrint('IMG ERROR [$imageUrl] -> $err');
                    return const Icon(Icons.broken_image, size: 32);
                  },
                ),
              )
                  : const Icon(Icons.image_not_supported, size: 32),
              title: Text('${p['name']} (ID $id)'),
              subtitle: Text('ĐVT: ${p['unit']}   Giá: ${p['price']}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TonKhoWidget(
                    key: ValueKey('stock_$id'),
                    stock: stock,
                  ),
                  if (videoUrl != null)
                    const Icon(Icons.play_circle_outline, size: 18),
                ],
              ),
              onTap: () {
                if (imageUrl == null && videoUrl == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không có media')),
                  );
                  return;
                }
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => Task3MediaPage(
                    title: '${p['name']} (ID $id)',
                    assets: [
                      if (imageUrl != null) {'type': 'image', 'url': imageUrl},
                      if (videoUrl != null) {'type': 'video', 'url': videoUrl},
                    ],
                  ),
                ));
              },
            ),
          );

        },
      ),
    );
  }
}

// ---- Chỉ HIỂN THỊ, không Timer
class TonKhoWidget extends StatelessWidget {
  final int? stock;
  const TonKhoWidget({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    final s = stock; // promote non-null
    if (s == null) return const Text('Tồn: …');
    if (s <= 0) {
      return const Text(
        'Hết hàng',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
      );
    }
    return Text('Tồn: $s', style: const TextStyle(fontWeight: FontWeight.w600));
  }
}
