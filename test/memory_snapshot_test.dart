import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/memory_snapshot.dart';

void main() {
  group('MemorySnapshot.hasSameValues', () {
    test('returns true for identical fields (timestamp ignored)', () {
      final a = MemorySnapshot(processRss: 100);
      final b = MemorySnapshot(processRss: 100);
      expect(a.hasSameValues(b), isTrue);
      expect(b.hasSameValues(a), isTrue);
    });

    test('returns false when any numeric field differs', () {
      final base = MemorySnapshot(
        processRss: 100,
        totalPss: 50,
        heapUsage: 20,
        isHeapDataAvailable: true,
      );
      final differs = MemorySnapshot(
        processRss: 100,
        totalPss: 51,
        heapUsage: 20,
        isHeapDataAvailable: true,
      );
      expect(base.hasSameValues(differs), isFalse);
    });

    test('returns false when a bool flag flips', () {
      final base = MemorySnapshot(
        processRss: 100,
        isNativeDataAvailable: false,
      );
      final other = MemorySnapshot(
        processRss: 100,
        isNativeDataAvailable: true,
      );
      expect(base.hasSameValues(other), isFalse);
    });

    test('fromNativeMap + copyWithHeapData compare consistently', () {
      MemorySnapshot build() =>
          MemorySnapshot.fromNativeMap(
            processRss: 10,
            map: {
              'totalPss': 5,
              'dalvikPss': 3,
              'nativePrivateDirty': 2,
              'physicalFootprint': 7,
              'availMem': 999,
            },
            isHeapDataAvailable: true,
          ).copyWithHeapData(
            heapUsage: 1,
            heapCapacity: 2,
            externalUsage: 0,
            newSpaceUsage: 0,
            newSpaceCapacity: 0,
            newSpaceExternalUsage: 0,
            oldSpaceUsage: 0,
            oldSpaceCapacity: 0,
            oldSpaceExternalUsage: 0,
            isHeapDataAvailable: true,
          );
      expect(build().hasSameValues(build()), isTrue);
      expect(
        build().hasSameValues(
          build().copyWithHeapData(
            heapUsage: 2,
            heapCapacity: 2,
            externalUsage: 0,
            newSpaceUsage: 0,
            newSpaceCapacity: 0,
            newSpaceExternalUsage: 0,
            oldSpaceUsage: 0,
            oldSpaceCapacity: 0,
            oldSpaceExternalUsage: 0,
            isHeapDataAvailable: true,
          ),
        ),
        isFalse,
      );
    });
  });
}
