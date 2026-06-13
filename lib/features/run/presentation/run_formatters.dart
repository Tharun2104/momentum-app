class RunFormatters {
  const RunFormatters._();

  static String distanceKm(double meters) {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  static String duration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  static String pace(double secondsPerKm) {
    if (secondsPerKm <= 0 || !secondsPerKm.isFinite) {
      return '-- /km';
    }

    final roundedSeconds = secondsPerKm.round();
    final minutes = roundedSeconds ~/ 60;
    final seconds = roundedSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }

  static String localDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();

    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String coordinate(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }
}
