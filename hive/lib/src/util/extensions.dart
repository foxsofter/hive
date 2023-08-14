import 'dart:math';
import 'dart:typed_data';

/// Not part of public API
extension StringX on String {
  /// Not part of public API
  bool get isAscii {
    for (var cu in codeUnits) {
      if (cu > 127) return false;
    }
    return true;
  }
}

/// Not part of public API
extension ListIntX on List<int> {
  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  int readUint32(int offset) {
    return this[offset] |
        this[offset + 1] << 8 |
        this[offset + 2] << 16 |
        this[offset + 3] << 24;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void writeUint32(int offset, int value) {
    this[offset] = value;
    this[offset + 1] = value >> 8;
    this[offset + 2] = value >> 16;
    this[offset + 3] = value >> 24;
  }
}

/// Not part of public API
extension Uint8ListX on Uint8List {
  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Uint8List view(int offset, int bytes) {
    return Uint8List.view(buffer, offsetInBytes + offset, bytes);
  }
}

/// Not part of public API
extension RandomX on Random {
  /// Not part of public API
  Uint8List nextBytes(int bytes) {
    var buffer = Uint8List(bytes);
    for (var i = 0; i < bytes; i++) {
      buffer[i] = nextInt(0xFF + 1);
    }
    return buffer;
  }
}

extension MapX<K, V> on Map<K, V> {
  /// The matching elements.
  ///
  Map<K, V> where(bool Function(K, V) test) {
    final ret = <MapEntry<K, V>>[];
    final es = entries;
    for (var e in es) {
      if (test(e.key, e.value)) {
        ret.add(e);
      }
    }
    return Map.fromEntries(ret);
  }

  /// The matching elements.
  ///
  Map<K, VT> whereValueType<VT>() {
    final ret = <MapEntry<K, VT>>[];
    final es = entries;
    for (var e in es) {
      final v = e.value;
      if (v is VT) {
        ret.add(MapEntry<K, VT>(e.key, v));
      }
    }
    return Map.fromEntries(ret);
  }
}
