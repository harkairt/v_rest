import 'package:fpdart/fpdart.dart';
import 'package:v_rest/caught.dart';

T? tryCast<T>(dynamic value, {T? fallback}) {
  try {
    return value as T;
  } on TypeError catch (_) {
    return fallback;
  }
}

sealed class RestDefect<E> {
  RestDefect({
    required this.caught,
    this.responseData,
  });

  factory RestDefect.unknown({required Caught caught, dynamic responseData}) {
    return UnknownRestDefect(caught: caught, responseData: responseData);
  }

  factory RestDefect.connection({required Caught caught, required dynamic responseData}) {
    return ConnectionRestDefect(caught: caught, responseData: responseData);
  }

  factory RestDefect.timeout({required Caught caught, required dynamic responseData}) {
    return TimeoutRestDefect(caught: caught, responseData: responseData);
  }

  factory RestDefect.cancel({required Caught caught, required dynamic responseData}) {
    return CancelRestDefect(caught: caught, responseData: responseData);
  }

  factory RestDefect.badCertificate({required Caught caught, required dynamic responseData}) {
    return BadCertificateRestDefect(caught: caught, responseData: responseData);
  }

  factory RestDefect.badResponse({
    required Caught caught,
    required int code,
    required Either<ParseRestDefect<E>, E> response,
    required dynamic responseData,
  }) {
    return BadResponseRestDefect(caught: caught, code: code, response: response, responseData: responseData);
  }

  factory RestDefect.parse({required Caught caught, required dynamic responseData}) {
    return ParseRestDefect(caught: caught, responseData: responseData);
  }

  factory RestDefect.invalidPayload({required Caught caught, required dynamic responseData}) {
    return InvalidPayloadRestDefect(caught: caught, responseData: responseData);
  }

  final dynamic responseData;
  final Caught caught;

  @override
  String toString() {
    return '$runtimeType(error: ${caught.error}, resposeData: $responseData)';
  }
}

final class BadCertificateRestDefect<E> extends RestDefect<E> {
  BadCertificateRestDefect({
    required super.caught,
    super.responseData,
  });
}

final class BadResponseRestDefect<E> extends RestDefect<E> {
  final Either<ParseRestDefect<E>, E> response;
  final int code;

  BadResponseRestDefect({
    required super.caught,
    required this.response,
    required this.code,
    required super.responseData,
  });

  @override
  String toString() {
    return 'BadResponseRestDefect(code: $code, response: $response)';
  }
}

final class ConnectionRestDefect<E> extends RestDefect<E> {
  ConnectionRestDefect({
    required super.caught,
    required super.responseData,
  });
}

final class TimeoutRestDefect<E> extends RestDefect<E> {
  TimeoutRestDefect({
    required super.caught,
    required super.responseData,
  });
}

final class CancelRestDefect<E> extends RestDefect<E> {
  CancelRestDefect({
    required super.caught,
    required super.responseData,
  });
}

final class ParseRestDefect<E> extends RestDefect<E> {
  ParseRestDefect({
    required super.caught,
    required super.responseData,
  });
}

final class InvalidPayloadRestDefect<E> extends RestDefect<E> {
  InvalidPayloadRestDefect({
    required super.caught,
    required super.responseData,
  });
}

final class UnknownRestDefect<E> extends RestDefect<E> {
  UnknownRestDefect({
    required super.caught,
    required super.responseData,
  });
}
