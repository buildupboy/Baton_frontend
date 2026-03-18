import 'package:dio/dio.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';

class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  Future<int> join({
    required String email,
    required String password,
    required String realname,
    required String nickname,
  }) {
    return requestJson<int>(
      _dio,
      () => _dio.post(
        '/api/v1/member/join',
        data: {
          'email': email,
          'password': password,
          'realname': realname,
          'nickname': nickname,
        },
      ),
      mapper: (json) => json as int,
    );
  }

  Future<TokenPair> login({required String email, required String password}) {
    return requestJson<TokenPair>(
      _dio,
      () => _dio.post(
        '/api/v1/member/login',
        data: {'email': email, 'password': password},
      ),
      mapper: (json) {
        if (json is! Map<String, dynamic>) {
          throw ApiException('로그인 응답 형식이 올바르지 않습니다.');
        }
        final access = (json['accessToken'] ?? '').toString();
        final refresh = (json['refreshToken'] ?? '').toString();
        if (access.isEmpty) throw ApiException('토큰이 비어있습니다.');
        return TokenPair(accessToken: access, refreshToken: refresh);
      },
    );
  }

  Future<void> logout() async {
    await requestJson<Object?>(
      _dio,
      () => _dio.post('/api/v1/member/logout'),
      mapper: (_) => null,
    );
  }
}

/// 네트워크 없이 테스트용으로 사용하는 Mock 구현.
class MockAuthApi extends AuthApi {
  MockAuthApi() : super(Dio());

  @override
  Future<int> join({
    required String email,
    required String password,
    required String realname,
    required String nickname,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // 항상 userId = 1 반환
    return 1;
  }

  @override
  Future<TokenPair> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // 단순 JWT 형식처럼 보이는 Mock 토큰
    const access =
        'eyMockAccessToken.eyJzdWIiOiJtb2NrVXNlciIsImF1dGgiOiJST0xFX1VTRVIifQ.mock-signature';
    const refresh =
        'eyMockRefreshToken.eyJleHAiOjE5OTk5OTk5OTl9.mock-signature';
    return const TokenPair(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}


