import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/network_request.dart';
import 'package:zero_inspector_kit/src/utils/network_replay.dart';

void main() {
  test('buildReplayRequest reconstructs method, url and headers', () {
    final r = NetworkRequest(
      id: '1',
      method: 'post',
      url: 'https://example.com/api',
      headers: {'X-Test': '1'},
      body: 'payload',
      requestTime: 0,
    );
    final req = buildReplayRequest(r);
    expect(req.method, 'POST');
    expect(req.url.toString(), 'https://example.com/api');
    expect(req.headers['X-Test'], '1');
    expect(req.body, 'payload');
  });

  test('buildReplayRequest uses bodyBytes for binary body', () {
    final r = NetworkRequest(
      id: '1',
      method: 'PUT',
      url: 'https://example.com/b',
      body: [1, 2, 3],
      requestTime: 0,
    );
    final req = buildReplayRequest(r);
    expect(req.bodyBytes, [1, 2, 3]);
  });
}
