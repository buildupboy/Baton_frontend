import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'data/spot_api.dart';
import '../auth/auth_providers.dart';

final spotApiProvider = Provider<SpotApi>((ref) {
  if (useMockApis) {
    return MockSpotApi();
  }
  return SpotApi(ref.watch(dioProvider));
});


