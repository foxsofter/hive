import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/adapters/big_int_adapter.dart';
import 'package:hive/src/adapters/date_time_adapter.dart';
import 'package:hive/src/box/box_base_impl.dart';
import 'package:hive/src/box/box_impl.dart';
import 'package:hive/src/box/default_compaction_strategy.dart';
import 'package:hive/src/box/default_key_comparator.dart';
import 'package:hive/src/box/lazy_box_impl.dart';
import 'package:hive/src/registry/type_registry_impl.dart';
import 'package:hive/src/util/extensions.dart';

import 'backend/storage_backend.dart';

/// Not part of public API
class HiveImpl extends TypeRegistryImpl implements HiveInterface {
  static final BackendManagerInterface _defaultBackendManager =
      BackendManager.select();

  final _boxes = HashMap<TupleBoxKey, BoxBaseImpl>();
  final _openingBoxes = HashMap<TupleBoxKey, Future<bool>>();
  BackendManagerInterface? _managerOverride;
  final Random _secureRandom = Random.secure();

  String? homePath;

  bool useLocks = true;

  bool wasInitialized = false;

  /// Not part of public API
  HiveImpl() {
    _registerDefaultAdapters();
  }

  /// either returns the preferred [BackendManagerInterface] or the
  /// platform default fallback
  BackendManagerInterface get manager =>
      _managerOverride ?? _defaultBackendManager;

  void _registerDefaultAdapters() {
    registerAdapter(DateTimeWithTimezoneAdapter(), internal: true);
    registerAdapter(DateTimeAdapter<DateTimeWithoutTZ>(), internal: true);
    registerAdapter(BigIntAdapter(), internal: true);
  }

  @override
  void init(
    String? path, {
    HiveStorageBackendPreference backendPreference =
        HiveStorageBackendPreference.native,
    bool useLocks = true,
  }) {
    homePath = path;
    _managerOverride = BackendManager.select(backendPreference);
    this.useLocks = useLocks;
    wasInitialized = true;
  }

  Future<BoxBase<E>> _openBox<E>(
    String name,
    bool lazy,
    HiveCipher? cipher,
    KeyComparator comparator,
    CompactionStrategy compaction,
    bool recovery,
    String? path,
    StorageBackend? backend,
    String? collection,
  ) async {
    assert(path == null || backend == null);
    assert(name.length <= 255, 'Box names need to be a max length of 255.');
    name = name.toLowerCase();
    if (isBoxOpen(name)) {
      if (lazy) {
        return lazyBox(name);
      } else {
        return box(name);
      }
    } else {
      if (_openingBoxes.containsKey(TupleBoxKey(name, collection))) {
        bool? opened = await _openingBoxes[TupleBoxKey(name, collection)];
        if (opened ?? false) {
          if (lazy) {
            return lazyBox(name);
          } else {
            return box(name);
          }
        } else {
          throw HiveError('The opening of the box $name failed previously.');
        }
      }

      var completer = Completer<bool>();
      _openingBoxes[TupleBoxKey(name, collection)] = completer.future;

      BoxBaseImpl<E>? newBox;
      try {
        backend ??= await manager.open(
            name, path ?? homePath, recovery, cipher, collection);

        if (lazy) {
          newBox = LazyBoxImpl<E>(this, name, comparator, compaction, backend);
        } else {
          newBox = BoxImpl<E>(this, name, comparator, compaction, backend);
        }

        await newBox.initialize();
        _boxes[TupleBoxKey(name, collection)] = newBox;

        completer.complete(true);
        return newBox;
      } catch (error) {
        // Finish by signaling an error has occurred. We complete before closing
        // the box, because that can fail and this the Completer would never get
        // completed.
        completer.complete(false);
        // Await the closing of the box to prevent leaving a hanging Future
        // which could not be caught.
        await newBox?.close();
        rethrow;
      } finally {
        unawaited(_openingBoxes.remove(TupleBoxKey(name, collection)));
      }
    }
  }

