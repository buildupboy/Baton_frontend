import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'data/run_api.dart';
import '../auth/auth_providers.dart';

final runApiProvider = Provider<RunApi>((ref) {
  if (useMockApis) {
    return MockRunApi();
  }
  return RunApi(ref.watch(dioProvider));
});


