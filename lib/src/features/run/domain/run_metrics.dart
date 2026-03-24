// lib/src/features/run/domain/run_metrics.dart

class RunMetrics {
  final double distance; // 미터(m) 단위
  final Duration duration; // 경과 시간
  final double currentPace; // 초/km 단위 (예: 300초 = 5분 페이스)

  RunMetrics({
    required this.distance,
    required this.duration,
    required this.currentPace,
  });

  // 초기값 객체
  factory RunMetrics.initial() =>
      RunMetrics(distance: 0.0, duration: Duration.zero, currentPace: 0.0);

  // 화면 표시용 포맷팅 (05'20")
  String get formattedPace {
    if (currentPace <= 0 || currentPace.isInfinite) return "-'--\"";
    int minutes = (currentPace / 60).floor();
    int seconds = (currentPace % 60).floor();
    return "${minutes.toString().padLeft(2, '0')}'${seconds.toString().padLeft(2, '0')}\"";
  }

  // 거리 포맷팅 (1.23 km)
  String get formattedDistance => (distance / 1000).toStringAsFixed(2);
}
