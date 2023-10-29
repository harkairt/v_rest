// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:io';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:v_rest/caught.dart';
import 'package:v_rest/rest_defect.dart';
import 'package:v_rest/status_codes.dart';

enum RestClientExceptionType { invalidPayload, noResponseData, formatError }

bool _isNullable<V>() => null is V;
bool _typesEqual<T1, T2>() => T1 == T2;

bool _isString(dynamic value) => value is String || _tryCast<String>(value) != null;
bool _isJsonMapType<T>() => _typesEqual<Map<String, dynamic>, T>();
bool _isJsonMap(dynamic value) => value is Map<String, dynamic> || _tryCast<Map<dynamic, dynamic>>(value) != null;
bool _isJsonListType<T>() => _typesEqual<List<dynamic>, T>();
bool _isJsonList(dynamic value) => value is List<dynamic> || _tryCast<List<dynamic>>(value) != null;

V? _tryCast<V>(dynamic value, {V? fallback}) {
  try {
    return value as V;
  } on TypeError catch (_) {
    return fallback;
  }
}

extension TryCastExtension on dynamic {
  V? tryCast<V>() {
    try {
      return this as V;
    } catch (_) {
      return null;
    }
  }
}

typedef JsonList = List<dynamic>;
typedef JsonMap = Map<String, dynamic>;

enum RestClientLoggingLevel { none, path, requestPayload, responsePayload, payload }

class RestClient {
  RestClient(
    this._dio, {
    this.on401,
    this.baseLogLevel = RestClientLoggingLevel.payload,
  });

  final Dio _dio;
  Function? on401;
  RestClientLoggingLevel baseLogLevel;

  Future<Either<RestDefect<E>, V>> get<VR, V, ER, E>(
    String path, {
    required V Function(VR value) mapValue,
    required E Function(ER value) mapError,
    Options? options,
    Map<String, dynamic>? queryParameters,
    bool crashReporting = true,
    RestClientLoggingLevel? logLevel,
  }) async {
    final id = _requestLog<void>(method: 'GET', path: path, logLevel: logLevel);
    return _get(
      path,
      mapValue: mapValue,
      mapError: mapError,
      queryParameters: queryParameters,
      options: options,
    ).mapLeft((defect) {
      _errorLog(id: id, method: 'GET', path: path, defect: defect, logLevel: logLevel);
      return defect;
    }).map((value) {
      _valueLog(id: id, method: 'GET', path: path, value: value, logLevel: logLevel);
      return value;
    }).run();
  }

  Future<Either<RestDefect<E>, V>> post<P, VR, V, ER, E>(
    String path, {
    required P payload,
    required V Function(VR value) mapValue,
    required E Function(ER value) mapError,
    Options? options,
    bool crashReporting = true,
    RestClientLoggingLevel? logLevel,
  }) async {
    final id = _requestLog<void>(method: 'POST', path: path, logLevel: logLevel);
    return _post(
      path,
      mapValue: mapValue,
      mapError: mapError,
      payload: payload,
      options: options,
    ).mapLeft((defect) {
      _errorLog(id: id, method: 'POST', path: path, defect: defect, logLevel: logLevel);
      return defect;
    }).map((value) {
      _valueLog(id: id, method: 'POST', path: path, value: value, logLevel: logLevel);
      return value;
    }).run();
  }

  Future<Either<RestDefect<E>, V>> put<P, VR, V, ER, E>(
    String path, {
    required P payload,
    required V Function(VR value) mapValue,
    required E Function(ER value) mapError,
    Options? options,
    bool crashReporting = true,
    RestClientLoggingLevel? logLevel,
  }) async {
    final id = _requestLog<void>(method: 'PUT', path: path, logLevel: logLevel);
    return _put(
      path,
      mapValue: mapValue,
      mapError: mapError,
      payload: payload,
      options: options,
    ).mapLeft((defect) {
      _errorLog(id: id, method: 'PUT', path: path, defect: defect, logLevel: logLevel);
      return defect;
    }).map((value) {
      _valueLog(id: id, method: 'PUT', path: path, value: value, logLevel: logLevel);
      return value;
    }).run();
  }

