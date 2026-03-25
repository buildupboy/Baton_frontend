import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_controller.dart';
import '../../auth/auth_providers.dart';
import '../../run/application/run_notifier.dart';
import '../../run/data/run_api.dart';
import '../../run/run_providers.dart';
import '../../spot/data/spot_api.dart';
import '../../spot/spot_providers.dart';
import 'map_home_view.dart';
import 'mock_location_controller.dart';

// [Fix] useMockApis가 정의되지 않아 추가 (전역 설정 파일이 있다면 import로 대체 필요)
const bool useMockApis = true;

class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key});

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  NaverMapController? _map;
  StreamSubscription<Position>? _posSub;

  Position? _pos;
  String? _error;
  bool _busy = false;

  int? _runId;
  DateTime? _runStart;
  final List<RunPoint> _path = [];

  List<SpotSummary> _nearbySpots = [];
  final Set<int> _checkedInSpotIds = <int>{};
  int _runScore = 0;
  bool _checkingIn = false;
  bool _freezeSpotsDuringRun = false;

  final Map<String, NMarker> _markers = {};
  final Map<String, NPolylineOverlay> _polylines = {};

  Timer? _spotsDebounce;

  MockLocationController? _mockController;

  // [Fix] 초기 로딩 시와 추적 시의 설정을 분리하여 관리
  static const double _initZoom = 13.0; // 시작 시 넓게 보기
  static const double _initTilt = 0.0; // 시작 시 비스듬히 보기
  static const double _trackingZoom = 18.0; // 위치 추적 시 확대
  static const double _trackingTilt = 60.0; // 위치 추적 시 수직 뷰

  static const _initialCam = NCameraPosition(
    // 한강 시민공원 근처 고정 좌표 (Mock 모드 기본)
    target: NLatLng(37.5113, 126.9940),
    zoom: _initZoom,
    tilt: _initTilt,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    _spotsDebounce?.cancel();
    _mockController?.dispose();
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (useMockApis) {
        // Mock 모드에서는 실제 GPS 대신 가상 위치를 사용(버튼/자동이동으로 조작)
        _mockController = MockLocationController(
          onPositionChanged: (p) async {
            if (!mounted) return;
            await _applyPosition(p, animate: true, refreshSpots: false);
            _debouncedLoadNearbySpots(p);

            // [Fix] Mock 모드일 때 러닝 중이라면 위치 정보를 Notifier에 수동 주입
            if (_runId != null) {
              ref.read(runProvider.notifier).updatePosition(p);
            }
          },
          onStateChanged: () => setState(() {}),
        );

        final pos = _mockController!.initPosition(lat: 37.5113, lng: 126.9940);
        _path
          ..clear()
          ..add(RunPoint(lat: pos.latitude, lng: pos.longitude));
        await _applyPosition(pos, animate: false, refreshSpots: true);
      } else {
        // 실제 모드: 현재 위치 권한/스트림을 연결
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) {
          throw ApiException('위치 서비스가 꺼져 있습니다.');
        }
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          throw ApiException('위치 권한이 필요합니다.');
        }

        final first = await Geolocator.getCurrentPosition();
        _path
          ..clear()
          ..add(RunPoint(lat: first.latitude, lng: first.longitude));
        await _applyPosition(first, animate: false, refreshSpots: true);

        _posSub?.cancel();
        _posSub =
            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.best,
                distanceFilter: 5,
              ),
            ).listen((p) async {
              if (!mounted) return;
              await _applyPosition(p, animate: true, refreshSpots: false);
              _debouncedLoadNearbySpots(p);
            });
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '초기화 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _debouncedLoadNearbySpots(Position pos) {
    if (_runId != null && _freezeSpotsDuringRun) return;
    _spotsDebounce?.cancel();
    _spotsDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      await _loadNearbySpots(pos);
    });
  }

  Future<void> _applyPosition(
    Position pos, {
    required bool animate,
    required bool refreshSpots,
  }) async {
    final isRunning = _runId != null;
    setState(() {
      _pos = pos;
      if (isRunning) {
        _path.add(RunPoint(lat: pos.latitude, lng: pos.longitude));
        // [Fix] Polyline은 좌표가 최소 2개 이상이어야 생성 가능 (네이티브 크래시 방지)
        if (_path.length >= 2) {
          final polyline = NPolylineOverlay(
            id: 'run',
            coords: _path.map((p) => NLatLng(p.lat, p.lng)).toList(),
            width: 6,
            color: Theme.of(context).colorScheme.primary,
          );
          _polylines['run'] = polyline;
          _map?.addOverlay(polyline);
        }
      }
    });
    final targetZoom = (_runId != null) ? _trackingZoom : _initZoom;
    final targetTilt = (_runId != null) ? _trackingTilt : _initTilt;

    await _moveCamera(
      pos,
      animate: animate,
      zoom: targetZoom,
      tilt: targetTilt,
    );

    if (refreshSpots) {
      await _loadNearbySpots(pos);
    }

    // [Fix] 위치 변경 시 15m 이내 스팟이 있으면 자동 체크인 시도
    _tryAutoCheckIn(pos);
  }

  // MapHomeScreen 상태 클래스 내부
  Future<void> _moveCamera(
    Position pos, {
    required bool animate,
    double? zoom, // 선택적 파라미터로 변경
    double? tilt, // 선택적 파라미터로 변경
  }) async {
    if (_map == null) return;

    final cam = NCameraUpdate.fromCameraPosition(
      NCameraPosition(
        target: NLatLng(pos.latitude, pos.longitude),
        // 파라미터가 있으면 그 값을 쓰고, 없으면 기본 추적 값(_trackingZoom) 사용
        zoom: zoom ?? _trackingZoom,
        tilt: tilt ?? _trackingTilt,
      ),
    );

    if (animate) {
      cam.setAnimation(
        animation: NCameraAnimation.easing,
        duration: const Duration(milliseconds: 300),
      );
    }
    await _map!.updateCamera(cam);
  }

  String _isoLocal(DateTime dt) {
    // Postman에서 yyyy-MM-ddTHH:mm:ss 형태로 사용
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(dt);
  }

  Future<void> _startRun() async {
    final pos = _pos;
    if (pos == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final api = ref.read(runApiProvider);
      final now = DateTime.now();
      final runId = await api.start(startTimeIsoLocal: _isoLocal(now));

      // [New] 러닝 지표 트래킹 시작
      // [Fix] Mock 모드면 내부 GPS 구독 끄기 (수동 주입 사용)
      ref.read(runProvider.notifier).startRunning(useGeolocator: !useMockApis);

      setState(() {
        _runId = runId;
        _runStart = now;
        _runScore = 0;
        _checkedInSpotIds.clear();
        _checkingIn = false;
        _freezeSpotsDuringRun = true;
        _spotsDebounce?.cancel();
        _path
          ..clear()
          ..add(RunPoint(lat: pos.latitude, lng: pos.longitude));
        // [Fix] 점이 1개일 때는 Polyline을 그릴 수 없으므로 오버레이 갱신 로직 제거
        _polylines.remove('run');
      });
      await _moveCamera(
        pos,
        animate: true,
        zoom: _trackingZoom,
        tilt: _trackingTilt,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishRun() async {
    final runId = _runId;
    if (runId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final api = ref.read(runApiProvider);
      await api.finish(
        runId: runId,
        endTimeIsoLocal: _isoLocal(DateTime.now()),
        path: List<RunPoint>.from(_path),
      );

      // [New] 러닝 지표 트래킹 종료
      ref.read(runProvider.notifier).stopRunning();

      setState(() {
        _runId = null;
        _runStart = null;
        _checkedInSpotIds.clear();
        _checkingIn = false;
        _freezeSpotsDuringRun = false;
        _map?.clearOverlays();
      });

      final p = _pos;
      if (p != null) {
        // 러닝 종료 후 1회만 주변 스팟 갱신
        await _moveCamera(p, animate: true, zoom: _initZoom, tilt: _initTilt);
        await _loadNearbySpots(p);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadiusMeters = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  Future<void> _checkInSpot(SpotSummary spotSummary) async {
    if (_runId == null) {
      setState(() => _error = '러닝 중에만 체크인할 수 있습니다.');
      return;
    }
    if (_checkingIn) return;

    final spotId = spotSummary.id;
    final sLat = spotSummary.latitude;
    final sLng = spotSummary.longitude;

    if (_checkedInSpotIds.contains(spotId)) {
      setState(() => _error = '이미 체크인한 스팟입니다.');
      return;
    }

    final pos = _pos;
    if (pos == null) return;

    final distance = _distanceMeters(
      lat1: pos.latitude,
      lng1: pos.longitude,
      lat2: sLat,
      lng2: sLng,
    );
    if (distance > 15) {
      setState(() => _error = '가까운 곳(15m 이내)에서만 체크인 가능합니다.');
      return;
    }

    setState(() {
      _checkingIn = true;
      _error = null;
    });

    try {
      final api = ref.read(spotApiProvider);
      final gained = await api.checkIn(spotId: spotId);
      // 서버 응답 points가 rewardAmount와 불일치할 수 있으므로 gained를 우선.

      final id = 'spot:$spotId';
      final marker = NMarker(
        id: id,
        position: NLatLng(spotSummary.latitude, spotSummary.longitude),
        caption: NOverlayCaption(text: spotSummary.name),
        subCaption: NOverlayCaption(
          text: '체크됨 (+${spotSummary.rewardAmount}P)',
        ),
      );
      marker.setOnTapListener((m) {
        unawaited(_checkInSpot(spotSummary));
      });

      setState(() {
        _checkedInSpotIds.add(spotId);
        _runScore += gained;
        // nearby를 다시 호출하지 않고, 체크됨 상태만 마커에 즉시 반영
        _markers[id] = marker;
        _map?.addOverlay(marker);
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '체크인 처리 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  void _tryAutoCheckIn(Position pos) {
    // 러닝 중이 아니면 자동 체크인 하지 않음
    if (_runId == null) return;

    for (final spot in _nearbySpots) {
      if (_checkedInSpotIds.contains(spot.id)) continue;

      final dist = _distanceMeters(
        lat1: pos.latitude,
        lng1: pos.longitude,
        lat2: spot.latitude,
        lng2: spot.longitude,
      );

      if (dist <= 15.0) {
        _checkInSpot(spot);
      }
    }
  }

  Future<void> _loadNearbySpots(Position pos) async {
    if (_runId != null && _freezeSpotsDuringRun) return;
    try {
      final api = ref.read(spotApiProvider);
      final spots = await api.nearby(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      _nearbySpots = spots;
      final next = <String, NMarker>{};
      for (final s in spots) {
        final id = 'spot:${s.id}';
        final checked = _checkedInSpotIds.contains(s.id);
        final marker = NMarker(
          id: id,
          position: NLatLng(s.latitude, s.longitude),
          caption: NOverlayCaption(text: s.name),
          subCaption: NOverlayCaption(
            text: checked ? '체크됨 (+${s.rewardAmount}P)' : '+${s.rewardAmount}P',
          ),
        );
        marker.setOnTapListener((m) {
          unawaited(_checkInSpot(s));
        });
        next[id] = marker;
      }

      _map?.clearOverlays();
      setState(() {
        _markers
          ..clear()
          ..addAll(next);
        _map?.addOverlayAll(_markers.values.toSet());
        if (_polylines.containsKey('run')) {
          _map?.addOverlay(_polylines['run']!);
        }
      });
    } catch (_) {
      // 주변 스팟 조회 실패는 치명적이지 않으니 무시
    }
  }

  Future<void> _logout() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).logout();
    } catch (_) {
      // 서버 로그아웃 실패해도 로컬 세션은 제거
    } finally {
      await ref.read(sessionControllerProvider.notifier).clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // [New] 실시간 러닝 지표 구독
    final runMetrics = ref.watch(runProvider);

    final pos = _pos;
    final duration = (_runStart == null)
        ? null
        : DateTime.now().difference(_runStart!);

    return MapHomeView(
      initialCameraPosition: _initialCam,
      currentPosition: pos,
      isRunning: _runId != null,
      isBusy: _busy,
      errorMsg: _error,
      runScore: _runScore,
      runDuration: duration,
      runMetrics: runMetrics, // [New] View에 전달
      useMockApis: useMockApis,
      mockStepMeters: _mockController?.stepMeters ?? 15,
      mockAutoWalk: _mockController?.isAutoWalk ?? false,
      onMapReady: (c) async {
        _map = c;

        // 1. 렌더링 안정화를 위해 잠시 대기
        await Future.delayed(const Duration(milliseconds: 500));

        // 2. 현재 위치(pos)가 있다면, 초기 줌(17.0)과 틸트(45.0)를 강제로 적용
        if (pos != null) {
          await _moveCamera(
            pos,
            animate: true,
            zoom: _initZoom, // 17.0 강제 지정
            tilt: _initTilt, // 45.0 강제 지정
          );
        }

        // 3. 나머지 오버레이 추가
        _map?.addOverlayAll(_markers.values.toSet());
        _map?.addOverlayAll(_polylines.values.toSet());

        if (mounted) setState(() {});
      },
      onMapTapped: (point, latLng) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      onLogout: _logout,
      onStartRun: _startRun,
      onFinishRun: _finishRun,
      onMoveToCurrentLocation: () async {
        if (pos == null) return;
        await _moveCamera(pos, animate: true);
        await _loadNearbySpots(pos);
      },
      onMockChangeStep: (val) => _mockController?.setStepMeters(val),
      onMockToggleAutoWalk: () => _mockController?.toggleAutoWalk(),
      onMockNudge: ({required east, required north}) =>
          _mockController?.nudge(eastMeters: east, northMeters: north),
    );
  }
}
