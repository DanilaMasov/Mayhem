import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/environment/runtime_environment.dart';

void main() {
  test('defaults debug to development and release to production', () {
    expect(
      MayhemRuntimeEnvironment.resolve(configured: '', releaseMode: false),
      MayhemRuntimeEnvironment.development,
    );
    expect(
      MayhemRuntimeEnvironment.resolve(configured: '', releaseMode: true),
      MayhemRuntimeEnvironment.production,
    );
  });

  test('normalizes explicit staging and production environments', () {
    expect(
      MayhemRuntimeEnvironment.resolve(
        configured: ' Staging ',
        releaseMode: true,
      ),
      MayhemRuntimeEnvironment.staging,
    );
    expect(
      MayhemRuntimeEnvironment.resolve(
        configured: 'PRODUCTION',
        releaseMode: false,
      ),
      MayhemRuntimeEnvironment.production,
    );
  });

  test('rejects unknown environments and development release targets', () {
    expect(
      () => MayhemRuntimeEnvironment.resolve(
        configured: 'prodution',
        releaseMode: true,
      ),
      throwsFormatException,
    );
    expect(
      () => MayhemRuntimeEnvironment.resolve(
        configured: 'development',
        releaseMode: true,
      ),
      throwsFormatException,
    );
  });
}
