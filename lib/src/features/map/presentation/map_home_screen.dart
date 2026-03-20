import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_controller.dart';
import '../../../design/glass.dart';
import '../../auth/auth_providers.dart';
import '../../run/data/run_api.dart';
import '../../run/run_providers.dart';
import '../../spot/data/spot_api.dart';
import '../../spot/spot_providers.dart';

class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key});

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  GoogleMapController? _map;
  StreamSubscription<Position>? _posSub;

  Position? _pos;
  String? _error;
  bool _busy = false;

  int? _runId;
  DateTime? _runStart;
  final List<RunPoint> _path = [];

  final Set<int> _checkedInSpotIds = <int>{};
  int _runScore = 0;
  bool _checkingIn = false;
  bool _freezeSpotsDuringRun = false;

  final Map<MarkerId, Marker> _markers = {};
  final Map<PolylineId, Polyline> _polylines = {};

  Timer? _spotsDebounce;

  // Mock location controls (only used when useMockApis == true)
  Timer? _mockAutoTimer;
  bool _mockAutoWalk = false;
  double _mockStepMeters = 15;
  int _mockAutoDir = 0;

  static const _initialCam = CameraPosition(
    // 한강 시민공원 근처 고정 좌표 (Mock 모드 기본)
    target: LatLng(37.5113, 126.9940),
    zoom: 18,
    tilt: 45,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    _spotsDebounce?.cancel();
    _mockAutoTimer?.cancel();
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
        final pos = _mockPosition(
          lat: 37.5113,
          lng: 126.9940,
          ts: DateTime.now(),
        );
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
        _posSub = Geolocator.getPositionStream(
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

  Position _mockPosition({
    required double lat,
    required double lng,
    required DateTime ts,
  }) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: ts,
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
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
        _polylines[const PolylineId('run')] = Polyline(
          polylineId: const PolylineId('run'),
          points: _path.map((p) => LatLng(p.lat, p.lng)).toList(),
          width: 6,
          color: Theme.of(context).colorScheme.primary,
        );
      }
    });
    await _moveCamera(pos, animate: animate);
    if (refreshSpots) {
      await _loadNearbySpots(pos);
    }
  }

  Future<void> _moveCamera(Position pos, {required bool animate}) async {
    final cam = CameraPosition(
      target: LatLng(pos.latitude, pos.longitude),
      zoom: 18.0,
      tilt: 45.0,
      bearing: 0,
    );
    if (_map == null) return;
    if (animate) {
      await _map!.animateCamera(CameraUpdate.newCameraPosition(cam));
    } else {
      await _map!.moveCamera(CameraUpdate.newCameraPosition(cam));
    }
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
        _polylines[const PolylineId('run')] = Polyline(
          polylineId: const PolylineId('run'),
          points: [LatLng(pos.latitude, pos.longitude)],
          width: 6,
          color: Theme.of(context).colorScheme.primary,
        );
      });
      await _moveCamera(pos, animate: true);
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
      setState(() {
        _runId = null;
        _runStart = null;
        _checkedInSpotIds.clear();
        _checkingIn = false;
        _freezeSpotsDuringRun = false;
      });

      final p = _pos;
      if (p != null) {
        // 러닝 종료 후 1회만 주변 스팟 갱신
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

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
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
      setState(() {
        _checkedInSpotIds.add(spotId);
        _runScore += gained;
        // nearby를 다시 호출하지 않고, 체크됨 상태만 마커에 즉시 반영
        final id = MarkerId('spot:$spotId');
        _markers[id] = Marker(
          markerId: id,
          position: LatLng(spotSummary.latitude, spotSummary.longitude),
          infoWindow: InfoWindow(
            title: spotSummary.name,
            snippet: '체크됨 (+${spotSummary.rewardAmount}P)',
          ),
          onTap: () {
            unawaited(_checkInSpot(spotSummary));
          },
        );
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '체크인 처리 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  void _nudgeMock({required double eastMeters, required double northMeters}) {
    if (!useMockApis) return;
    final cur = _pos;
    if (cur == null) return;

    final lat = cur.latitude;
    final metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(lat * math.pi / 180.0).abs();

    final dLat = northMeters / metersPerDegLat;
    final dLng = eastMeters / (metersPerDegLng == 0 ? 1 : metersPerDegLng);

    final next = _mockPosition(
      lat: lat + dLat,
      lng: cur.longitude + dLng,
      ts: DateTime.now(),
    );
    unawaited(_applyPosition(next, animate: true, refreshSpots: false));
    _debouncedLoadNearbySpots(next);
  }

  void _toggleMockAutoWalk() {
    if (!useMockApis) return;
    setState(() => _mockAutoWalk = !_mockAutoWalk);

    _mockAutoTimer?.cancel();
    if (!_mockAutoWalk) return;

    _mockAutoDir = 0;
    _mockAutoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_mockAutoWalk) return;
      // 간단히 사각형으로 반복 이동 (N → E → S → W)
      switch (_mockAutoDir % 4) {
        case 0:
          _nudgeMock(eastMeters: 0, northMeters: _mockStepMeters);
        case 1:
          _nudgeMock(eastMeters: _mockStepMeters, northMeters: 0);
        case 2:
          _nudgeMock(eastMeters: 0, northMeters: -_mockStepMeters);
        case 3:
        default:
          _nudgeMock(eastMeters: -_mockStepMeters, northMeters: 0);
      }
      _mockAutoDir++;
    });
  }

  Future<void> _loadNearbySpots(Position pos) async {
    if (_runId != null && _freezeSpotsDuringRun) return;
    try {
      final api = ref.read(spotApiProvider);
      final spots = await api.nearby(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      final next = <MarkerId, Marker>{};
      for (final s in spots) {
        final id = MarkerId('spot:${s.id}');
        final checked = _checkedInSpotIds.contains(s.id);
        next[id] = Marker(
          markerId: id,
          position: LatLng(s.latitude, s.longitude),
          infoWindow: InfoWindow(
            title: s.name,
            snippet: checked ? '체크됨 (+${s.rewardAmount}P)' : '+${s.rewardAmount}P',
          ),
          onTap: () {
            unawaited(_checkInSpot(s));
          },
        );
      }
      setState(() {
        _markers
          ..clear()
          ..addAll(next);
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
    final scheme = Theme.of(context).colorScheme;
    final isRunning = _runId != null;
    final pos = _pos;
    final duration = (_runStart == null)
        ? null
        : DateTime.now().difference(_runStart!);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _initialCam,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              tiltGesturesEnabled: true,
              buildingsEnabled: true,
              markers: Set<Marker>.of(_markers.values),
              polylines: Set<Polyline>.of(_polylines.values),
              onMapCreated: (c) async {
                _map = c;
                if (pos != null) await _moveCamera(pos, animate: false);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 10,
                                width: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isRunning ? scheme.tertiary : scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isRunning
                                          ? '러닝 중 · ${duration == null ? '--:--' : _fmt(duration)} · 점수: $_runScoreP'
                                          : '대기 중 · 주변 스팟을 확인하세요',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      useMockApis
                                          ? '테스트 모드(Mock API · 가상 위치)'
                                          : '실제 위치 모드',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: scheme.secondary),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _busy ? null : _logout,
                                icon: const Icon(Icons.logout),
                                tooltip: '로그아웃',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (useMockApis)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '가상 위치 조작',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Text(
                                  pos == null
                                      ? '--'
                                      : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: scheme.secondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SegmentedButton<double>(
                                    segments: const [
                                      ButtonSegment(
                                        value: 5,
                                        label: Text('5m'),
                                      ),
                                      ButtonSegment(
                                        value: 15,
                                        label: Text('15m'),
                                      ),
                                      ButtonSegment(
                                        value: 50,
                                        label: Text('50m'),
                                      ),
                                    ],
                                    selected: {_mockStepMeters},
                                    onSelectionChanged: _busy
                                        ? null
                                        : (s) {
                                            final v = s.firstOrNull;
                                            if (v == null) return;
                                            setState(() => _mockStepMeters = v);
                                          },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton.tonal(
                                  onPressed: _busy ? null : _toggleMockAutoWalk,
                                  child: Text(_mockAutoWalk ? '자동 이동 끄기' : '자동 이동'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filledTonal(
                                  onPressed: _busy
                                      ? null
                                      : () => _nudgeMock(
                                            eastMeters: 0,
                                            northMeters: _mockStepMeters,
                                          ),
                                  icon: const Icon(Icons.keyboard_arrow_up),
                                  tooltip: '북쪽으로 이동',
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filledTonal(
                                  onPressed: _busy
                                      ? null
                                      : () => _nudgeMock(
                                            eastMeters: -_mockStepMeters,
                                            northMeters: 0,
                                          ),
                                  icon: const Icon(Icons.keyboard_arrow_left),
                                  tooltip: '서쪽으로 이동',
                                ),
                                const SizedBox(width: 10),
                                IconButton.filledTonal(
                                  onPressed: _busy
                                      ? null
                                      : () => _nudgeMock(
                                            eastMeters: _mockStepMeters,
                                            northMeters: 0,
                                          ),
                                  icon: const Icon(Icons.keyboard_arrow_right),
                                  tooltip: '동쪽으로 이동',
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filledTonal(
                                  onPressed: _busy
                                      ? null
                                      : () => _nudgeMock(
                                            eastMeters: 0,
                                            northMeters: -_mockStepMeters,
                                          ),
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                  tooltip: '남쪽으로 이동',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        child: Text(
                          _error!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : (isRunning ? _finishRun : _startRun),
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        isRunning ? scheme.error : scheme.primary,
                                  ),
                                  child: _busy
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text(isRunning ? '종료' : '시작'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton.filledTonal(
                                onPressed: (pos == null || _busy)
                                    ? null
                                    : () async {
                                        await _moveCamera(pos, animate: true);
                                        await _loadNearbySpots(pos);
                                      },
                                icon: const Icon(Icons.my_location),
                                tooltip: '현재 위치',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_busy && _pos == null)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  String get _runScoreP => '${_runScore}P';

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

