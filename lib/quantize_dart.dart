/*
 * quantize.js Copyright 2008 Nick Rabinowitz
 * Ported to node.js by Olivier Lesnicki
 * Ported to Dart by Shi Lei
 * Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php
 */
// fill out a couple protovis dependencies
/*
 * Block below copied from Protovis: http://mbostock.github.com/protovis/
 * Copyright 2010 Stanford Visualization Group
 * Licensed under the BSD License: http://www.opensource.org/licenses/bsd-license.php
 */

import 'dart:math' as math;

class _PV {
  static map(List array, [Function f]) {
    return f != null
      ? array.map((d) {
        return f(d);
      }).toList()
      : List.from(array);
  }

  static int naturalOrder(a, b) {
    return a < b ? -1 : a > b ? 1 : 0;
  }

  static sum(List array, [Function f]) {
    final combine = f != null
      ? (p, d, i) {
        return p + f(d);
      }
      : (p, d) {
        return p + d;
      };
    return array.fold(0, combine);
  }

  static max(List array, [Function f]) {
    final list = f != null ? _PV.map(array, f) : array;
    int max = list.first;
    list.skip(1).forEach((element) {
      max = math.max(max, element);
    });
    return max;
  }
}

var _sigbits = 5,
    _rshift = 8 - _sigbits,
    _maxIterations = 1000,
    _fractByPopulations = 0.75;

_getColorIndex(r, g, b) {
  return (r << 2 * _sigbits) + (g << _sigbits) + b;
}

class PQueue {
  int Function(dynamic, dynamic) comparator;

  PQueue(this.comparator);

  var contents = List(),
      sorted = false;

  sort() {
    contents.sort(comparator);
    sorted = true;
  }

  push(o) {
    contents.add(o);
    sorted = false;
  }
  peek(index) {
    if (!sorted) { sort(); }
    if (index == null) { index = contents.length - 1; }
    return contents[index];
  }
  pop() {
    if (!sorted) { sort(); }
    return contents.removeLast();
  }
  size() {
    return contents.length;
  }
  map(f) {
    return contents.map(f).toList();
  }
  debug() {
    if (!sorted) { sort(); }
    return contents;
  }
}

class VBox {
  var r1;
  var r2;
  var g1;
  var g2;
  var b1;
  var b2;
  var histo;

  VBox(
    this.r1,
    this.r2,
    this.g1,
    this.g2,
    this.b1,
    this.b2,
    this.histo,
  );

  var _volume;
  volume([force]) {
    if (_volume == null || force == true) {
      _volume = (r2 - r1 + 1) * (g2 - g1 + 1) * (b2 - b1 + 1);
    }

    return _volume;
  }

  var _countSet;
  var _count;
  count([force]) {
    if (_countSet == null || force == true) {
      var npix = 0,
          i,
          j,
          k,
          index;

      for (i = r1; i <= r2; i++) {
        for (j = g1; j <= g2; j++) {
          for (k = b1; k <= b2; k++) {
            index = _getColorIndex(i, j, k);
            npix += histo[index] == null ? 0 : histo[index];
          }
        }
      }

      _count = npix;
      _countSet = true;
    }

    return _count;
  }

  copy() {
    return VBox(r1, r2, g1, g2, b1, b2, histo);
  }

  var _avg;
  avg([force]) {
    if (_avg == null || force == true) {
      var ntot = 0.0,
          mult = 1 << 8 - _sigbits,
          rsum = 0.0,
          gsum = 0.0,
          bsum = 0.0,
          hval,
          i,
          j,
          k,
          histoindex;

      for (i = r1; i <= r2; i++) {
        for (j = g1; j <= g2; j++) {
          for (k = b1; k <= b2; k++) {
            histoindex = _getColorIndex(i, j, k);
            hval = histo[histoindex] == null ? 0 : histo[histoindex];
            ntot += hval;
            rsum += hval * (i + 0.5) * mult;
            gsum += hval * (j + 0.5) * mult;
            bsum += hval * (k + 0.5) * mult;
          }
        }
      }

      if (ntot != 0) {
        _avg = [(rsum ~/ ntot), (gsum ~/ ntot), (bsum ~/ ntot)];
      } else {
        _avg = [(mult * (r1 + r2 + 1) ~/ 2), (mult * (g1 + g2 + 1) ~/ 2), (mult * (b1 + b2 + 1) ~/ 2)];
      }
    }

    return _avg;
  }

  contains(pixel) {
    var rval = pixel[0] >> _rshift,
        gval = pixel[1] >> _rshift,
        bval = pixel[2] >> _rshift;
    return rval >= r1 && rval <= r2 && gval >= g1 && gval <= g2 && bval >= b1 && bval <= b2;
  }
}

class VBoxElement {
  var vbox, color;

