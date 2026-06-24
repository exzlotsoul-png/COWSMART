import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiClient {
  final Dio _dio;
  String? _token;

  // Base URL: Use 127.0.0.1 for windows/web, 10.0.2.2 for android emulator
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  ApiClient()
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          // Remove Content-Type for FormData so Dio sets multipart boundary automatically
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
          }
          return handler.next(options);
        },
      ),
    );
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('🌐 API: $obj'),
      ),
    );
  }

  void setToken(String? token) {
    _token = token;
  }

  Future<Response> get(String path, {Map<String, dynamic>? query}) async {
    try {
      return await _dio.get(path, queryParameters: query);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout)
      return 'เชื่อมต่อหมดเวลา (Connection Timeout)';
    if (e.type == DioExceptionType.receiveTimeout)
      return 'เซิร์ฟเวอร์ตอบสนองช้า (Receive Timeout)';
    if (e.response != null) {
      final message =
          e.response?.data['message'] ??
          'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์ (${e.response?.statusCode})';
      print('❌ API Error: $message');
      return message;
    }
    return 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต';
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
