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

  test('buildReplayRequest honors an edited query-param URL', () {
    // 重放编辑器仅允许修改查询参数：用编辑后的 URL 重建请求时，
    // method / headers / body 保持原样，URL 指向新查询。
    // The replay editor only lets you edit query params: when replayed with the
    // rebuilt URL, method / headers / body stay verbatim and the URL carries the
    // new query.
    final r = NetworkRequest(
      id: '1',
      method: 'get',
      url: 'https://example.com/api?page=1&q=old',
      headers: {'X-Test': '1'},
      requestTime: 0,
    );
    const editedUrl = 'https://example.com/api?page=2&q=new&sort=asc';
    final req = buildReplayRequest(r, url: editedUrl);
    expect(req.method, 'GET');
    expect(req.url.toString(), editedUrl);
    expect(req.headers['X-Test'], '1');
  });

  test('buildReplayRequest keeps original URL when none edited', () {
    final r = NetworkRequest(
      id: '1',
      method: 'get',
      url: 'https://example.com/api?a=1',
      requestTime: 0,
    );
    final req = buildReplayRequest(r);
    expect(req.url.toString(), 'https://example.com/api?a=1');
  });

  test('rebuilt query preserves order and updated values', () {
    // 与编辑器 _rebuildUrl 等价的纯函数校验：编辑后参数顺序与值正确。
    // Pure-function check mirroring the editor's _rebuildUrl: order and values
    // survive the rebuild.
    final map = {'page': '2', 'q': 'new', 'sort': 'asc'};
    final rebuilt = Uri.parse(
      'https://example.com/api?page=1',
    ).replace(queryParameters: map).toString();
    expect(rebuilt, 'https://example.com/api?page=2&q=new&sort=asc');
  });
}
