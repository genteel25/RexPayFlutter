import 'package:dio/dio.dart';

class DioErrorUtil {
  // general methods:------------------------------------------------------------
  static String handleError(dynamic error) {
    String errorDescription = '';
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.cancel:
          errorDescription = 'Request to API server was cancelled';
          break;
        case DioExceptionType.connectionTimeout:
          errorDescription = 'Connection timeout with API server';
          break;
        case DioExceptionType.connectionError:
          errorDescription = 'No internet connection';
          break;
        case DioExceptionType.receiveTimeout:
          errorDescription = 'Receive timeout in connection with API server';
          break;
        case DioExceptionType.badResponse:
          if (error.response?.statusCode == 404) {
            errorDescription = error.response?.data["responseMessage"] ??
                'Unexpected error occurred';
          } else if (error.response?.statusCode == 400) {
            errorDescription =
                error.response?.data["responseMessage"] ?? 'Bad request';
          } else if (error.response?.statusCode == 422) {
            errorDescription =
                error.response?.data["responseMessage"] ?? 'Bad request';
          } else if (error.response?.statusCode == 401) {
            errorDescription = error.response?.data["responseMessage"] ??
                'These credentials are wrong \nCheck and try again';
          } else if (error.response?.statusCode == 500) {
            errorDescription = error.response?.data["responseMessage"] ??
                'Server is currently under maintenance, Try again later';
          } else {
            errorDescription =
                'Received invalid status code: ${error.response?.statusCode}';
          }
          break;
        case DioExceptionType.sendTimeout:
          errorDescription = 'Send timeout in connection with API server';
          break;
        default:
          errorDescription = 'Unknown error occurred';
        // break;
      }
    } else if (error is TypeError) {
      errorDescription = error.stackTrace.toString();
    } else {
      return error.toString();
    }
    return errorDescription;
  }

  static String normalizeError(dynamic error) {
    if (error.runtimeType.toString().toLowerCase().contains("map")) {
      if (error.containsKey("errors")) {
        Map<String, dynamic> errors =
            Map<String, dynamic>.from(error["errors"]);
        return errors.values.first[0];
      } else {
        return error["message"];
      }
    }

    return error;
  }
}
