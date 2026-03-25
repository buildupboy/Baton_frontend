import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import '../../../design/glass.dart';
import '../../run/domain/run_metrics.dart';

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
    required this.runMetrics,
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
  final RunMetrics runMetrics; // [New] 러닝 지표 데이터

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

  // [New] 대시보드 내 시간 포맷팅 (시:분:초)
  String _formatFullDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  // [New] 대시보드 아이템 위젯
  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
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
                  // 상단 상태 바 (기존 유지)
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

                  // [New] 러닝 페이스/거리 대시보드 (러닝 중에만 표시)
                  if (isRunning)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 15,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              "페이스",
                              runMetrics.formattedCurrentPace,
                            ),
                            _buildStatItem(
                              "거리",
                              "${runMetrics.formattedDistance} km",
                            ),
                            _buildStatItem(
                              "시간",
                              _formatFullDuration(runMetrics.duration),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const Spacer(),

                  // [개선] 가상 위치 조작 패널 (러닝머신 스타일)
                  if (useMockApis)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mock Runner',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: scheme.primary,
                                      ),
                                ),
                                if (mockAutoWalk)
                                  const _BlinkingDot(), // 아래 커스텀 위젯 추가
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 1. 속도(페이스) 선택 레이블
                            Row(
                              children: [
                                const Icon(
                                  Icons.speed,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "테스트 속도: ${mockStepMeters.toStringAsFixed(1)} m/s "
                                  "(${(60 / (mockStepMeters * 3.6)).toStringAsFixed(1)}' Pace)",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 2. 속도 조절 SegmentedButton (5m/15m 대신 실제 페이스 위주로 변경 추천)
                            SegmentedButton<double>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: 2.77,
                                  label: Text('6\'00'),
                                ),
                                ButtonSegment(
                                  value: 3.33,
                                  label: Text('5\'00'),
                                ),
                                ButtonSegment(
                                  value: 4.16,
                                  label: Text('4\'00'),
                                ),
                                ButtonSegment(
                                  value: 5.55,
                                  label: Text('3\'00'),
                                ),
                              ],
                              selected: {mockStepMeters},
                              onSelectionChanged: isBusy
                                  ? null
                                  : (s) => onMockChangeStep(s.first),
                            ),
                            const SizedBox(height: 12),

                            // 3. 메인 컨트롤 (자동 이동 & 수동 이동)
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: FilledButton.icon(
                                    onPressed: isBusy
                                        ? null
                                        : onMockToggleAutoWalk,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: mockAutoWalk
                                          ? scheme.errorContainer
                                          : scheme.primaryContainer,
                                      foregroundColor: mockAutoWalk
                                          ? scheme.error
                                          : scheme.onPrimaryContainer,
                                    ),
                                    icon: Icon(
                                      mockAutoWalk
                                          ? Icons.pause_circle
                                          : Icons.play_circle,
                                    ),
                                    label: Text(
                                      mockAutoWalk ? '시뮬레이션 중단' : '자동 이동 시작',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 수동 넛지(Nudge)는 이제 '순간이동'이 아니라 '위치 보정'용으로 활용
                                IconButton.filledTonal(
                                  onPressed: isBusy
                                      ? null
                                      : () => onMockNudge(
                                          east: 0,
                                          north: mockStepMeters,
                                        ),
                                  icon: const Icon(Icons.north),
                                  tooltip: "북쪽으로 한 걸음",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
