import 'package:dio/dio.dart';

import '../data/api.dart';
import '../i18n/translations.dart';

/// Short, user-facing text for an unexpected failure (never a raw exception).
String friendlyError(Object e, Translations t) {
  if (e is ApiException) {
    return e.statusCode == null ? t.err_network : t.err_generic;
  }
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return t.err_network;
      default:
        return e.response == null ? t.err_network : t.err_generic;
    }
  }
  return t.err_generic;
}
