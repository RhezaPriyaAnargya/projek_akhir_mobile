import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class PedometerService {
  static const double _strideM = 0.762;
  static const double _calPerStep = 0.04;

  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;
  int _initialSteps = 0;
  int _currentSteps = 0;
  String _status = 'stopped';

  // Callback untuk update UI
  Function(int steps, String status)? onUpdate;

  Future<bool> init() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      _status = 'permission denied';
      onUpdate?.call(_currentSteps, _status);
      return false;
    }

    _stepSub = Pedometer.stepCountStream.listen((e) {
      if (_initialSteps == 0) _initialSteps = e.steps;
      _currentSteps = e.steps - _initialSteps;
      onUpdate?.call(_currentSteps, _status);
    });

    _statusSub = Pedometer.pedestrianStatusStream.listen((e) {
      _status = e.status;
      onUpdate?.call(_currentSteps, _status);
    }, onError: (_) {});
    return true;
  }

  void dispose() {
    _stepSub?.cancel();
    _statusSub?.cancel();
  }

  void reset() {
    _initialSteps = _initialSteps + _currentSteps;
    _currentSteps = 0;
    onUpdate?.call(_currentSteps, _status);
  }

  int get steps => _currentSteps;
  String get status => _status;
  double get distanceKm => (_currentSteps * _strideM) / 1000;
  double get calories => _currentSteps * _calPerStep;
}
