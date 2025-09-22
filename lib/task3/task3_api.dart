import 'package:dio/dio.dart';
import '../core/env.dart';
import 'dart:async';

class Task3Api {
  Task3Api() {
    _dio.interceptors.add(LogInterceptor(
      request: false, responseHeader: false, responseBody: true, error: true,
    ));
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: Env.task3Base,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
  ));

  CancelToken? _pageToken;
  CancelToken? _stockToken;

  // ===== Simple in-memory caches (giảm gọi mạng lặp) =====
  final Map<int, List<Map<String, dynamic>>> _mediaCache = {}; // productId -> assets
  final Map<int, int> _stockCache = {};                        // productId -> qty


  // ===== Helpers =====
  Future<void> _safePing() async {
    try { await _dio.get('/health'); } catch (_) {/* ignore */}
  }

  static int _asInt(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? def;
  }

  static String _asStr(dynamic v, {String def = ''}) => v?.toString() ?? def;

  static List<Map<String, dynamic>> _asListOfMap(dynamic v) {
    if (v is List) {
      return v.where((e) => e is Map)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }
  static String? _getUrl(Map<String, dynamic> m) {
    final v = m['url'] ?? m['uri'] ?? m['link'];
    return (v == null || v.toString().isEmpty) ? null : v.toString();
  }

  static String? _normalizeUrl(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (u.startsWith('//')) return 'https:$u';
    if (u.startsWith('/')) return '${Env.task3Base}$u';
    return '${Env.task3Base}/$u';
  }


  static String? _pickImageUrl(List<Map<String, dynamic>> assets) {
    if (assets.isEmpty) return null;
    final imgs = assets.where((a) => _asStr(a['type']).toLowerCase() == 'image').toList();
    if (imgs.isEmpty) return null;
    imgs.sort((a, b) => (_asInt(a['sortOrder'])) - (_asInt(b['sortOrder'])));
    final primary = imgs.firstWhere((a) => (a['isPrimary'] == true), orElse: () => imgs.first);
    return _getUrl(primary);
  }

  static String? _pickVideoUrl(List<Map<String, dynamic>> assets) {
    final vids = assets.where((a) => _asStr(a['type']).toLowerCase() == 'video').toList();
    if (vids.isEmpty) return null;
    vids.sort((a, b) => (_asInt(a['sortOrder'])) - (_asInt(b['sortOrder'])));
    final primary = vids.firstWhere((a) => (a['isPrimary'] == true), orElse: () => vids.first);
    return _getUrl(primary);
  }

  // ===============================
  // Load 1 trang: /products + /inventory + /media (cancellable, fault-tolerant)
  // ===============================
  Future<List<Map<String, dynamic>>> loadPageCancellable(
      int page, {
        int size = 10,
      }) async {
    // hủy request cũ (nếu có)
    _pageToken?.cancel('next page');
    _pageToken = CancelToken();

    await _safePing();

    // helper chuẩn hoá URL (để ảnh relative / //cdn thành URL hợp lệ)
    String? norm(String? url) {
      if (url == null) return null;
      final u = url.trim();
      if (u.isEmpty) return null;
      if (u.startsWith('http://') || u.startsWith('https://')) return u;
      if (u.startsWith('//')) return 'https:$u';
      if (u.startsWith('/')) return '${Env.task3Base}$u';
      return '${Env.task3Base}/$u';
    }

    try {
      // 1) /products (bắt buộc)
      final p = await _dio.get(
        '/products',
        queryParameters: {'page': page, 'size': size},
        cancelToken: _pageToken,
      );

      final body = p.data;
      if (body is! Map || body['items'] is! List) {
        return const [];
      }

      final items = (body['items'] as List)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // dedupe đề phòng backend trả trùng id
      final ids = ((body['ids'] is List)
          ? (body['ids'] as List).map((e) => _asInt(e))
          : items.map((e) => _asInt(e['id'])))
          .where((x) => x > 0)
          .toSet()
          .toList();

      // 2) map tạm + fill từ cache media
      final Map<int, int> stockById = {};
      final Map<int, List<Map<String, dynamic>>> assetsById = {};

      for (final id in ids) {
        final cached = _mediaCache[id];
        if (cached != null) assetsById[id] = cached;
      }
      final needMedia = ids.where((id) => !_mediaCache.containsKey(id)).toList();

      // 3) gọi inventory + (media nếu còn thiếu) song song
      final futures = <Future<dynamic>>[
        _dio
            .get('/inventory',
            queryParameters: {'ids': ids.join(',')}, cancelToken: _pageToken)
            .then((r) => r.data)
            .catchError((_) => null),
        if (needMedia.isNotEmpty)
          _dio
              .get('/media',
              queryParameters: {'ids': needMedia.join(',')},
              cancelToken: _pageToken)
              .then((r) => r.data)
              .catchError((_) => null),
      ];

      final results = await Future.wait(futures, eagerError: false);
      final invData = results.isNotEmpty ? results[0] : null;
      final medData = (results.length >= 2) ? results[1] : null;

      // 3a) parse inventory: { results: [ {id, stock}, ... ] }
      if (invData is Map && invData['results'] is List) {
        for (final row in (invData['results'] as List)) {
          if (row is Map) {
            final pid = _asInt(row['id']);
            final qty = _asInt(row['stock']);
            if (pid > 0) stockById[pid] = qty;
          }
        }
      }

      // 3b) parse media: chấp nhận {results|items|data: [...] } hoặc list phẳng
      dynamic listNode;
      if (medData is Map) {
        listNode = medData['results'] ?? medData['items'] ?? medData['data'];
      } else if (medData is List) {
        listNode = medData;
      }

      if (listNode is List) {
        for (final row in listNode) {
          if (row is! Map) continue;
          final pid = _asInt(row['productId'] ?? row['id']);
          final assets = _asListOfMap(row['assets'] ?? row['media'] ?? []);
          if (pid > 0) {
            assetsById[pid] = assets;   // dùng ngay
            _mediaCache[pid] = assets;  // lưu cache cho lần sau
          }
        }
      }

      // 4) merge + normalize URL cho ảnh/video
      final merged = <Map<String, dynamic>>[];
      for (final it in items) {
        final pid = _asInt(it['id']);
        final assets = assetsById[pid] ?? const <Map<String, dynamic>>[];

        final rawImage = (it['imageUrl'] as String?) ?? _pickImageUrl(assets);
        final rawVideo = (it['videoUrl'] as String?) ?? _pickVideoUrl(assets);

        merged.add({
          ...it,
          'stock': stockById[pid],
          'assets': assets,
          'imageUrl': norm(rawImage),
          'videoUrl': norm(rawVideo),
        });
      }

      return merged;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow; // do người dùng lướt nhanh
      // ignore: avoid_print
      print('loadPageCancellable /products error: ${e.response?.statusCode} ${e.response?.data}');
      return const [];
    }
  }


  // ===============================
  // Stock cho viewport (cancellable)
  // ===============================
  Future<Map<int, int>> loadStockForVisibleIds(
      List<int> ids, {
        int? delayMs,
        bool fixed = false,
      }) async {
    _stockToken?.cancel('user scrolled');
    _stockToken = CancelToken();

    final qp = <String, dynamic>{ 'ids': ids.join(',') };
    if (delayMs != null) qp['delayMs'] = delayMs;
    if (fixed) qp['fixed'] = 1;

    try {
      final r = await _dio.post(
        '/inventory/visible',
        queryParameters: qp,
        data: {'ids': ids},
        cancelToken: _stockToken,
        options: Options(sendTimeout: const Duration(seconds: 10)),
      );

      final out = <int, int>{};
      final list = (r.data is Map && r.data['results'] is List) ? r.data['results'] as List : const [];
      for (final x in list) {
        if (x is Map) {
          final id = _asInt(x['id']);
          final val = _asInt(x['stock']);
          if (id > 0) out[id] = val;
        }
      }
      return out;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return {};
      // ignore: avoid_print
      print('loadStockForVisibleIds error: ${e.response?.statusCode}');
      return {};
    }
  }

  // ==== Hủy ====
  void cancelPageRequest() {
    _pageToken?.cancel('user scrolled');
  }

  void cancelStockRequests() {
    _stockToken?.cancel('dispose');
  }

  void cancelAll() {
    cancelPageRequest();
    cancelStockRequests();
  }
}
