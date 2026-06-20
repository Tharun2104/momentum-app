import '../models/fitness_summary.dart';
import 'fitness_data_client.dart';

FitnessDataClient createPlatformFitnessDataClient() {
  return const UnsupportedFitnessDataClient();
}

class UnsupportedFitnessDataClient implements FitnessDataClient {
  const UnsupportedFitnessDataClient();

  @override
  Future<FitnessSummary> loadTodaySummary() async {
    return const FitnessSummary(
      status: FitnessSummaryStatus.unavailable,
      message: 'Fitness data is currently available only on iPhone.',
    );
  }
}