  @override
  Future<Box<E>> openBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    @Deprecated('Use [backend] with a [StorageBackendMemory] instead')
    Uint8List? bytes,
    StorageBackend? backend,
    String? collection,
    @Deprecated('Use encryptionCipher instead') List<int>? encryptionKey,
  }) async {
    if (encryptionKey != null) {
      encryptionCipher = HiveAesCipher(encryptionKey);
    }
    if (backend == null && bytes != null) {
      backend = StorageBackendMemory(bytes, encryptionCipher);
    }
    return await _openBox<E>(
      name,
      false,
      encryptionCipher,
      keyComparator,
      compactionStrategy,
      crashRecovery,
      path,
      backend,
      collection,
    ) as Box<E>;
  }

  @override
  Future<Box<E>> openTypeBox<E>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      _openTypeBox<E>();

  Future<Box<E>> _openTypeBox<E>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) async {
    final adapter = _checkAndGetTypeAdapter(E);
    final boxName = adapter.typeId.toString();
    Box<E>? box;
    if (oldBox != null &&
        oldBox.isOpen &&
        !await manager.boxExists(boxName, path ?? homePath, collection)) {
      box = await _openBox<E>(
        boxName,
        false,
        encryptionCipher,
        keyComparator,
        compactionStrategy,
        crashRecovery,
        path,
        backend,
        collection,
      ) as Box<E>;
      final vals = oldBox.toMap().whereValueType<E>();
      await box.putAll(vals);
    }
    box ??= await _openBox<E>(
      boxName,
      false,
      encryptionCipher,
      keyComparator,
      compactionStrategy,
      crashRecovery,
      path,
      backend,
      collection,
    ) as Box<E>;
    return box;
  }

  @override
  Future<LazyBox<E>> openLazyBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
    @Deprecated('Use encryptionCipher instead') List<int>? encryptionKey,
    StorageBackend? backend,
  }) async {
    if (encryptionKey != null) {
      encryptionCipher = HiveAesCipher(encryptionKey);
    }
    return await _openBox<E>(
        name,
        true,
        encryptionCipher,
        keyComparator,
        compactionStrategy,
        crashRecovery,
        path,
        backend,
        collection) as LazyBox<E>;
  }

  @override
  Future<LazyBox<E>> openLazyTypeBox<E>({
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
    StorageBackend? backend,
  }) async {
    final adapter = _checkAndGetTypeAdapter(E);
    return await _openBox<E>(
        adapter.typeId.toString(),
        true,
        encryptionCipher,
        keyComparator,
        compactionStrategy,
        crashRecovery,
        path,
        backend,
        collection) as LazyBox<E>;
  }

  BoxBase<E> _getBoxInternal<E>(String name, [bool? lazy, String? collection]) {
    var lowerCaseName = name.toLowerCase();
    var box = _boxes[TupleBoxKey(lowerCaseName, collection)];
    if (box != null) {
      if ((lazy == null || box.lazy == lazy) && box.valueType == E) {
        return box as BoxBase<E>;
      } else {
        var typeName = box is LazyBox
            ? 'LazyBox<${box.valueType}>'
            : 'Box<${box.valueType}>';
        throw HiveError('The box "$lowerCaseName" is already open '
            'and of type $typeName.');
      }
    } else {
      throw HiveError('Box not found. Did you forget to open box?');
    }
  }

  /// Not part of public API
  BoxBase? getBoxWithoutCheckInternal(String name, [String? collection]) {
    print('Fetching box $name');
    print(_boxes.keys);
    var lowerCaseName = name.toLowerCase();
    print(_boxes.containsKey(TupleBoxKey(lowerCaseName, collection)));
    return _boxes[TupleBoxKey(lowerCaseName, collection)];
  }

  @override
  Box<E> box<E>(String name, [String? collection]) =>
      _getBoxInternal<E>(name, false, collection) as Box<E>;

  @override
  Box<E> typeBox<E>([String? collection]) {
    final adapter = _checkAndGetTypeAdapter(E);
    return _getBoxInternal<E>(
      adapter.typeId.toString(),
      false,
      collection,
    ) as Box<E>;
  }

  @override
  LazyBox<E> lazyBox<E>(String name, [String? collection]) =>
      _getBoxInternal<E>(name, true, collection) as LazyBox<E>;

  @override
  Box<E> lazyTypeBox<E>([String? collection]) {
    final adapter = _checkAndGetTypeAdapter(E);
    return _getBoxInternal<E>(
      adapter.typeId.toString(),
      true,
      collection,
    ) as Box<E>;
  }

  @override
  bool isBoxOpen(String name, [String? collection]) {
    return _boxes.containsKey(TupleBoxKey(name.toLowerCase(), collection));
  }

  @override
  bool isTypeBoxOpen<E>([String? collection]) {
    final adapter = _checkAndGetTypeAdapter(E);
    return _boxes.containsKey(TupleBoxKey(
      adapter.typeId.toString(),
      collection,
    ));
  }

  @override
  Future<void> close() {
    var closeFutures = _boxes.values.map((box) {
      return box.close();
    });

    return Future.wait(closeFutures);
  }

  /// Not part of public API
  void unregisterBox(String name, [String? collection]) {
    name = name.toLowerCase();
    _openingBoxes.remove(TupleBoxKey(name, collection));
    _boxes.remove(TupleBoxKey(name, collection));
  }

  @override
  Future<void> deleteBoxFromDisk(String name,
      {String? path, String? collection}) async {
    var lowerCaseName = name.toLowerCase();
    var box = _boxes[TupleBoxKey(lowerCaseName, collection)];
    if (box != null) {
      await box.deleteFromDisk();
    } else {
      await manager.deleteBox(lowerCaseName, path ?? homePath, collection);
    }
  }

  @override
  Future<void> deleteTypeBoxFromDisk<E>({
    String? path,
    String? collection,
  }) async {
    final adapter = _checkAndGetTypeAdapter(E);
    final name = adapter.typeId.toString();
    var box = _boxes[TupleBoxKey(name, collection)];
    if (box != null) {
      await box.deleteFromDisk();
    } else {
      await manager.deleteBox(name, path ?? homePath, collection);
    }
  }

  @override
  Future<void> deleteFromDisk() {
    var deleteFutures = _boxes.values.toList().map((box) {
      return box.deleteFromDisk();
    });

    return Future.wait(deleteFutures);
  }

  @override
  List<int> generateSecureKey() {
    return _secureRandom.nextBytes(32);
  }

  @override
  Future<bool> boxExists(String name,
      {String? path, String? collection}) async {
    var lowerCaseName = name.toLowerCase();
    return await manager.boxExists(lowerCaseName, path ?? homePath, collection);
  }

  @override
  Future<bool> typeBoxExists<E>({String? path, String? collection}) async {
    final adapter = _checkAndGetTypeAdapter(E);
    return await manager.boxExists(
      adapter.typeId.toString(),
      path ?? homePath,
      collection,
    );
  }

  // ignore: invalid_use_of_visible_for_testing_member
  ResolvedAdapter _checkAndGetTypeAdapter(Type type) {
    if (type == dynamic || type == Object) {
      throw HiveError('type E should not be dynamic or Object');
    }
    final adapter = findAdapterForType(type);
    if (adapter == null) {
      throw HiveError("adapter for type ${type.toString()} is not exists!");
    }
    return adapter;
  }

  @override
  Future<void> openTypeBox2<E1, E2>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) async {
    await Future.wait([
      _openTypeBox<E1>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E2>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      )
    ]);
  }

  @override
  Future<void> openTypeBox3<E1, E2, E3>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) async {
    await Future.wait([
      _openTypeBox<E1>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E2>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E3>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
    ]);
  }

  @override
  Future<void> openTypeBox4<E1, E2, E3, E4>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) async {
    await Future.wait([
      _openTypeBox<E1>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E2>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E3>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E4>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
    ]);
  }

  @override
  Future<void> openTypeBox5<E1, E2, E3, E4, E5>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) async {
    await Future.wait([
      _openTypeBox<E1>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E2>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E3>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E4>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E5>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
    ]);
  }

  @override
  Future<void> openTypeBox6<E1, E2, E3, E4, E5, E6>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) async {
    await Future.wait([
      _openTypeBox<E1>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E2>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E3>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E4>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E5>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E6>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
    ]);
  }

  @override
  Future<void> openTypeBox7<E1, E2, E3, E4, E5, E6, E7>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) async {
    await Future.wait([
      _openTypeBox<E1>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E2>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E3>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E4>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E5>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E6>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
      _openTypeBox<E7>(
        oldBox: oldBox,
        encryptionCipher: encryptionCipher,
        keyComparator: keyComparator,
        compactionStrategy: compactionStrategy,
      ),
    ]);
  }

  @override
  Future<void> openTypeBox8<E1, E2, E3, E4, E5, E6, E7, E8>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void> openTypeBox9<E1, E2, E3, E4, E5, E6, E7, E8, E9>(
          {Box? oldBox,
          HiveCipher? encryptionCipher,
          KeyComparator keyComparator = defaultKeyComparator,
          CompactionStrategy compactionStrategy = defaultCompactionStrategy,
          bool crashRecovery = true,
          String? path,
          StorageBackend? backend,
          String? collection}) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void> openTypeBox10<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E10>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void> openTypeBox11<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E10>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E11>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void>
      openTypeBox12<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11, E12>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
          Future.wait([
            _openTypeBox<E1>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E2>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E3>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E4>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E5>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E6>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E7>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E8>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E9>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E10>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E11>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E12>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
          ]);

  @override
  Future<void>
      openTypeBox13<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11, E12, E13>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
          Future.wait([
            _openTypeBox<E1>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E2>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E3>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E4>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E5>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E6>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E7>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E8>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E9>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E10>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E11>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E12>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
            _openTypeBox<E13>(
              oldBox: oldBox,
              encryptionCipher: encryptionCipher,
              keyComparator: keyComparator,
              compactionStrategy: compactionStrategy,
            ),
          ]);

  @override
  Future<void> openTypeBox14<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11, E12,
          E13, E14>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E10>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E11>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E12>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E13>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E14>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void> openTypeBox15<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11, E12,
          E13, E14, E15>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E10>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E11>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E12>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E13>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E14>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E15>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void> openTypeBox16<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11, E12,
          E13, E14, E15, E16>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E10>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E11>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E12>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E13>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E14>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E15>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E16>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void> openTypeBox17<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11, E12,
          E13, E14, E15, E16, E17>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E10>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E11>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E12>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E13>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E14>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E15>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E16>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E17>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void> openTypeBox18<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11, E12,
          E13, E14, E15, E16, E17, E18>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E10>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E11>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E12>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E13>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E14>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E15>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E16>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E17>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E18>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void> openTypeBox19<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11, E12,
          E13, E14, E15, E16, E17, E18, E19>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E10>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E11>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E12>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E13>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E14>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E15>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E16>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E17>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E18>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E19>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void> openTypeBox20<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11, E12,
          E13, E14, E15, E16, E17, E18, E19, E20>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E10>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E11>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E12>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E13>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E14>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E15>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E16>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E17>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E18>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E19>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E20>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void> openTypeBox21<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11, E12,
          E13, E14, E15, E16, E17, E18, E19, E20, E21>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E10>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E11>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E12>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E13>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E14>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E15>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E16>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E17>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E18>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E19>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E20>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E21>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);

  @override
  Future<void> openTypeBox22<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11, E12,
          E13, E14, E15, E16, E17, E18, E19, E20, E21, E22>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  }) =>
      Future.wait([
        _openTypeBox<E1>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E2>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E3>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E4>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E5>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E6>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E7>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E8>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E9>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E10>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E11>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E12>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E13>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E14>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E15>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E16>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E17>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E18>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E19>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E20>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E21>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
        _openTypeBox<E22>(
          oldBox: oldBox,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
        ),
      ]);
}

/// tiny helper for map key management...
class TupleBoxKey {
  final String box;
  final String? collection;

  TupleBoxKey(this.box, this.collection);

  @override
  String toString() => collection == null ? box : '$collection.$box';

  @override
  int get hashCode => collection == null
      ? box.hashCode
      : [box.hashCode, collection.hashCode].hashCode;

  @override
  bool operator ==(Object other) {
    return hashCode == other.hashCode;
  }
}
