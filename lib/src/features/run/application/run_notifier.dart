import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/run_metrics.dart';

// 위치와 시간을 기록하는 데이터 클래스 (필요 시 활용)
class RunStateData {
  final Position position;
  final DateTime timestamp;
  RunStateData(this.position, this.timestamp);
}

final runProvider = NotifierProvider<RunNotifier, RunMetrics>(() {
  return RunNotifier();
});

// [변경] Notifier<T>를 상속받습니다.
class RunNotifier extends Notifier<RunMetrics> {
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
  Position? _lastPosition;

  // 페이스 필터링을 위한 변수 (이전 값을 저장하여 급격한 변화 방지)
  double _filteredPace = 0.0;

  @override
  RunMetrics build() {
    // 위젯이 종료될 때 자원을 자동 해제하도록 설정
    ref.onDispose(() {
      stopRunning();
    });
    return RunMetrics.initial();
  }

  // 수정 전: void startRunning()
  // 수정 후:
  void startRunning({bool useGeolocator = true}) {
    state = RunMetrics.initial();
    _lastPosition = null;
    _filteredPace = 0.0;
    _startTimer();

    // 실제 모드일 때만 자체 GPS 구독 시작
    if (useGeolocator) {
      _startLocationTracking();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = RunMetrics(
        distance: state.distance,
        duration: state.duration + const Duration(seconds: 1),
        currentPace: _calculatePace(
          state.distance,
          state.duration.inSeconds + 1,
        ),
        averagePace: state.averagePace,
      );
    });
  }

  void _startLocationTracking() {
    _positionStream?.cancel();
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          final now = DateTime.now();
          double distStep = 0.0;

          // 1. 총 이동 거리 누적 (좌표 기반)
          if (_lastPosition != null) {
            distStep = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              position.latitude,
              position.longitude,
            );
          }

          // 2. 실시간 페이스 계산 (position.speed 활용)
          double rawCurrentPace = 0.0;

          // speed는 m/s 단위임. 0.5m/s(약 시속 1.8km) 이상일 때만 계산 (정지 시 튀는 것 방지)
          if (position.speed > 0.5) {
            // 공식: 60 / (m/s * 3.6) -> 분/km 단위
            rawCurrentPace = 60 / (position.speed * 3.6);
          }

          // 3. 페이스 필터링 (Low-pass Filter)
          // 이전 페이스 80% + 현재 측정값 20%를 섞어 튐 현상을 억제합니다.
          if (_filteredPace == 0.0) {
            _filteredPace = rawCurrentPace;
          } else if (rawCurrentPace > 0) {
            _filteredPace = (_filteredPace * 0.8) + (rawCurrentPace * 0.2);
          } else {
            // 완전히 멈췄을 때
            _filteredPace = 0.0;
          }

          // 4. 상태 업데이트
          final newDistance = state.distance + distStep;
          state = RunMetrics(
            distance: newDistance,
            duration: state.duration,
            currentPace: _filteredPace,
            averagePace: _calculatePace(newDistance, state.duration.inSeconds),
          );

          _lastPosition = position;
        });
  }

  // [추가] Mock 모드나 외부 위치 데이터를 수동으로 주입하기 위한 메서드
  void updatePosition(Position position) {
    final now = DateTime.now();
    double distStep = 0.0;

    // 1. 거리 계산
    if (_lastPosition != null) {
      distStep = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
    }

    // 2. 페이스 계산 (속도 기반)
    double rawCurrentPace = 0.0;
    if (position.speed > 0.5) {
      rawCurrentPace = 60 / (position.speed * 3.6);
    }

    // 3. 필터링 적용 (기존 로직과 동일)
    if (_filteredPace == 0.0) {
      _filteredPace = rawCurrentPace;
    } else if (rawCurrentPace > 0) {
      _filteredPace = (_filteredPace * 0.8) + (rawCurrentPace * 0.2);
    }

    // 4. 상태 업데이트
    final newDistance = state.distance + distStep;
    state = RunMetrics(
      distance: newDistance,
      duration: state.duration,
      currentPace: _filteredPace,
      averagePace: _calculatePace(newDistance, state.duration.inSeconds),
    );

    _lastPosition = position;
  }

  // 전체 평균 페이스 계산 (초/km 단위 반환)
  double _calculatePace(double distanceMeters, int seconds) {
    if (distanceMeters < 10) return 0.0;
    return seconds / (distanceMeters / 1000);
  }

  void stopRunning() {
    _timer?.cancel();
    _positionStream?.cancel();
    _lastPosition = null;
    _filteredPace = 0.0;
  }
}
