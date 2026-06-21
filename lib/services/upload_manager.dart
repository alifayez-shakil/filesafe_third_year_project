import 'dart:async';
import 'package:flutter/foundation.dart';

enum UploadStatus { encrypting, streaming, syncing, completed, failed }

class UploadTask {
  final String fileName;
  final int totalBytes;
  int uploadedBytes = 0;
  UploadStatus status = UploadStatus.encrypting;
  String errorMessage = '';
  bool dismissed = false;

  void Function()? onProgressChanged;
  Timer? _progressTimer;

  UploadTask({
    required this.fileName,
    required this.totalBytes,
    this.onProgressChanged,
  }) {
    _startProgressSimulation();
  }

  bool get isTerminal =>
      status == UploadStatus.completed || status == UploadStatus.failed;

  // ─── Simulate smooth progress (20 steps) ────────────────────────
  void _startProgressSimulation() {
    // If the file is tiny, speed up the simulation.
    final stepDuration = totalBytes > 10 * 1024 * 1024 ? 200 : 80; // ms
    int step = 0;
    const totalSteps = 20;

    _progressTimer = Timer.periodic(Duration(milliseconds: stepDuration), (
      timer,
    ) {
      if (dismissed || isTerminal) {
        timer.cancel();
        return;
      }

      step++;
      final progress = step / totalSteps;
      // Update status based on progress
      if (progress < 0.3) {
        status = UploadStatus.encrypting;
      } else if (progress < 0.7) {
        status = UploadStatus.streaming;
      } else {
        status = UploadStatus.syncing;
      }

      // Clamp to totalBytes
      final newBytes = (totalBytes * progress).round();
      if (newBytes > uploadedBytes) {
        uploadedBytes = newBytes > totalBytes ? totalBytes : newBytes;
        onProgressChanged?.call();
      }

      // If we've reached the end, stop advancing; wait for external completion
      if (progress >= 1.0) {
        timer.cancel();
        // Don't set completed here – the caller will set it.
      }
    });
  }

  // ─── Called when upload finishes ─────────────────────────────────
  void markCompleted() {
    _progressTimer?.cancel();
    status = UploadStatus.completed;
    uploadedBytes = totalBytes;
    onProgressChanged?.call();
    Future.delayed(const Duration(seconds: 2), () {
      dismissed = true;
      onProgressChanged?.call();
    });
  }

  void markFailed(String error) {
    _progressTimer?.cancel();
    status = UploadStatus.failed;
    errorMessage = error;
    onProgressChanged?.call();
  }

  void dispose() {
    _progressTimer?.cancel();
  }
}

class UploadManager extends ChangeNotifier {
  final List<UploadTask> _tasks = [];

  List<UploadTask> get tasks => _tasks.where((t) => !t.dismissed).toList();

  bool get hasActive =>
      _tasks.any((t) => t.status != UploadStatus.completed && !t.dismissed);

  void addTask(UploadTask task) {
    task.onProgressChanged = notifyListeners;
    _tasks.add(task);
    notifyListeners();
  }

  void removeCompleted() {
    _tasks.removeWhere(
      (t) => t.dismissed && t.status == UploadStatus.completed,
    );
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  @override
  void dispose() {
    for (final task in _tasks) {
      task.dispose();
    }
    super.dispose();
  }
}
