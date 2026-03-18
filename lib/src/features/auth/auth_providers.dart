import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'data/auth_api.dart';

/// true 이면 네트워크 없이 Mock API를 사용합니다.
const bool useMockApis = true;

final authApiProvider = Provider<AuthApi>((ref) {
  if (useMockApis) {
    return MockAuthApi();
  }
  return AuthApi(ref.watch(dioProvider));
});