  Future<Either<RestDefect<E>, V>> delete<VR, V, ER, E>(
    String path, {
    required V Function(VR value) mapValue,
    required E Function(ER value) mapError,
    Options? options,
    bool crashReporting = true,
    RestClientLoggingLevel? logLevel,
  }) async {
    final id = _requestLog<void>(method: 'DELETE', path: path, logLevel: logLevel);
    return _delete(
      path,
      mapValue: mapValue,
      mapError: mapError,
      options: options,
    ).mapLeft((defect) {
      _errorLog(id: id, method: 'DELETE', path: path, defect: defect, logLevel: logLevel);
      return defect;
    }).map((value) {
      _valueLog(id: id, method: 'DELETE', path: path, value: value, logLevel: logLevel);
      return value;
    }).run();
  }

  TaskEither<RestDefect<E>, V> _makeRequest<VR, V, ER, E>(
    Future<Response<dynamic>> Function() fn, {
    required V Function(VR value) mapValue,
    required E Function(ER value) mapError,
  }) {
    return TaskEither.flatten(
      TaskEither.tryCatch(
        () async {
          final response = await fn();

          final either = (await _handleResponse<E, VR, V>(response, mapValue));
          return TaskEither.fromEither(either);
        },
        (e, stack) {
          final dioException = tryCast<DioException>(e);
          if (dioException != null) {
            return _handleError(dioException, mapError);
          } else {
            return RestDefect.unknown(caught: Caught(e, stack), responseData: null);
          }
        },
      ),
    );
  }

  TaskEither<RestDefect<E>, V> _get<VR, V, ER, E>(
    String path, {
    required V Function(VR value) mapValue,
    required E Function(ER value) mapError,
    Options? options,
    Map<String, dynamic>? queryParameters,
  }) {
    return _makeRequest(
      () => _dio.get<dynamic>(
        path,
        options: options,
        queryParameters: queryParameters,
      ),
      mapValue: mapValue,
      mapError: mapError,
    );
  }

  TaskEither<RestDefect<E>, V> _post<P, VR, V, ER, E>(
    String path, {
    required P payload,
    required V Function(VR value) mapValue,
    required E Function(ER value) mapError,
    Options? options,
  }) {
    if (!(_isJsonList(payload) || _isJsonMap(payload) || payload is FormData || payload == null)) {
      return TaskEither.left(RestDefect<E>.invalidPayload(
        responseData: null,
        caught: Caught.current(
            'Payload must be either List<dynamic>, Map<String, dynamic>, FormData or null. It is ${payload.runtimeType}'),
      ));
    }

    return _makeRequest(
      () => _dio.post<dynamic>(path, data: payload, options: options, cancelToken: null),
      mapValue: mapValue,
      mapError: mapError,
    );
  }

  TaskEither<RestDefect<E>, V> _put<P, VR, V, ER, E>(
    String path, {
    required P payload,
    required V Function(VR value) mapValue,
    required E Function(ER value) mapError,
    Options? options,
  }) {
    if (!(_isJsonList(payload) || _isJsonMap(payload) || payload is FormData || payload == null)) {
      return TaskEither.left(RestDefect<E>.invalidPayload(
        responseData: null,
        caught: Caught.current(
            'Payload must be either List<dynamic>, Map<String, dynamic>, FormData or null. It is ${payload.runtimeType}'),
      ));
    }

    return _makeRequest(
      () => _dio.put<dynamic>(path, data: payload, options: options, cancelToken: null),
      mapValue: mapValue,
      mapError: mapError,
    );
  }

  TaskEither<RestDefect<E>, V> _delete<VR, V, ER, E>(
    String path, {
    required V Function(VR value) mapValue,
    required E Function(ER value) mapError,
    Options? options,
  }) {
    return _makeRequest(
      () => _dio.delete<dynamic>(path, options: options, cancelToken: null),
      mapValue: mapValue,
      mapError: mapError,
    );
  }

