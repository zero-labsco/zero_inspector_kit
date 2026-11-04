import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// 记录调用次数的宿主 override，用来验证链式委托。
/// Host-side override that records calls so chaining can be asserted.
class _RecordingOverrides extends HttpOverrides {
  _RecordingOverrides(this.client);

  final HttpClient client;
  int calls = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    calls++;
    return client;
  }
}

void main() {
  HttpOverrides? original;
  late HttpClient rawClient;

  setUp(() {
    original = HttpOverrides.current;
    rawClient = HttpClient();
  });

  tearDown(() {
    HttpOverrides.global = original;
    InspectorHttpInterceptor.instance.stop();
    rawClient.close(force: true);
  });

  test('InspectorHttpOverrides chains over a host delegate', () {
    final delegate = _RecordingOverrides(rawClient);
    final client = InspectorHttpOverrides(delegate).createHttpClient(null);

    expect(delegate.calls, 1);
    // 返回的是检查器代理，而不是宿主原始 client。
    // The inspector proxy is returned, not the host's raw client.
    expect(client, isNot(same(rawClient)));
  });

  test('stop() preserves an override installed by the host after start()', () {
    final interceptor = InspectorHttpInterceptor.instance;
    interceptor.start();
    expect(HttpOverrides.current, isA<InspectorHttpOverrides>());

    final hostOverrides = _RecordingOverrides(rawClient);
    HttpOverrides.global = hostOverrides;

    interceptor.stop();
    expect(HttpOverrides.current, same(hostOverrides));
  });

  test('stop() restores the original override when nothing replaced it', () {
    final hostOverrides = _RecordingOverrides(rawClient);
    HttpOverrides.global = hostOverrides;

    final interceptor = InspectorHttpInterceptor.instance;
    interceptor.start();
    interceptor.stop();

    expect(HttpOverrides.current, same(hostOverrides));
  });

  test('reinstall() re-chains over the current override and is idempotent', () {
    final interceptor = InspectorHttpInterceptor.instance;
    interceptor.start();

    final hostOverrides = _RecordingOverrides(rawClient);
    HttpOverrides.global = hostOverrides;

    ZeroInspectorKit.reinstallHttpOverrides();
    final reinstalled = HttpOverrides.current;
    expect(reinstalled, isA<InspectorHttpOverrides>());
    expect(
      (reinstalled! as InspectorHttpOverrides).delegate,
      same(hostOverrides),
    );

    ZeroInspectorKit.reinstallHttpOverrides();
    expect(HttpOverrides.current, same(reinstalled));
  });

  test('createInspectorHttpClient works inside HttpOverrides.runZoned', () {
    HttpOverrides.runZoned(() {
      // zone 级 override 屏蔽了 global，但工厂仍应产出被包装的 client。
      // The zone-level override bypasses global, yet the factory must still
      // produce a wrapped client.
      final client = createInspectorHttpClient(null);
      expect(client, isNot(same(rawClient)));
    }, createHttpClient: createInspectorHttpClient);
  });
}
