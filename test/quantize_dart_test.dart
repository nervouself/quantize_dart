import 'package:quantize_dart/quantize_dart.dart';
import 'package:test/test.dart';

void main() {

  group("test quantize", () {

    final arrayOfPixels = [[190,197,190], [202,204,200], [207,214,210], [211,214,211], [205,207,207]];
    final maximumColorCount = 4;
    final colorMap = quantize(arrayOfPixels, maximumColorCount);

    test('quantize => CMap', () {
      expect(colorMap.runtimeType, CMap);
      expect(colorMap.palette != null, true);
      expect(colorMap.map != null, true);
    });

    test('CMap.palette => []', () {
      final res = [[204,204,204], [208,212,212], [188,196,188], [212,204,196]];
      expect(colorMap.palette().toString(), res.toString());
    });

    test('CMap.map => []', () {
      expect(colorMap.map(arrayOfPixels[0]).toString(), [188,196,188].toString());
    });
  });

}
