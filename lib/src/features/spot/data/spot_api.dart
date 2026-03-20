import 'package:dio/dio.dart';
import 'dart:math' as math;

import '../../../core/network/api_client.dart';

class SpotSummary {
  const SpotSummary({
    required this.id,
    required this.name,
    required this.rewardAmount,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final int rewardAmount;
  final double latitude;
  final double longitude;

  factory SpotSummary.fromJson(Map<String, dynamic> json) {
    return SpotSummary(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      rewardAmount: (json['rewardAmount'] as num).toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class SpotDetail {
  const SpotDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.rewardAmount,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final String description;
  final int rewardAmount;
  final double latitude;
  final double longitude;

  factory SpotDetail.fromJson(Map<String, dynamic> json) {
    return SpotDetail(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      rewardAmount: (json['rewardAmount'] as num).toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class SpotApi {
  SpotApi(this._dio);
  final Dio _dio;

  Future<List<SpotSummary>> nearby({
    required double latitude,
    required double longitude,
  }) {
    // Postman에는 GET인데 body 예시가 있음. 실서비스는 query가 자연스럽지만,
    // 안전하게 query로 보냄(서버가 body를 요구하면 쉽게 교체 가능).
    return requestJson<List<SpotSummary>>(
      _dio,
      () => _dio.get(
        '/api/v1/spots/nearby',
        queryParameters: {'latitude': latitude, 'longitude': longitude},
      ),
      mapper: (json) {
        if (json is! List) throw ApiException('스팟 목록 응답 형식이 올바르지 않습니다.');
        return json
            .whereType<Map<String, dynamic>>()
            .map(SpotSummary.fromJson)
            .toList();
      },
    );
  }

  Future<SpotDetail> detail(int spotId) {
    return requestJson<SpotDetail>(
      _dio,
      () => _dio.get('/api/v1/spots/$spotId'),
      mapper: (json) {
        if (json is! Map<String, dynamic>) {
          throw ApiException('스팟 상세 응답 형식이 올바르지 않습니다.');
        }
        return SpotDetail.fromJson(json);
      },
    );
  }

  /// 스팟 [spotId]에 대해 체크인.
  ///
  /// 백엔드 응답 스펙이 확정 전이므로,
  /// - `data`가 숫자면 그대로 points로 취급
  /// - `data`가 Map이면 `points`/`rewardAmount` 등을 우선 탐색
  /// 하는 형태로 최대한 방어적으로 매핑합니다.
  Future<int> checkIn({required int spotId}) {
    return requestJson<int>(
      _dio,
      () => _dio.post('/api/v1/spots/$spotId/checkin'),
      mapper: (json) {
        if (json is num) return json.toInt();
        if (json is Map<String, dynamic>) {
          final v = json['points'] ??
              json['rewardAmount'] ??
              json['reward'] ??
              json['score'];
          if (v is num) return v.toInt();
        }
        throw ApiException('체크인 응답 형식이 올바르지 않습니다.');
      },
    );
  }
}

/// 실제 서버 없이 테스트용 스팟 데이터를 제공하는 Mock 구현.
class MockSpotApi extends SpotApi {
  MockSpotApi() : super(Dio());

  @override
  Future<List<SpotSummary>> nearby({
    required double latitude,
    required double longitude,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // 요청으로 들어온 현재 위치를 기준으로, 반경 200m 이내에 10개 스팟 생성
    // (체크인/근접 로직 검증용: 위치를 조금만 움직여도 스팟이 계속 따라오게)
    const count = 10;
    const radiusMeters = 200.0;

    final rand = math.Random(
      // 입력 좌표에 따라 결정적으로 생성되도록 seed 고정
      (latitude * 1e6).round() ^ (longitude * 1e6).round(),
    );

    double metersPerDegLat(double lat) => 111320.0;
    double metersPerDegLng(double lat) =>
        111320.0 * math.cos(lat * math.pi / 180.0).abs();

    final baseLat = latitude;
    final baseLng = longitude;
    final mLat = metersPerDegLat(baseLat);
    final mLng = metersPerDegLng(baseLat);

    final spots = <SpotSummary>[];
    for (var i = 0; i < count; i++) {
      // 원판 내부에 균일하게 분포: r = sqrt(u) * R
      final u = rand.nextDouble();
      final r = math.sqrt(u) * radiusMeters;
      final theta = rand.nextDouble() * 2 * math.pi;

      final north = r * math.sin(theta);
      final east = r * math.cos(theta);

      final dLat = north / mLat;
      final dLng = east / (mLng == 0 ? 1 : mLng);

      spots.add(
        SpotSummary(
          id: i + 1,
          name: 'Mock Spot ${i + 1}',
          rewardAmount: 50 + (i * 10),
          latitude: baseLat + dLat,
          longitude: baseLng + dLng,
        ),
      );
    }
    return spots;
  }

  @override
  Future<SpotDetail> detail(int spotId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    // detail은 "최근 nearby 기준"을 유지하지 않으므로, 간단히 id 기반 더미로 제공
    final reward = 50 + ((spotId - 1).clamp(0, 9) * 10);
    return SpotDetail(
      id: spotId,
      name: 'Mock Spot $spotId',
      description: '가상 위치 체크인 테스트용 스팟입니다. (반경 200m 내 자동 생성)',
      rewardAmount: reward,
      latitude: 0,
      longitude: 0,
    );
  }

  @override
  Future<int> checkIn({required int spotId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    // MockNearby 생성 규칙과 동일하게 보상 계산
    return 50 + ((spotId - 1).clamp(0, 9) * 10);
  }
}


