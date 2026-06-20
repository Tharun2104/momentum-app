import '../models/fitness_summary.dart';
import 'fitness_data_client_stub.dart'
    if (dart.library.io) 'health_fitness_data_client.dart';

abstract class FitnessDataClient {
  Future<FitnessSummary> loadTodaySummary();
}

FitnessDataClient createFitnessDataClient() {
  return createPlatformFitnessDataClient();
}