  VBoxElement(this.vbox, this.color);
}

class CMap {

  var vboxes;
  CMap() {
    this.vboxes = PQueue((a, b) {
      return _PV.naturalOrder(a.vbox.count() * a.vbox.volume(), b.vbox.count() * b.vbox.volume());
    });
  }

  push(vbox) {
    this.vboxes.push(VBoxElement(vbox, vbox.avg()));
  }
  palette() {
    return this.vboxes.map((vb) {
      return vb.color;
    });
  }
  size() {
    return this.vboxes.size();
  }
  map(color) {
    var vboxes = this.vboxes;

    for (var i = 0; i < vboxes.size(); i++) {
      if (vboxes.peek(i).vbox.contains(color)) {
        return vboxes.peek(i).color;
      }
    }

    return this.nearest(color);
  }
  nearest(color) {
    var vboxes = this.vboxes,
        d1,
        d2,
        pColor;

    for (var i = 0; i < vboxes.size(); i++) {
      d2 = math.sqrt(math.pow(color[0] - vboxes.peek(i).color[0], 2) + math.pow(color[1] - vboxes.peek(i).color[1], 2) + math.pow(color[2] - vboxes.peek(i).color[2], 2));

      if (d2 < d1 || d1 == null) {
        d1 = d2;
        pColor = vboxes.peek(i).color;
      }
    }

    return pColor;
  }
  forcebw() {
    var vboxes = this.vboxes;
    vboxes.sort((a, b) {
      return _PV.naturalOrder(_PV.sum(a.color), _PV.sum(b.color));
    });

    var lowest = vboxes[0].color;
    if (lowest[0] < 5 && lowest[1] < 5 && lowest[2] < 5) { vboxes[0].color = [0, 0, 0]; } // force lightest color to white if everything > 251

    var idx = vboxes.length - 1,
        highest = vboxes[idx].color;
    if (highest[0] > 251 && highest[1] > 251 && highest[2] > 251) { vboxes[idx].color = [255, 255, 255]; }
  }

}

_getHisto(List pixels) {
  var histosize = 1 << 3 * _sigbits,
      histo = List(histosize),
      index,
      rval,
      gval,
      bval;
  pixels.forEach((pixel) {
    rval = pixel[0] >> _rshift;
    gval = pixel[1] >> _rshift;
    bval = pixel[2] >> _rshift;
    index = _getColorIndex(rval, gval, bval);
    histo[index] = (histo[index] == null ?  0 : histo[index]) + 1;
  });
  return histo;
}

_vboxFromPixels(List pixels, histo) {
  var rmin = 1000000,
      rmax = 0,
      gmin = 1000000,
      gmax = 0,
      bmin = 1000000,
      bmax = 0,
      rval,
      gval,
      bval;

  pixels.forEach((pixel) {
    rval = pixel[0] >> _rshift;
    gval = pixel[1] >> _rshift;
    bval = pixel[2] >> _rshift;
    if (rval < rmin) { rmin = rval; }else if (rval > rmax) { rmax = rval; }
    if (gval < gmin) { gmin = gval; }else if (gval > gmax) { gmax = gval; }
    if (bval < bmin) { bmin = bval; }else if (bval > bmax) { bmax = bval; }
  });
  return VBox(rmin, rmax, gmin, gmax, bmin, bmax, histo);
}

_safeSetArray(List list, index, element) {
  if (!(list.length > index)) {
    list.addAll(List(index - list.length + 1));
  }
  list[index] = element;
}

