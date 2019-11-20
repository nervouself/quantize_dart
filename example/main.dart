import 'package:quantize_dart/quantize_dart.dart';

void main() {

  final arrayOfPixels = [[190,197,190], [202,204,200], [207,214,210], [211,214,211], [205,207,207]];
  final maximumColorCount = 4;
  final colorMap = quantize(arrayOfPixels, maximumColorCount);

  final palette = [[204,204,204], [208,212,212], [188,196,188], [212,204,196]];
  print(palette);

  final palette2 = colorMap.map(arrayOfPixels[0]);
  print(palette2);

}