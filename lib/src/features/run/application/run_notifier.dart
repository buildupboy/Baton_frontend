import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/run_metrics.dart';

// [1] 최근 위치와 시간을 함께 저장하기 위한 데이터 클래스
class RunStateData {
  final Position position;
  final DateTime timestamp;
  RunStateData(this.position, this.timestamp);
}

final runProvider = NotifierProvider<RunNotifier, RunMetrics>(() {
  return RunNotifier();
});

class RunNotifier extends Notifier<RunMetrics> {
  // [2] 실시간 페이스 계산을 위한 변수들
  final List<RunStateData> _recentStates = [];
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
  Position? _lastPosition;

  @override
  RunMetrics build() {
    ref.onDispose(() => stopRunning());
    return RunMetrics.initial();
  }

  // [Fix] Mock 모드에서는 Geolocator를 끄기 위해 useGeolocator 파라미터 추가
  void startRunning({bool useGeolocator = true}) {
    state = RunMetrics.initial();
    _recentStates.clear();
    _lastPosition = null;
    _startTimer();
    if (useGeolocator) {
      _startLocationTracking();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final newDuration = state.duration + const Duration(seconds: 1);
      state = RunMetrics(
        distance: state.distance,
        duration: newDuration,
        currentPace: state.currentPace,
        averagePace: _calculatePace(state.distance, newDuration.inSeconds),
      );
    });
  }

  void _startLocationTracking() {
    _positionStream?.cancel();
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 2, // 2미터 이동 시마다 업데이트
          ),
        ).listen((Position position) {
          updatePosition(position);
        });
  }

  // [Fix] 외부(Mock 컨트롤러)에서 위치를 주입할 수 있도록 public 메서드로 분리
  void updatePosition(Position position) {
    final now = DateTime.now();
    double dist = 0.0;

    if (_lastPosition != null) {
      dist = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // 시속 30km 이하의 정상적인 움직임만 기록
      // (Mock 모드 등에서는 speed가 0일 수 있으므로 속도 체크를 완화하거나 로직 조정 필요)
      if (position.speed < 8.3) {
        final newDistance = state.distance + dist;

        // 최근 10초 데이터 업데이트 (Sliding Window)
        _recentStates.add(RunStateData(position, now));
        _recentStates.removeWhere(
          (s) => now.difference(s.timestamp).inSeconds > 10,
        );

        state = RunMetrics(
          distance: newDistance,
          duration: state.duration,
          currentPace: _calculateRecentPace(), // 실시간 페이스 계산 호출
          averagePace: _calculatePace(newDistance, state.duration.inSeconds),
        );
      }
    }
    _lastPosition = position;
  }

  // [3] 최근 10초 구간의 페이스 계산 메서드
  double _calculateRecentPace() {
    if (_recentStates.length < 2) return 0.0;

    double recentDist = 0.0;
    for (int i = 0; i < _recentStates.length - 1; i++) {
      recentDist += Geolocator.distanceBetween(
        _recentStates[i].position.latitude,
        _recentStates[i].position.longitude,
        _recentStates[i + 1].position.latitude,
        _recentStates[i + 1].position.longitude,
      );
    }

    if (recentDist < 5) return 0.0; // 최소 5미터는 이동해야 계산

    int timeDiff = _recentStates.last.timestamp
        .difference(_recentStates.first.timestamp)
        .inSeconds;

    if (timeDiff <= 0) return 0.0;

    return timeDiff / (recentDist / 1000);
  }

  double _calculatePace(double distanceMeters, int seconds) {
    if (distanceMeters < 10 || seconds <= 0) return 0.0;
    return seconds / (distanceMeters / 1000);
  }

  void stopRunning() {
    _timer?.cancel();
    _positionStream?.cancel();
    _lastPosition = null;
    _recentStates.clear();
  }
}
