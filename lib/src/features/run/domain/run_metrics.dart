// lib/src/features/run/domain/run_metrics.dart

class RunMetrics {
  final double distance;
  final Duration duration;
  final double currentPace; // 최근 10초 구간 페이스
  final double averagePace; // 운동 시작 후 전체 평균 페이스

  RunMetrics({
    required this.distance,
    required this.duration,
    required this.currentPace,
    required this.averagePace,
  });

  factory RunMetrics.initial() => RunMetrics(
    distance: 0.0,
    duration: Duration.zero,
    currentPace: 0.0,
    averagePace: 0.0,
  );

  // 화면 표시용 (최근 페이스 우선 표시)
  String get formattedCurrentPace => _formatPace(currentPace);
  String get formattedAveragePace => _formatPace(averagePace);

  String _formatPace(double pace) {
    if (pace <= 0 || pace.isInfinite || pace > 1800)
      return "-'--\""; // 30분 페이스 넘어가면 무시
    int minutes = (pace / 60).floor();
    int seconds = (pace % 60).floor();
    return "${minutes.toString().padLeft(2, '0')}'${seconds.toString().padLeft(2, '0')}\"";
  }

  String get formattedDistance => (distance / 1000).toStringAsFixed(2);
}
