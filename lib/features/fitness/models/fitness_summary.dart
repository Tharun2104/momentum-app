enum FitnessSummaryStatus { ready, unavailable, permissionDenied, error }

class FitnessSummary {
  const FitnessSummary({
    required this.status,
    this.steps = 0,
    this.distanceMeters = 0,
    this.activeCalories = 0,
    this.message,
  });

  final FitnessSummaryStatus status;
  final int steps;
  final double distanceMeters;
  final double activeCalories;
  final String? message;
}
