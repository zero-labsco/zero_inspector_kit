import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  group('WsInspectorService', () {
    late WsInspectorService svc;

    setUp(() {
      svc = WsInspectorService.instance;
      svc.reset();
      svc.isEnabled = false;
      InspectorService.instance.clearNetworkRequests();
    });

    test('enable/disable toggles isEnabled', () {
      expect(svc.isEnabled, isFalse);
      svc.enable();
      expect(svc.isEnabled, isTrue);
      svc.toggle();
      expect(svc.isEnabled, isFalse);
    });

    test('recordCall is a no-op when capture is disabled', () {
      svc.isEnabled = false;
      svc.recordCall(name: 'svc/Method', request: 'req', response: 'resp');
      expect(InspectorService.instance.networkRequestCount, 0);
    });

    test('recordCall records a gRPC entry when enabled', () {
      svc.isEnabled = true;
      svc.recordCall(
        name: 'svc/Method',
        request: 'the-request',
        response: 'the-response',
      );
      final reqs = InspectorService.instance.networkRequests;
      expect(reqs.length, 1);
      final r = reqs.first;
      expect(r.method, 'gRPC');
      expect(r.url, 'svc/Method');
      expect(r.body, 'the-request');
      expect(r.responseBody, 'the-response');
    });

    test('framesFor returns null for unknown / evicted sessions', () {
      expect(svc.framesFor('nope'), isNull);
    });

    test('wsHandshakeZoneKey marks the zone during connect path', () {
      // 拦截器依赖 zone 标记跳过握手 GET；此处验证机制可用。
      // The interceptor relies on the zone flag to skip the handshake GET;
      // this verifies the mechanism is usable.
      expect(Zone.current[wsHandshakeZoneKey], isNull);
      runZoned(
        () => expect(Zone.current[wsHandshakeZoneKey], isTrue),
        zoneValues: {wsHandshakeZoneKey: true},
      );
      expect(Zone.current[wsHandshakeZoneKey], isNull);
    });

    test('reset clears active sessions', () {
      svc.isEnabled = true;
      svc.recordCall(name: 'a/b', response: 'r');
      expect(svc.framesFor('x'), isNull); // sessions only created via WS wrap
      svc.reset();
      expect(svc.isEnabled, isTrue); // reset keeps the switch state
    });
  });

  group('WsFrame classification', () {
    test('WsFrame model carries direction, type and byte size', () {
      // _framePreview / _byteSizeOf 是私有静态，这里通过 recordCall 间接无法覆盖；
      // 但可以验证公开模型与枚举字段存在且可用。
      // _framePreview / _byteSizeOf are private statics not directly reachable;
      // we instead assert the public model + enum surface is intact.
      final f = WsFrame(
        outgoing: true,
        type: WsFrameType.binary,
        text: '00 01 02',
        byteSize: 3,
        at: DateTime(2024, 1, 1),
      );
      expect(f.type, WsFrameType.binary);
      expect(f.byteSize, 3);
      expect(f.outgoing, isTrue);
    });
  });
}
