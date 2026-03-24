import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/run_metrics.dart';

// [변경] StateNotifierProvider 대신 NotifierProvider를 사용합니다.
final runProvider = NotifierProvider<RunNotifier, RunMetrics>(() {
  return RunNotifier();
});

// [변경] Notifier<T>를 상속받습니다.
class RunNotifier extends Notifier<RunMetrics> {
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
  Position? _lastPosition;

  // [중요] 최신 버전은 build() 메서드에서 초기 상태를 반환합니다.
  @override
  RunMetrics build() {
    // 위젯이 종료될 때 자원을 자동 해제하도록 설정
    ref.onDispose(() {
      stopRunning();
    });
    return RunMetrics.initial();
  }

  void startRunning() {
    state = RunMetrics.initial();
    _startTimer();
    _startLocationTracking();
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
          if (_lastPosition != null) {
            double distanceBetween = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              position.latitude,
              position.longitude,
            );

            if (position.speed < 8.3) {
              state = RunMetrics(
                distance: state.distance + distanceBetween,
                duration: state.duration,
                currentPace: _calculatePace(
                  state.distance + distanceBetween,
                  state.duration.inSeconds,
                ),
              );
            }
          }
          _lastPosition = position;
        });
  }

  double _calculatePace(double distanceMeters, int seconds) {
    if (distanceMeters < 10) return 0.0;
    return seconds / (distanceMeters / 1000);
  }

  void stopRunning() {
    _timer?.cancel();
    _positionStream?.cancel();
    _lastPosition = null;
  }
}