  Future<Either<RestDefect<E>, V>> _handleResponse<E, VR, V>(
    Response<dynamic> response,
    V Function(VR value) mapValue,
  ) async {
    final dynamic data = response.data;

    if (data == null) {
      if (_isNullable<V>()) {
        return Right(null as V);
      } else {
        return Left(
          RestDefect.parse(
            responseData: response.data,
            caught: Caught.current(
              'Success status (${response.statusCode}) but null data, although V ($V) is non-nullable.',
            ),
          ),
        );
      }
    } else {
      try {
        final casted = _tryCast<VR>(data);
        if (casted != null) {
          try {
            return Right(mapValue(data as VR));
          } catch (error, stack) {
            return Left(RestDefect.parse(responseData: response.data, caught: Caught(error, stack)));
          }
        }

        if (_isString(data) && (_isJsonListType<VR>() || _isJsonMapType<VR>())) {
          final dynamic jsonData = json.decode(data as String);
          final castedJson = _tryCast<VR>(jsonData);

          if (castedJson != null) {
            try {
              return Right(mapValue(castedJson));
            } catch (error, stack) {
              return Left(RestDefect.parse(responseData: response.data, caught: Caught(error, stack)));
            }
          } else {
            return Left(
              RestDefect.parse(
                  responseData: response.data,
                  caught: Caught.current('Could not cast ${castedJson.runtimeType} to $VR')),
            );
          }
        }

        return Left(RestDefect.parse(
            responseData: response.data, caught: Caught.current('Could not cast ${data.runtimeType} to $VR')));
      } catch (error, stack) {
        return Left(RestDefect.parse(responseData: response.data, caught: Caught(error, stack)));
      }
    }
  }

  RestDefect<E> _handleError<ER, E>(
    DioException dioException,
    E Function(ER value) mapError,
  ) {
    final caught = Caught(dioException, dioException.stackTrace);
    final data = dioException.response?.data;

    return switch (dioException.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        RestDefect<E>.timeout(caught: caught, responseData: data),
      DioExceptionType.cancel => RestDefect<E>.timeout(caught: caught, responseData: data),
      DioExceptionType.connectionError => RestDefect<E>.connection(caught: caught, responseData: data),
      DioExceptionType.unknown => RestDefect<E>.unknown(caught: caught, responseData: data),
      DioExceptionType.badCertificate => RestDefect<E>.badCertificate(caught: caught, responseData: data),
      DioExceptionType.badResponse => () {
          final response = dioException.response;
          if (response == null) {
            return RestDefect<E>.connection(caught: caught, responseData: data);
          }

          final code = response.statusCode ?? 0;

          if (code == 401) {
            on401?.call();
          }

          if (data == null) {
            return RestDefect<E>.badResponse(
              responseData: data,
              caught: caught,
              code: code,
              response: Left(
                ParseRestDefect<E>(
                  responseData: data,
                  caught: Caught.current('response.data is null'),
                ),
              ),
            );
          }

          try {
            final casted = _tryCast<ER>(data);
            if (casted != null) {
              return RestDefect<E>.badResponse(
                responseData: data,
                caught: caught,
                code: code,
                response: Either.tryCatch(
                  () => mapError(casted),
                  (o, s) => ParseRestDefect<E>(
                    responseData: data,
                    caught: Caught(o, s),
                  ),
                ),
              );
            }

            if (_isString(data) && (_isJsonListType<ER>() || _isJsonMapType<ER>())) {
              final dynamic jsonData = json.decode(data as String);
              final castedJson = _tryCast<ER>(jsonData);
              if (castedJson != null) {
                return RestDefect<E>.badResponse(
                  responseData: data,
                  caught: caught,
                  code: code,
                  response: Either.tryCatch(
                    () => mapError(castedJson),
                    (o, s) => ParseRestDefect<E>(
                      caught: Caught(o, s),
                      responseData: data,
                    ),
                  ),
                );
              } else {
                return RestDefect<E>.parse(
                  caught: Caught.current('Decoded string response could not be parse as $ER'),
                  responseData: data,
                );
              }
            }

            return RestDefect<E>.badResponse(
              responseData: data,
              caught: caught,
              code: code,
              response: Left(
                ParseRestDefect<E>(
                  caught: Caught.current('Could not parse ${data.runtimeType} as $ER'),
                  responseData: data,
                ),
              ),
            );
          } catch (o, s) {
            return RestDefect<E>.badResponse(
              responseData: data,
              caught: caught,
              code: code,
              response: Left(
                ParseRestDefect<E>(
                  responseData: data,
                  caught: Caught(o, s),
                ),
              ),
            );
          }
        }(),
    };
  }

  final _warningRequestDurationTreshold = Duration(milliseconds: 600);
  final _alertRequestDurationTreshold = Duration(milliseconds: 1400);
  int _currentRequestId = 0;
  final Map<int, DateTime> _requestsInProgress = {};

