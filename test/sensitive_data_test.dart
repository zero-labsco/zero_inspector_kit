import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// 会话存档与网络导出共用的 JSON 快照脱敏回归测试。
/// Regression tests for the JSON-snapshot masking shared by the session
/// archive and network exports.
void main() {
  test('maskNetworkJson covers headers, URL query and both bodies', () {
    final original = <String, dynamic>{
      'id': 'r1',
      'method': 'GET',
      'url': 'https://example.com/api?token=abc123',
      'headers': <String, dynamic>{
        'Authorization': 'Bearer abc123',
        'Accept': 'application/json',
      },
      'body': '{"password":"hunter2"}',
      'responseBody': 'Bearer eyJhbGciOi.abcdefgh.ijklmnop',
      'statusCode': 200,
    };

    final masked = SensitiveData.maskNetworkJson(original);

    expect(masked['headers']['Authorization'], SensitiveData.placeholder);
    expect(masked['headers']['Accept'], 'application/json');
    expect(masked['url'], isNot(contains('abc123')));
    // Uri.replace 会把占位符编码成 %2A%2A%2A，因此只断言敏感值已消失。
    // Uri.replace percent-encodes the placeholder, so assert the secret is gone.
    expect(masked['url'], contains('token='));
    expect(masked['body'], isNot(contains('hunter2')));
    expect(masked['responseBody'], isNot(contains('eyJhbGciOi')));
    expect(masked['statusCode'], 200);
    expect(masked['id'], 'r1');
    // 不得就地修改输入，否则导出 / 回放仍会拿到脱敏后的数据。
    // Must not mutate the input, or exports / replay would lose the original.
    expect(original['url'], 'https://example.com/api?token=abc123');
    expect(original['headers']['Authorization'], 'Bearer abc123');
  });

  test('maskNetworkJson tolerates missing / null fields', () {
    final masked = SensitiveData.maskNetworkJson(<String, dynamic>{
      'id': 'r2',
      'url': 'https://example.com/ping',
      'headers': null,
      'body': null,
      'responseBody': null,
    });
    expect(masked['url'], 'https://example.com/ping');
    expect(masked['headers'], isNull);
    expect(masked['body'], isNull);
    expect(masked['responseBody'], isNull);
  });

  test(
    'maskBody masks credentials / PII in valid JSON under ordinary keys',
    () {
      // 结构化 JSON 路径此前只置空敏感**键**，非敏感键下的值级凭据原样导出。
      // The structured JSON path used to null only sensitive *keys*, leaking
      // credential / PII values stored under ordinary keys.
      const body =
          '{"phone":"13800138000",'
          '"message":"Bearer eyJhbGciOi.abcdefgh.ijklmnop",'
          '"nested":{"idCard":"11010119900101123X"}}';
      final masked = SensitiveData.maskBody(body);

      expect(masked, isNot(contains('13800138000')));
      expect(masked, isNot(contains('eyJhbGciOi')));
      expect(masked, isNot(contains('11010119900101123X')));
      // 脱敏后仍必须是合法 JSON，不能退化成整段占位符。
      // Masking must keep the payload valid JSON instead of collapsing it.
      expect(jsonDecode(masked), isA<Map>());
      expect(jsonDecode(masked)['phone'], SensitiveData.placeholder);
    },
  );

  test('maskUrl covers URL fragment and userInfo credentials', () {
    // OAuth implicit / OIDC return tokens in the fragment, invisible to
    // queryParameters. / OAuth implicit / OIDC 把 token 放在 fragment 里。
    final withFragment = SensitiveData.maskUrl(
      'https://example.com/cb#access_token=abc123&state=xyz',
    );
    expect(withFragment, isNot(contains('abc123')));
    expect(withFragment, contains('access_token='));
    expect(withFragment, contains('state=xyz'));

    final withUserInfo = SensitiveData.maskUrl(
      'https://user:s3cr3t@example.com/api',
    );
    expect(withUserInfo, isNot(contains('s3cr3t')));
    expect(withUserInfo, contains('example.com/api'));

    // 普通 URL 不应被改写。/ An ordinary URL must stay byte-identical.
    expect(
      SensitiveData.maskUrl('https://example.com/api?limit=10'),
      'https://example.com/api?limit=10',
    );
  });
}
