import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

/// A failed API call, keyed by the stable `code` of the spec's problem+json
/// errors (plus `NETWORK` / `UNKNOWN` for failures that never reached the API).
class Failure implements Exception {
  const Failure({
    required this.code,
    this.statusCode,
    this.detail,
    this.fieldErrors = const {},
  });

  static const network = 'NETWORK';
  static const unknown = 'UNKNOWN';

  final String code;
  final int? statusCode;

  /// Server-localized message; only a fallback for codes the app does not know.
  final String? detail;
  final Map<String, List<String>> fieldErrors;

  factory Failure.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return const Failure(code: network);
    }
    final status = response.statusCode;
    final data = response.data;
    if (data is Map && data['code'] is String) {
      return Failure(
        code: data['code'] as String,
        statusCode: status,
        detail: data['detail'] as String?,
        fieldErrors: _fieldErrors(data['errors']),
      );
    }
    return Failure(code: _codeForStatus(status), statusCode: status);
  }

  static String _codeForStatus(int? status) => switch (status) {
    401 => 'UNAUTHORIZED',
    403 => 'FORBIDDEN',
    404 => 'NOT_FOUND',
    429 => 'RATE_LIMITED',
    final s? when s >= 500 => 'INTERNAL_ERROR',
    _ => unknown,
  };

  static Map<String, List<String>> _fieldErrors(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): [
          if (entry.value is List)
            for (final message in entry.value as List) message.toString(),
        ],
    };
  }

  @override
  String toString() => 'Failure($code, status: $statusCode)';
}

typedef ApiResult<T> = Future<Either<Failure, T>>;

/// Runs an API call and folds every error into a [Failure].
ApiResult<T> guardApi<T>(Future<T> Function() run) async {
  try {
    return Either.right(await run());
  } on DioException catch (error) {
    final inner = error.error;
    return Either.left(inner is Failure ? inner : Failure.fromDio(error));
  } on Failure catch (failure) {
    return Either.left(failure);
  } catch (_) {
    // A response that does not match the contract is not something users can fix.
    return Either.left(const Failure(code: Failure.unknown));
  }
}

extension UnwrapApiResult<T> on ApiResult<T> {
  /// For `FutureProvider`s: surface the [Failure] as an `AsyncError`.
  Future<T> unwrap() async => (await this).fold((f) => throw f, (v) => v);
}
