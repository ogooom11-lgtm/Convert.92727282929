import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'runner.dart';

/// داخليًا: يحمل قيمة الناتج من داخل isolate الإدخال.
class ProcessRunResult {
  ProcessRunResult(this.outcome, this.stdoutText, this.stderrText);
  final ProcessOutcome outcome;
  final String stdoutText;
  final String stderrText;
}

/// مُنفّذ الأوامر.
///
/// المبادئ الملزمة (من الخطة):
/// * المعاملات تُمرّر كقائمة منفصلة، لا كنص سطر أوامر — لذلك تعمل أسماء
///   الملفات العربية والمسافات بلا أي معالجة خاصة.
/// * كل عملية لها مهلة (٢٠ دقيقة افتراضيًا) وإمكانية إلغاء فورية.
/// * لا تجميد للواجهة: القراءة تدريجية، والنتيجة تُعاد كوعد.
class ProcessRunner {
  ProcessRunner({this.defaultTimeout = const Duration(minutes: 20)});

  final Duration defaultTimeout;

  Process? _active;
  bool _cancelRequested = false;

  bool get isBusy => _active != null;

  /// يشغّل [executable] بالمعاملات [arguments].
  ///
  /// [onLine] تُستدعى لكل سطر من المخرجات — تُستخدم لعرض تقدم حقيقي.
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration? timeout,
    void Function(String line)? onLine,
    void Function(int pid)? onStarted,
  }) async {
    final stopwatch = Stopwatch()..start();
    _cancelRequested = false;

    Process process;
    try {
      process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: false,
      );
    } on ProcessException catch (error) {
      stopwatch.stop();
      return ProcessRunResult(
        ProcessOutcome(
          exitCode: -1,
          stdoutText: '',
          stderrText: error.message.isEmpty
              ? 'تعذّر تشغيل: $executable'
              : error.message,
          timedOut: false,
          cancelled: false,
          duration: stopwatch.elapsed,
        ),
        '',
        error.message,
      );
    }

    _active = process;
    onStarted?.call(process.pid);

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final firstLines = <String>[];

    // نقرأ التدفقين معًا حتى لا يمتلئ الأنبوب ويتوقف البرنامج الخارجي.
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      stdoutBuffer.writeln(line);
      if (firstLines.length < 2000) firstLines.add(line);
      onLine?.call(line);
    }).catchError((_) {});

    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      stderrBuffer.writeln(line);
      if (firstLines.length < 2000) firstLines.add(line);
      onLine?.call(line);
    }).catchError((_) {});

    var timedOut = false;
    final limit = timeout ?? defaultTimeout;
    final timer = Timer(limit, () {
      timedOut = true;
      _killTree(process);
    });

    int exitCode;
    try {
      await Future.wait<void>([stdoutDone, stderrDone]);
      exitCode = await process.exitCode;
    } catch (_) {
      exitCode = -1;
    }
    timer.cancel();
    stopwatch.stop();

    final wasCancelled = _cancelRequested;
    _cancelRequested = false;
    _active = null;

    return ProcessRunResult(
      ProcessOutcome(
        exitCode: wasCancelled ? -2 : (timedOut ? -3 : exitCode),
        stdoutText: stdoutBuffer.toString(),
        stderrText: stderrBuffer.toString(),
        timedOut: timedOut,
        cancelled: wasCancelled,
        duration: stopwatch.elapsed,
      ),
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
    );
  }

  /// إلغاء فوري: يقتل العملية وشجرة عملياتها (LibreOffice ينشئ عمليات فرعية).
  void cancel() {
    final process = _active;
    if (process == null) return;
    _cancelRequested = true;
    _killTree(process);
  }

  void _killTree(Process process) {
    if (Platform.isWindows) {
      // /T يقتل الشجرة، /F قتل قسري.
      Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F'],
          runInShell: false);
    } else {
      process.kill(ProcessSignal.sigkill);
    }
  }
}
