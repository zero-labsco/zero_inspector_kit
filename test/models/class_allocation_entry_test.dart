import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/class_allocation_entry.dart';

void main() {
  group('ClassAllocationEntry.fromJson', () {
    test('parses new/old HeapSpace and sorts by bytes desc', () {
      final json = <String, dynamic>{
        'type': 'AllocationProfile',
        'classes': <dynamic>[
          {
            'type': 'ClassHeapStats',
            'class': <String, dynamic>{
              'type': '@Class',
              'id': 'classes/1',
              'name': 'String',
            },
            'new': <String, dynamic>{
              'type': 'HeapSpace',
              'name': 'new',
              'count': 100,
              'size': 4096,
            },
            'old': <String, dynamic>{
              'type': 'HeapSpace',
              'name': 'old',
              'count': 900,
              'size': 90000,
            },
          },
          {
            'class': <String, dynamic>{'id': 'classes/2', 'name': 'Uint8List'},
            'new': <String, dynamic>{'count': 50, 'size': 200000},
            'old': <String, dynamic>{'count': 0, 'size': 0},
          },
        ],
      };

      final list = ClassAllocationEntry.fromJson(json);
      expect(list, hasLength(2));

      // 按字节降序：Uint8List (200000) 在前，String (94096) 在后
      // Sorted by bytes desc: Uint8List (200000) first, String (94096) after.
      expect(list[0].className, 'Uint8List');
      expect(list[0].instances, 50);
      expect(list[0].bytes, 200000);
      expect(list[0].newBytes, 200000);

      expect(list[1].className, 'String');
      expect(list[1].instances, 1000);
      expect(list[1].bytes, 94096);
      expect(list[1].newBytes, 4096);
    });

    test('falls back to legacy top-level count/size fields', () {
      final json = <String, dynamic>{
        'type': 'AllocationProfile',
        'classes': <dynamic>[
          {
            'class': <String, dynamic>{'name': 'Foo'},
            'count': 10,
            'size': 1000,
          },
          {
            'class': <String, dynamic>{'name': 'Bar'},
            'instances': 5,
            'bytes': 500,
          },
        ],
      };

      final list = ClassAllocationEntry.fromJson(json);
      expect(list, hasLength(2));
      expect(list[0].className, 'Foo');
      expect(list[0].instances, 10);
      expect(list[0].bytes, 1000);
      expect(list[1].className, 'Bar');
      expect(list[1].instances, 5);
      expect(list[1].bytes, 500);
    });

    test('skips sentinel / empty / zero-only entries', () {
      final json = <String, dynamic>{
        'type': 'AllocationProfile',
        'classes': <dynamic>[
          {
            'class': <String, dynamic>{'name': '::'},
            'new': <String, dynamic>{'count': 5, 'size': 10},
            'old': <String, dynamic>{'count': 0, 'size': 0},
          },
          {
            'class': <String, dynamic>{'name': ''},
            'new': <String, dynamic>{'count': 5, 'size': 10},
            'old': <String, dynamic>{'count': 0, 'size': 0},
          },
          {
            'class': <String, dynamic>{'name': 'Zero'},
            'new': <String, dynamic>{'count': 0, 'size': 0},
            'old': <String, dynamic>{'count': 0, 'size': 0},
          },
          {
            'class': <String, dynamic>{'name': 'Real'},
            'new': <String, dynamic>{'count': 1, 'size': 100},
            'old': <String, dynamic>{'count': 0, 'size': 0},
          },
        ],
      };

      final list = ClassAllocationEntry.fromJson(json);
      expect(list, hasLength(1));
      expect(list.single.className, 'Real');
      expect(list.single.bytes, 100);
    });

    test('returns empty list when classes is missing or wrong type', () {
      expect(
        ClassAllocationEntry.fromJson(<String, dynamic>{
          'type': 'AllocationProfile',
        }),
        isEmpty,
      );
      expect(
        ClassAllocationEntry.fromJson(<String, dynamic>{
          'type': 'AllocationProfile',
          'classes': 'not-a-list',
        }),
        isEmpty,
      );
    });
  });
}
