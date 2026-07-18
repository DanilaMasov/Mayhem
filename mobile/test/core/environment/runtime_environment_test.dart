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

  test('uses native flavor when no explicit environment is provided', () {
    expect(
      MayhemRuntimeEnvironment.resolve(
        configured: '',
        releaseMode: true,
        flavor: 'staging',
      ),
      MayhemRuntimeEnvironment.staging,
    );
    expect(
      MayhemRuntimeEnvironment.resolve(
        configured: '',
        releaseMode: true,
        flavor: 'production',
      ),
      MayhemRuntimeEnvironment.production,
    );
  });

  test('rejects conflicting native flavor and explicit environment', () {
    expect(
      () => MayhemRuntimeEnvironment.resolve(
        configured: 'production',
        releaseMode: true,
        flavor: 'staging',
      ),
      throwsFormatException,
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
    expect(
      () => MayhemRuntimeEnvironment.resolve(
        configured: '',
        releaseMode: false,
        flavor: 'preview',
      ),
      throwsFormatException,
    );
  });
}
