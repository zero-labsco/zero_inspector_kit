import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ZeroInspectorKit init can be called', () {
    ZeroInspectorKit.init();
    expect(true, isTrue);
  });

  test('ZeroInspectorKit wrapApp returns a Widget', () {
    final widget = ZeroInspectorKit.wrapApp(const SizedBox());
    expect(widget, isNotNull);
    expect(widget, isA<Widget>());
  });

  test('InspectorLogInterceptor singleton exists', () {
    final interceptor = InspectorLogInterceptor.instance;
    expect(interceptor, isNotNull);
  });

  test('InspectorHttpInterceptor singleton exists', () {
    final interceptor = InspectorHttpInterceptor.instance;
    expect(interceptor, isNotNull);
  });

  test('InspectorService singleton exists', () {
    final service = InspectorService.instance;
    expect(service, isNotNull);
  });

  test('DatabaseService singleton exists', () {
    final service = DatabaseService.instance;
    expect(service, isNotNull);
  });
}
