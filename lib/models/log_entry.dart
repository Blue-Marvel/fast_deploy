enum LogLevel { stdout, stderr, info, warn, error, success }

class LogEntry {
  LogEntry({
    required this.level,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final LogLevel level;
  final String message;
  final DateTime timestamp;
}

/// One end-to-end script execution: stdout/stderr stream + exit code future.
class RunHandle {
  RunHandle({
    required this.id,
    required this.label,
    required this.entries,
    required this.exitCode,
    required this.startedAt,
    required this.cancel,
  });

  final String id;
  final String label;
  final Stream<LogEntry> entries;
  final Future<int> exitCode;
  final DateTime startedAt;
  final void Function() cancel;
}
