import 'package:dio/dio.dart';

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
    // 서울 주요 러닝 스팟 예시
    return const [
      SpotSummary(
        id: 1,
        name: '한강 시민공원',
        rewardAmount: 100,
        latitude: 37.5113,
        longitude: 126.9940,
      ),
      SpotSummary(
        id: 2,
        name: '서울숲',
        rewardAmount: 120,
        latitude: 37.5444,
        longitude: 127.0374,
      ),
      SpotSummary(
        id: 3,
        name: '남산 서울타워',
        rewardAmount: 150,
        latitude: 37.5512,
        longitude: 126.9882,
      ),
    ];
  }

  @override
  Future<SpotDetail> detail(int spotId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    switch (spotId) {
      case 1:
        return const SpotDetail(
          id: 1,
          name: '한강 시민공원',
          description: '서울에서 가장 인기 있는 러닝 코스. 야경이 특히 아름답습니다.',
          rewardAmount: 100,
          latitude: 37.5113,
          longitude: 126.9940,
        );
      case 2:
        return const SpotDetail(
          id: 2,
          name: '서울숲',
          description: '나무와 잔디가 잘 정돈된 러닝 스팟. 도심 속 힐링 코스.',
          rewardAmount: 120,
          latitude: 37.5444,
          longitude: 127.0374,
        );
      case 3:
      default:
        return const SpotDetail(
          id: 3,
          name: '남산 서울타워',
          description: '언덕과 뷰가 좋은 힐코스. 체력 테스트에 제격입니다.',
          rewardAmount: 150,
          latitude: 37.5512,
          longitude: 126.9882,
        );
    }
  }
}


