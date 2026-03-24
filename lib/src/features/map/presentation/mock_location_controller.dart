// c:\001_Porjects\runapp\lib\src\features\map\presentation\mock_location_controller.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class MockLocationController {
  MockLocationController({
    required this.onPositionChanged,
    required this.onStateChanged,
  });

  /// 위치가 변경될 때 호출되는 콜백
  final void Function(Position position) onPositionChanged;

  /// 내부 상태(버튼 활성 여부 등)가 변경될 때 UI 갱신을 요청하는 콜백
  final VoidCallback onStateChanged;

  Timer? _timer;
  bool _autoWalk = false;
  double _stepMeters = 15.0;
  int _dir = 0;

  // 현재 가상 위치 저장
  Position? _currentPos;

  bool get isAutoWalk => _autoWalk;
  double get stepMeters => _stepMeters;

  void dispose() {
    _timer?.cancel();
  }

  /// 초기 가상 위치 설정
  Position initPosition({required double lat, required double lng}) {
    final pos = _createPosition(lat: lat, lng: lng);
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
    if (!_autoWalk) return;

    _dir = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // 간단히 사각형으로 반복 이동 (N → E → S → W)
      switch (_dir % 4) {
        case 0:
          nudge(eastMeters: 0, northMeters: _stepMeters);
          break;
        case 1:
          nudge(eastMeters: _stepMeters, northMeters: 0);
          break;
        case 2:
          nudge(eastMeters: 0, northMeters: -_stepMeters);
          break;
        case 3:
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

    final next = _createPosition(lat: lat + dLat, lng: cur.longitude + dLng);
    _currentPos = next;

    onPositionChanged(next);
  }

  Position _createPosition({required double lat, required double lng}) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }
}
