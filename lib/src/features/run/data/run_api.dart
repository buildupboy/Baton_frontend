import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class RunPoint {
  const RunPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class RunApi {
  RunApi(this._dio);
  final Dio _dio;

  Future<int> start({required String startTimeIsoLocal}) {
    return requestJson<int>(
      _dio,
      () => _dio.post(
        '/api/v1/runs/start',
        data: {'startTime': startTimeIsoLocal},
      ),
      mapper: (json) => (json as num).toInt(),
    );
  }

  Future<void> finish({
    required int runId,
    required String endTimeIsoLocal,
    required List<RunPoint> path,
  }) async {
    await requestJson<Object?>(
      _dio,
      () => _dio.post(
        '/api/v1/runs/$runId/finish',
        data: {
          'endTime': endTimeIsoLocal,
          'path': path.map((p) => p.toJson()).toList(),
        },
      ),
      mapper: (_) => null,
    );
  }
}

/// 실제 서버 없이 러닝 시작/종료를 흉내 내는 Mock 구현.
class MockRunApi extends RunApi {
  MockRunApi() : super(Dio());

  @override
  Future<int> start({required String startTimeIsoLocal}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // 단순히 항상 runId = 1 반환
    return 1;
  }

  @override
  Future<void> finish({
    required int runId,
    required String endTimeIsoLocal,
    required List<RunPoint> path,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}


