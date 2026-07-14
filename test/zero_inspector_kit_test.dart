import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ZeroInspectorKit instance creation', () {
    final kit = ZeroInspectorKit();
    expect(kit, isNotNull);
  });

  test('getPlatformVersion returns a Future', () {
    final kit = ZeroInspectorKit();
    final result = kit.getPlatformVersion();
    expect(result, isA<Future<String?>>());
  });
}