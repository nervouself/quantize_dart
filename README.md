# quantize_dart

The Dart implementation of quantize, based on [quantize](https://github.com/lokesh/quantize).

## Usage

`````dart
import 'package:quantize_dart/quantize_dart.dart';

final arrayOfPixels = [[190,197,190], [202,204,200], [207,214,210], [211,214,211], [205,207,207]];
final maximumColorCount = 4;

final colorMap = quantize(arrayOfPixels, maximumColorCount);
`````

* `arrayOfPixels` - A list of pixels (represented as [R,G,B arrays]) to quantize
* `maxiumColorCount` - The maximum number of colours allowed in the reduced palette

#### Reduced Palette

The `.palette()` method returns a list that contains the reduced color palette.

`````dart
// Returns the reduced palette
colorMap.palette(); 
// [[204, 204, 204], [208,212,212], [188,196,188], [212,204,196]]
`````

#### Reduced pixel

The `.map(pixel)` method maps an individual pixel to the reduced color palette.

`````dart
// Returns the reduced pixel
colorMap.map(arrayOfPixels[0]);
// [188,196,188]
`````

## License

Licensed under the MIT License.
