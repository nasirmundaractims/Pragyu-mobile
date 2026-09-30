class ApiException implements Exception {
  ApiException({
    required this.message,
    required this.statusCode,
    this.code,
    this.fieldErrors = const {},
    this.data,
    this.cause,
  });

  final String message;
  final int statusCode;
  final String? code;
  final Map<String, String> fieldErrors;
  final Map<String, dynamic>? data;
  final Object? cause;

  bool get isUnauthorized =>
      statusCode == 401 ||
      code == 'AUTH_002' ||
      code == 'AUTH_001' ||
      code == 'UNAUTHENTICATED';

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
