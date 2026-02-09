class TreadmillData {
  double speed;
  double incline;
  int time;
  int calories;
  double distance;
  int heartRate;
  bool isRunning;

  TreadmillData({
    this.speed = 0.0,
    this.incline = 0.0,
    this.time = 0,
    this.calories = 0,
    this.distance = 0.0,
    this.heartRate = 0,
    this.isRunning = false,
  });

  @override
  String toString() =>
      'TreadmillData(speed: $speed, incline: $incline, time: $time, calories: $calories, distance: $distance, heartRate: $heartRate, isRunning: $isRunning)';
}