_medianCutApply(histo, VBox vbox) {
  if (vbox.count() == 0) {
    return [null, null];
  }
  var rw = vbox.r2 - vbox.r1 + 1,
      gw = vbox.g2 - vbox.g1 + 1,
      bw = vbox.b2 - vbox.b1 + 1,
      maxw = _PV.max([rw, gw, bw]);

  if (vbox.count() == 1) {
    return [vbox.copy()];
  }

  var total = 0,
      partialsum = List(),
      lookaheadsum = List(),
      i,
      j,
      k,
      sum,
      index;

  if (maxw == rw) {
    for (i = vbox.r1; i <= vbox.r2; i++) {
      sum = 0;

      for (j = vbox.g1; j <= vbox.g2; j++) {
        for (k = vbox.b1; k <= vbox.b2; k++) {
          index = _getColorIndex(i, j, k);
          sum += histo[index] == null ? 0 : histo[index];
        }
      }

      total += sum;
      _safeSetArray(partialsum, i, total);
    }
  } else if (maxw == gw) {
    for (i = vbox.g1; i <= vbox.g2; i++) {
      sum = 0;

      for (j = vbox.r1; j <= vbox.r2; j++) {
        for (k = vbox.b1; k <= vbox.b2; k++) {
          index = _getColorIndex(j, i, k);
          sum += histo[index] == null ? 0 : histo[index];
        }
      }

      total += sum;
      _safeSetArray(partialsum, i, total);
    }
  } else {
    /* maxw == bw */
    for (i = vbox.b1; i <= vbox.b2; i++) {
      sum = 0;

      for (j = vbox.r1; j <= vbox.r2; j++) {
        for (k = vbox.g1; k <= vbox.g2; k++) {
          index = _getColorIndex(j, k, i);
          sum += histo[index] == null ? 0 : histo[index];
        }
      }

      total += sum;
      _safeSetArray(partialsum, i, total);
    }
  }

  partialsum.forEach((d) {
    final i = partialsum.indexOf(d);
    _safeSetArray(lookaheadsum, i, total - (d == null ? 0 : d));
  });

  doCut(color) {
    num vboxdim1;
    num vboxdim2;
    num left;
    num right;
    var vbox1,
        vbox2,
        d2,
        count2 = 0;

    switch (color) {
      case 'r':
        vboxdim1 = vbox.r1;
        vboxdim2 = vbox.r2;
        break;
      case 'g':
        vboxdim1 = vbox.g1;
        vboxdim2 = vbox.g2;
        break;
      case 'b':
        vboxdim1 = vbox.b1;
        vboxdim2 = vbox.b2;
        break;
      default:
    }

    for (num i = vboxdim1; i <= vboxdim2; i++) {
      if (partialsum[i] > total / 2) {
        vbox1 = vbox.copy();
        vbox2 = vbox.copy();
        left = i - vboxdim1;
        right = vboxdim2 - i;
        if (left <= right) {
          d2 = math.min(vboxdim2 - 1, (i + right / 2) ~/ 1);
        } else {
          d2 = math.max(vboxdim1, (i - 1 - left / 2) ~/ 1);
        }

        while (partialsum[d2] == null || partialsum[d2] == 0) { d2++; }

        count2 = lookaheadsum[d2];

        while ((count2 == 0 || count2 == null) && (partialsum[d2 - 1] != null && partialsum[d2 - 1] != 0)) {
          count2 = lookaheadsum[--d2];
        }

        switch (color) {
          case 'r':
            vbox1.r2 = d2;
            vbox2.r1 = vbox1.r2 + 1;
            break;
          case 'g':
            vbox1.g2 = d2;
            vbox2.g1 = vbox1.g2 + 1;
            break;
          case 'b':
            vbox1.b2 = d2;
            vbox2.b1 = vbox1.b2 + 1;
            break;
          default:
        }

        return [vbox1, vbox2];
      }
    }
    return [null, null];
  }

  return maxw == rw ? doCut('r') : maxw == gw ? doCut('g') : doCut('b');
}

/// Usually returns an instance of `CMap`,
/// returns `null` If the parameter is unqualified
/// 
/// `pixels` - A list of pixels (represented as [[R,G,B]]) to quantize
/// 
/// `maxcolors` - The maximum number of colours allowed in the reduced palette, between 2 and 256
/// 
/// The `CMap.palette()` method returns a list that contains the reduced color palette
/// 
/// The `CMap.map(pixel)` method maps an individual pixel to the reduced color palette (pixel represented as [R,G,B])
quantize(List<List<int>> pixels, int maxcolors) {
  if (pixels.isEmpty || maxcolors < 2 || maxcolors > 256) {
    return null;
  }

  var histo = _getHisto(pixels);

  var vbox = _vboxFromPixels(pixels, histo),
      pq = PQueue((a, b) {
        return _PV.naturalOrder(a.count(), b.count());
      });
  pq.push(vbox);

  iter(lh, target) {
    var ncolors = lh.size(),
        niters = 0,
        vbox;

    while (niters < _maxIterations) {
      if (ncolors >= target) { return; }

      if (niters++ > _maxIterations) {
        return;
      }

      vbox = lh.pop();

      if (vbox.count() == 0) {
        lh.push(vbox);
        niters++;
        continue;
      }

      var vboxes = _medianCutApply(histo, vbox),
          vbox1 = vboxes[0],
          vbox2 = vboxes[1];

      if (vbox1 == null) {
        return;
      }

      lh.push(vbox1);

      if (vbox2 != null) {
        lh.push(vbox2);
        ncolors++;
      }
    }
  }

  iter(pq, _fractByPopulations * maxcolors);

  var pq2 = PQueue((a, b) {
    return _PV.naturalOrder(a.count() * a.volume(), b.count() * b.volume());
  });

  while (pq.size() != 0) {
    pq2.push(pq.pop());
  }

  iter(pq2, maxcolors);

  var cmap = CMap();

  while (pq2.size() != 0) {
    cmap.push(pq2.pop());
  }

  return cmap;
}

