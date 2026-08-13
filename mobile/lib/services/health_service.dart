import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Wraps the `health` package to read Steps, Heart Rate, and Calories
/// Burned from Android Health Connect.
class HealthDailyMetrics {
  final DateTime date;
  final int steps;
  final int? heartRate;
  final DateTime? heartRateMeasuredAt;
  final double caloriesBurned;

  const HealthDailyMetrics({
    required this.date,
    required this.steps,
    required this.heartRate,
    this.heartRateMeasuredAt,
    required this.caloriesBurned,
  });
}

class HealthService {
  static final Health _health = Health();

  static final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
  ];

  static final List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  static bool _configured = false;

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Checks whether Health Connect is installed/available on this device.
  static Future<bool> isAvailable() async {
    try {
      await _ensureConfigured();
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      debugPrint('HealthService.isAvailable error: $e');
      return false;
    }
  }

  /// Opens the Play Store / update flow for Health Connect if it's missing.
  static Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('HealthService.installHealthConnect error: $e');
    }
  }

  /// Requests read permission for steps, heart rate, and calories burned.
  /// Returns true if permission was granted.
  static Future<bool> requestPermissions() async {
    try {
      await _ensureConfigured();

      final hasPermissions = await _health.hasPermissions(
        _dataTypes,
        permissions: _permissions,
      );

      if (hasPermissions == true) {
        return true;
      }

      return await _health.requestAuthorization(
        _dataTypes,
        permissions: _permissions,
      );
    } catch (e) {
      debugPrint('HealthService.requestPermissions error: $e');
      return false;
    }
  }

  static Future<bool> hasPermissions() async {
    try {
      await _ensureConfigured();
      return await _health.hasPermissions(
            _dataTypes,
            permissions: _permissions,
          ) ??
          false;
    } catch (e) {
      debugPrint('HealthService.hasPermissions error: $e');
      return false;
    }
  }

  /// Fetches aggregated steps, latest heart rate, and total calories burned
  /// for each day between [start] and [end] (inclusive, local time).
  static Future<List<HealthDailyMetrics>> fetchMetricsForRange(
    DateTime start,
    DateTime end,
  ) async {
    await _ensureConfigured();

    final results = <HealthDailyMetrics>[];

    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day);

    for (var day = rangeStart;
        !day.isAfter(rangeEnd);
        day = day.add(const Duration(days: 1))) {
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      try {
        final metrics = await _fetchMetricsForDay(dayStart, dayEnd);
        results.add(metrics);
      } catch (e) {
        debugPrint('HealthService.fetchMetricsForRange error on $day: $e');
        results.add(
          HealthDailyMetrics(
            date: dayStart,
            steps: 0,
            heartRate: null,
            caloriesBurned: 0,
          ),
        );
      }
    }

    return results;
  }

  /// Fetches today's steps, latest heart rate, and calories burned so far.
  static Future<HealthDailyMetrics> fetchTodayMetrics() async {
    await _ensureConfigured();

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _fetchMetricsForDay(dayStart, dayEnd);
  }

  static Future<HealthDailyMetrics> _fetchMetricsForDay(
    DateTime dayStart,
    DateTime dayEnd,
  ) async {
    int steps = 0;
    int? heartRate;
    DateTime? heartRateMeasuredAt;
    double calories = 0;

    try {
      final stepsTotal = await _health.getTotalStepsInInterval(
        dayStart,
        dayEnd,
      );
      steps = stepsTotal ?? 0;
    } catch (e) {
      debugPrint('HealthService: steps fetch failed: $e');
    }

    try {
      final heartRateData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: dayStart,
        endTime: dayEnd,
      );

      if (heartRateData.isNotEmpty) {
        heartRateData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
        final latestPoint = heartRateData.first;
        final latest = latestPoint.value;
        if (latest is NumericHealthValue) {
          heartRate = latest.numericValue.round();
          heartRateMeasuredAt = latestPoint.dateTo;
        }
      }
    } catch (e) {
      debugPrint('HealthService: heart rate fetch failed: $e');
    }

    try {
      final activeCaloriesData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: dayStart,
        endTime: dayEnd,
      );

      for (final point in activeCaloriesData) {
        final value = point.value;
        if (value is NumericHealthValue) {
          calories += value.numericValue.toDouble();
        }
      }
    } catch (e) {
      debugPrint('HealthService: active calories fetch failed: $e');
    }

    try {
      final basalCaloriesData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BASAL_ENERGY_BURNED],
        startTime: dayStart,
        endTime: dayEnd,
      );

      for (final point in basalCaloriesData) {
        final value = point.value;
        if (value is NumericHealthValue) {
          calories += value.numericValue.toDouble();
        }
      }
    } catch (e) {
      debugPrint('HealthService: basal calories fetch failed: $e');
    }

    return HealthDailyMetrics(
      date: dayStart,
      steps: steps,
      heartRate: heartRate,
      heartRateMeasuredAt: heartRateMeasuredAt,
      caloriesBurned: calories,
    );
  }
}
