import 'package:dio/dio.dart';

/// Calls [onDisabled] when the API answers 403 `FEATURE_DISABLED`: the clinic
/// switched a feature off while the app was open, so the cached switches are
/// stale and must be re-read. The error itself still reaches the caller. The
/// `/features` call is skipped (it can never be disabled) so it cannot loop.
class FeatureDisabledInterceptor extends Interceptor {
  FeatureDisabledInterceptor(this.onDisabled);

  final void Function() onDisabled;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final data = err.response?.data;
    if (err.response?.statusCode == 403 &&
        data is Map &&
        data['code'] == 'FEATURE_DISABLED' &&
        !err.requestOptions.path.endsWith('/features')) {
      onDisabled();
    }
    handler.next(err);
  }
}