  int _requestLog<P>({
    required String method,
    required String path,
    P? payload,
    RestClientLoggingLevel? logLevel,
  }) {
    final effectiveLogLevel = logLevel ?? baseLogLevel;

    final id = _currentRequestId++;
    _requestsInProgress[id] = clock.now();

    if (effectiveLogLevel != RestClientLoggingLevel.none) {
      debugPrint('-> $method $path');
    }

    if ([RestClientLoggingLevel.requestPayload, RestClientLoggingLevel.payload].contains(effectiveLogLevel) &&
        payload != null) {
      try {
        final dynamic maybeJson = (payload as dynamic).toJson();
        final formattedJson = JsonEncoder.withIndent(' ').convert(maybeJson);
        debugPrint(formattedJson);
      } on NoSuchMethodError {
        debugPrint(payload.toString());
      }
    }

    return id;
  }

  void _valueLog<V>({
    required int id,
    required String method,
    required String path,
    required V value,
    RestClientLoggingLevel? logLevel,
  }) {
    final startTime = _requestsInProgress.remove(id)!;
    final finishTime = clock.now();
    final duration = finishTime.difference(startTime);

    final effectiveLogLevel = logLevel ?? baseLogLevel;

    if (effectiveLogLevel != RestClientLoggingLevel.none) {
      if (duration < _warningRequestDurationTreshold) {
        debugPrint('<- (${duration.inMilliseconds} ms) ${_greenText("$method $path")}');
      } else if (duration < _alertRequestDurationTreshold) {
        debugPrint('<- ${_yellowText("(${duration.inMilliseconds} ms)")} ${_greenText("$method $path")}');
      } else {
        debugPrint('<- ${_redText("(${duration.inMilliseconds} ms)")} ${_greenText("$method $path")}');
      }
    }
    if ([RestClientLoggingLevel.responsePayload, RestClientLoggingLevel.payload].contains(effectiveLogLevel)) {
      try {
        final dynamic maybeJson = (value as dynamic).toJson();
        final formattedJson = JsonEncoder.withIndent(' ').convert(maybeJson);
        debugPrint(formattedJson);
      } on NoSuchMethodError {
        try {
          if (value is List) {
            final itemJsonList = value.map<dynamic>((dynamic it) {
              final dynamic maybeJson = (it as dynamic).toJson();
              return maybeJson;
            }).toList();
            final formattedJson = JsonEncoder.withIndent(' ').convert(itemJsonList);
            debugPrint(formattedJson);
          } else {
            debugPrint(value.toString());
          }
        } on NoSuchMethodError {
          debugPrint(value.toString());
        }
      }
    }
  }

  void _errorLog<E>({
    required int id,
    required String method,
    required String path,
    required RestDefect<E> defect,
    RestClientLoggingLevel? logLevel,
  }) {
    final startTime = _requestsInProgress.remove(id)!;
    final finishTime = clock.now();
    final duration = finishTime.difference(startTime);
    final effectiveLogLevel = logLevel ?? baseLogLevel;

    if (effectiveLogLevel != RestClientLoggingLevel.none) {
      switch (defect) {
        case BadResponseRestDefect():
          debugPrint(
              '<- (${duration.inMilliseconds} ms) ${_redText("$method - ${defect.code} ${statusCodes.lookup(defect.code).fold(() => '', (t) => t)} - $path")}');
        case _:
          debugPrint('<- (${duration.inMilliseconds} ms) ${_redText("$method $path")}');
      }
    }

    if ([RestClientLoggingLevel.responsePayload, RestClientLoggingLevel.payload].contains(effectiveLogLevel)) {
      try {
        final data = defect.responseData;
        if (data != null) {
          final f = JsonEncoder.withIndent(' ').convert(defect.responseData);
          debugPrint(_redText(f));
        }
      } on Exception catch (e) {
        debugPrint(e.toString());
      }
    }
  }
}

String _redText(String text) {
  if (kIsWeb || Platform.isAndroid) {
    return text.split('\n').map((line) => '\x1B[31m$line\x1B[0m').join('\n');
  } else {
    return "🛑 $text";
  }
}

String _yellowText(String text) {
  if (kIsWeb || Platform.isAndroid) {
    return text.split('\n').map((line) => "\x1B[33m$line\x1B[0m").join('\n');
  } else {
    return "🟠 $text";
  }
}

String _greenText(String text) {
  if (kIsWeb || Platform.isAndroid) {
    return text.split('\n').map((line) => "\x1B[32m$line\x1B[0m").join('\n');
  } else {
    return "🟢 $text";
  }
}
