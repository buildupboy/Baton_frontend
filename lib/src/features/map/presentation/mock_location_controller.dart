import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class MockLocationController {
  MockLocationController({
    required this.onPositionChanged,
    required this.onStateChanged,
  });

  final void Function(Position position) onPositionChanged;
  final VoidCallback onStateChanged;

  Timer? _timer;
  bool _autoWalk = false;
  double _stepMeters = 5.0; // [변경] 15m는 너무 커서 5m(시속 18km) 정도로 기본값 하향
  int _dir = 0;

  Position? _currentPos;

  bool get isAutoWalk => _autoWalk;
  double get stepMeters => _stepMeters;

  void dispose() {
    _timer?.cancel();
  }

  Position initPosition({required double lat, required double lng}) {
    final pos = _createPosition(lat: lat, lng: lng, speed: 0);
    _currentPos = pos;
    return pos;
  }

  void setStepMeters(double value) {
    _stepMeters = value;
    onStateChanged();
  }

  void toggleAutoWalk() {
    _autoWalk = !_autoWalk;
    onStateChanged();

    _timer?.cancel();
    if (!_autoWalk) {
      // 멈췄을 때 속도를 0으로 한 번 더 전송하여 페이스가 떨어지게 유도
      if (_currentPos != null) {
        final stopPos = _createPosition(
          lat: _currentPos!.latitude,
          lng: _currentPos!.longitude,
          speed: 0,
        );
        _currentPos = stopPos;
        onPositionChanged(stopPos);
      }
      return;
    }

    _dir = 0;
    // 1초마다 이동 시뮬레이션
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      switch (_dir % 40) {
        // 방향 전환 주기를 길게 변경 (직선 주행 테스트용)
        case 0:
        case 1:
        case 2:
        case 3:
        case 4:
        case 5:
        case 6:
        case 7:
        case 8:
        case 9:
          nudge(eastMeters: 0, northMeters: _stepMeters);
          break;
        case 10:
        case 11:
        case 12:
        case 13:
        case 14:
        case 15:
        case 16:
        case 17:
        case 18:
        case 19:
          nudge(eastMeters: _stepMeters, northMeters: 0);
          break;
        case 20:
        case 21:
        case 22:
        case 23:
        case 24:
        case 25:
        case 26:
        case 27:
        case 28:
        case 29:
          nudge(eastMeters: 0, northMeters: -_stepMeters);
          break;
        default:
          nudge(eastMeters: -_stepMeters, northMeters: 0);
          break;
      }
      _dir++;
    });
  }

  void nudge({required double eastMeters, required double northMeters}) {
    final cur = _currentPos;
    if (cur == null) return;

    final lat = cur.latitude;
    const metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(lat * math.pi / 180.0).abs();

    final dLat = northMeters / metersPerDegLat;
    final dLng = eastMeters / (metersPerDegLng == 0 ? 1 : metersPerDegLng);

    // [중요] 이동 거리(m)를 시간(1초)으로 나누어 speed 계산
    // nudge가 버튼 클릭으로 발생할 수도 있고 타이머로 발생할 수도 있으므로 실제 이동 거리를 사용
    final movedDistance = math.sqrt(
      math.pow(eastMeters, 2) + math.pow(northMeters, 2),
    );

    // speed는 m/s 단위임
    final next = _createPosition(
      lat: lat + dLat,
      lng: cur.longitude + dLng,
      speed: movedDistance, // 1초에 이동한 거리이므로 곧 속도(m/s)가 됨
    );

    _currentPos = next;
    onPositionChanged(next);
  }

  Position _createPosition({
    required double lat,
    required double lng,
    required double speed,
  }) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5.0, // Mock임을 감지하기 좋게 고정값 부여
      altitude: 0.0,
      heading: 0.0,
      speed: speed, // 계산된 속도 주입
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
      floor: null,
      isMocked: true,
    );
  }
}
