import 'package:dio/dio.dart';
import '../core/env.dart';
import 'dart:async';

class Task3Api {
  int? _lastId; // Lưu lastId của sản phẩm cuối cùng

  Task3Api() {
    _dio.interceptors.add(LogInterceptor(
      request: false,
      responseHeader: false,
      responseBody: true,
      error: true,
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

  // ===== Helpers =====
  Future<void> _safePing() async {
    try {
      await _dio.get('/health');
    } catch (_) {/* ignore */}
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
      return v
          .where((e) => e is Map)
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
    final imgs =
    assets.where((a) => _asStr(a['type']).toLowerCase() == 'image').toList();
    if (imgs.isEmpty) return null;
    imgs.sort((a, b) => (_asInt(a['sortOrder'])) - (_asInt(b['sortOrder'])));
    final primary =
    imgs.firstWhere((a) => (a['isPrimary'] == true), orElse: () => imgs.first);
    return _getUrl(primary);
  }

  static String? _pickVideoUrl(List<Map<String, dynamic>> assets) {
    final vids =
    assets.where((a) => _asStr(a['type']).toLowerCase() == 'video').toList();
    if (vids.isEmpty) return null;
    vids.sort((a, b) => (_asInt(a['sortOrder'])) - (_asInt(b['sortOrder'])));
    final primary =
    vids.firstWhere((a) => (a['isPrimary'] == true), orElse: () => vids.first);
    return _getUrl(primary);
  }

  // ===============================
  // 2️⃣ Load 1 trang dùng keyset pagination (lastId)
  // ===============================
  Future<Map<String, dynamic>?> loadPageCancellable({
    int size = 10,
    int? lastId,
  }) async {
    _pageToken?.cancel('next page');
    _pageToken = CancelToken();

    await _safePing();

    final queryParams = <String, dynamic>{
      'size': size,
      if (lastId != null) 'lastId': lastId,
    };

    try {
      final p = await _dio.get(
        '/products',
        queryParameters: queryParams,
        cancelToken: _pageToken,
      );

      final body = p.data;
      if (body is! Map) return null;

      // Parse items
      final List<Map<String, dynamic>> items =
      (body['items'] is List)
          ? (body['items'] as List)
          .where((e) => e is Map)
          .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map))
          .toList()
          : const [];

      // Chuẩn hoá url ảnh/video nếu có
      final merged = <Map<String, dynamic>>[];
      for (final it in items) {
        final rawImage = it['imageUrl'] as String?;
        final rawVideo = it['videoUrl'] as String?;
        merged.add({
          ...it,
          'imageUrl': _normalizeUrl(rawImage),
          'videoUrl': _normalizeUrl(rawVideo),
        });
      }

      // lastId từ backend
      final nextCursor = body['lastId'] != null
          ? int.tryParse(body['lastId'].toString())
          : null;
      _lastId = nextCursor;

      final hasNextFromServer = body['hasNext'] == true;

      return {
        'items': merged,
        'hasNext': hasNextFromServer,
        'lastId': nextCursor,
      };
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return null;
      print('loadPageCancellable /products error: '
          '${e.response?.statusCode} ${e.response?.data}');
      return null;
    }
  }

  // ===== 3️⃣ Reset pagination khi refresh list =====
  void resetPagination() {
    _lastId = null;
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

    final qp = <String, dynamic>{'ids': ids.join(',')};
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
      final list = (r.data is Map && r.data['results'] is List)
          ? r.data['results'] as List
          : const [];
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
