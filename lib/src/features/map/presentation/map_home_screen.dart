import 'dart:async';

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

  final Map<MarkerId, Marker> _markers = {};
  final Map<PolylineId, Polyline> _polylines = {};

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
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Mock 모드에서는 실제 GPS 대신 고정 좌표 사용
      final pos = Position(
        latitude: 37.5113,
        longitude: 126.9940,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      _pos = pos;
      _path.clear();
      _path.add(RunPoint(lat: pos.latitude, lng: pos.longitude));

      await _moveCamera(pos, animate: false);
      await _loadNearbySpots(pos);

      // Mock 모드에서는 위치 스트림 대신 간단한 고정 경로만 사용
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '초기화 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
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
        _path
          ..clear()
          ..add(RunPoint(lat: pos.latitude, lng: pos.longitude));
        _polylines.remove(const PolylineId('run'));
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
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadNearbySpots(Position pos) async {
    try {
      final api = ref.read(spotApiProvider);
      final spots = await api.nearby(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      final next = <MarkerId, Marker>{};
      for (final s in spots) {
        final id = MarkerId('spot:${s.id}');
        next[id] = Marker(
          markerId: id,
          position: LatLng(s.latitude, s.longitude),
          infoWindow: InfoWindow(title: s.name, snippet: '+${s.rewardAmount}P'),
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
                                          ? '러닝 중 · ${duration == null ? '--:--' : _fmt(duration)}'
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
                                      '테스트 모드(Mock API · 고정 위치)',
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

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

