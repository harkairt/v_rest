import 'package:flutter/material.dart';

const isDebug = true;

extension StackTraceX on StackTrace {
  StackTrace get sanitized {
    return this;
  }
}

class Caught {
  final Object error;
  final StackTrace stackTrace;

  Caught(this.error, StackTrace stackTrace) : stackTrace = stackTrace.sanitized;

  Caught.current(this.error) : stackTrace = StackTrace.current.sanitized;

  Caught.print(this.error, StackTrace stackTrace) : stackTrace = stackTrace.sanitized {
    debugPrint(toStringDetailed());
  }

  String toStringDetailed() {
    return '🚧 Caught 🚧 ${error.runtimeType}: $error \n${stackTrace.toString()}';
  }

  @override
  String toString() {
    if (isDebug) {
      return '${error.runtimeType}: $error';
    }

    return 'An error occured';
  }
}
