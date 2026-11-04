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
}
