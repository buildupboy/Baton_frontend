import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_controller.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode});
  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, code: $code, message: $message)';
}

String formatApiErrorMessage(ApiException e) {
  if (e.statusCode != null) {
    return '[${e.statusCode}] ${e.message}';
  }
  return e.message;
}

final dioProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionControllerProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://equator-swimming-folic.ngrok-free.dev',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = session.tokenPair?.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) {
        handler.next(e);
      },
    ),
  );

  return dio;
});

dynamic unwrapApiResponse(dynamic data) {
  // Success: { success: true, message: "...", data: ... }
  // Error:   { status: "fail", code: "...", message: "..." }
  //          { success: false, message: "...", data: "..." }
  if (data is Map<String, dynamic>) {
    if (data['success'] == true) {
      return data['data'];
    }
    if (data['success'] == false) {
      final msg = (data['message'] ?? data['data'] ?? '요청에 실패했습니다.')
          .toString();
      final code = data['code']?.toString();
      throw ApiException(msg, code: code);
    }
    if (data['status'] == 'fail') {
      final msg = (data['message'] ?? '요청에 실패했습니다.').toString();
      final code = data['code']?.toString();
      throw ApiException(msg, code: code);
    }
  }
  throw ApiException('알 수 없는 응답 형식입니다.');
}

Future<T> requestJson<T>(
  Dio dio,
  Future<Response<dynamic>> Function() call, {
  T Function(dynamic json)? mapper,
}) async {
  try {
    final res = await call();
    final unwrapped = unwrapApiResponse(res.data);
    if (mapper != null) return mapper(unwrapped);
    return unwrapped as T;
  } on DioException catch (e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      if (data['status'] == 'fail' || data['success'] == false) {
        throw ApiException(
          (data['message'] ?? data['data'] ?? '요청에 실패했습니다.').toString(),
          code: data['code']?.toString(),
          statusCode: statusCode,
        );
      }
    }
    throw ApiException('네트워크 오류가 발생했습니다.', statusCode: statusCode);
  }
}
