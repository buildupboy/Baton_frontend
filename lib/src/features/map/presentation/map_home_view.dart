import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import '../../../design/glass.dart';

class MapHomeView extends StatelessWidget {
  const MapHomeView({
    super.key,
    required this.initialCameraPosition,
    required this.onMapReady,
    required this.onMapTapped,
    required this.currentPosition,
    required this.isRunning,
    required this.isBusy,
    required this.errorMsg,
    required this.runScore,
    required this.runDuration,
    required this.useMockApis,
    required this.mockStepMeters,
    required this.mockAutoWalk,
    required this.onLogout,
    required this.onStartRun,
    required this.onFinishRun,
    required this.onMoveToCurrentLocation,
    required this.onMockChangeStep,
    required this.onMockToggleAutoWalk,
    required this.onMockNudge,
  });

  final NCameraPosition initialCameraPosition;
  final void Function(NaverMapController) onMapReady;
  final void Function(NPoint, NLatLng) onMapTapped;

  final Position? currentPosition;
  final bool isRunning;
  final bool isBusy;
  final String? errorMsg;
  final int runScore;
  final Duration? runDuration;

  // Mock Mode Props
  final bool useMockApis;
  final double mockStepMeters;
  final bool mockAutoWalk;

  // Callbacks
  final VoidCallback onLogout;
  final VoidCallback onStartRun;
  final VoidCallback onFinishRun;
  final VoidCallback onMoveToCurrentLocation;
  final ValueChanged<double> onMockChangeStep;
  final VoidCallback onMockToggleAutoWalk;
  final void Function({required double east, required double north})
  onMockNudge;

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pos = currentPosition;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: initialCameraPosition,
                locationButtonEnable: false,
                compassEnable: false,
                tiltGesturesEnable: true,
                indoorEnable: true,
                locale: const Locale('ko'),
                // [Fix] 네비게이션 바(약 90px) + 하단 안전 영역(Safe Area)만큼
                // 지도 내부 패딩을 주어 로고와 중심점이 가려지지 않게 설정
                contentPadding: EdgeInsets.only(bottom: 90 + bottomSafe),
              ),
              onMapReady: onMapReady,
              onMapTapped: onMapTapped,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // 상단 상태 바
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
                                  color: isRunning
                                      ? scheme.tertiary
                                      : scheme.primary,
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
                                          ? '러닝 중 · ${runDuration == null ? '--:--' : _fmt(runDuration!)} · 점수: ${runScore}P'
                                          : '대기 중 · 주변 스팟을 확인하세요',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
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
                                onPressed: isBusy ? null : onLogout,
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

                  // 가상 위치 조작 패널
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
                                  style: Theme.of(context).textTheme.labelSmall
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
                                        value: 5.0,
                                        label: Text('5m'),
                                      ),
                                      ButtonSegment(
                                        value: 15.0,
                                        label: Text('15m'),
                                      ),
                                      ButtonSegment(
                                        value: 50.0,
                                        label: Text('50m'),
                                      ),
                                    ],
                                    selected: {mockStepMeters},
                                    onSelectionChanged: isBusy
                                        ? null
                                        : (s) {
                                            final v = s.firstOrNull;
                                            if (v != null) onMockChangeStep(v);
                                          },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton.tonal(
                                  onPressed: isBusy
                                      ? null
                                      : onMockToggleAutoWalk,
                                  child: Text(
                                    mockAutoWalk ? '자동 이동 끄기' : '자동 이동',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // D-Pad Controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filledTonal(
                                  onPressed: isBusy
                                      ? null
                                      : () => onMockNudge(
                                          east: 0,
                                          north: mockStepMeters,
                                        ),
                                  icon: const Icon(Icons.keyboard_arrow_up),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filledTonal(
                                  onPressed: isBusy
                                      ? null
                                      : () => onMockNudge(
                                          east: -mockStepMeters,
                                          north: 0,
                                        ),
                                  icon: const Icon(Icons.keyboard_arrow_left),
                                ),
                                const SizedBox(width: 10),
                                IconButton.filledTonal(
                                  onPressed: isBusy
                                      ? null
                                      : () => onMockNudge(
                                          east: mockStepMeters,
                                          north: 0,
                                        ),
                                  icon: const Icon(Icons.keyboard_arrow_right),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filledTonal(
                                  onPressed: isBusy
                                      ? null
                                      : () => onMockNudge(
                                          east: 0,
                                          north: -mockStepMeters,
                                        ),
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 에러 메시지
                  if (errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        child: Text(
                          errorMsg!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ),

                  // 하단 액션 버튼
                  Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: isBusy
                                      ? null
                                      : (isRunning ? onFinishRun : onStartRun),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isRunning
                                        ? scheme.error
                                        : scheme.primary,
                                  ),
                                  child: isBusy
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(isRunning ? '종료' : '시작'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton.filledTonal(
                                onPressed: (pos == null || isBusy)
                                    ? null
                                    : onMoveToCurrentLocation,
                                icon: const Icon(Icons.my_location),
                                tooltip: '현재 위치',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // [Fix] 하단 탭바(CustomBottomBar) 높이만큼 여백 추가 (버튼이 가려지지 않도록)
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
          if (isBusy && pos == null)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
