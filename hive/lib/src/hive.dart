part of hive;

/// The main API interface of Hive. Available through the `Hive` constant.
abstract class HiveInterface implements TypeRegistry {
  /// Initialize Hive by giving it a home directory.
  ///
  /// (Not necessary in the browser)
  ///
  /// The [useLocks] parameter can be used to turn off lockfiles for the
  /// database. Locks are used to prevent other processes from opening the
  /// database and in turn protect the database from corruption. If you turn
  /// this off, you need to externally synchronize accesses to the database.
  /// There is no performance benefit from disabling locks. The only benefit is
  /// that some platforms don't allow you to suspend while holding a lock for a
  /// file in a shared folder (i.e. on iOS, if you move the database to a
  /// shared container). If your app isn't crashing because it holds a lock
  /// during suspension and you don't know that you need this feature and don't
  /// understand the consequences, don't turn locking off.
  void init(
    String? path, {
    HiveStorageBackendPreference backendPreference =
        HiveStorageBackendPreference.native,
    bool useLocks = true,
  });

  /// Opens a box.
  ///
  /// If the box is already open, the instance is returned and all provided
  /// parameters are being ignored.
  @Deprecated('Use [openTypeBox] instead')
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
  });

  /// Opens a box only store type E.
  ///
  /// If oldBox is not null, migrate the data of type E in oldBox to the current
  /// box at the first initialization.
  ///
  /// If the box is already open, the instance is returned and all provided
  /// parameters are being ignored.
  Future<Box<E>> openTypeBox<E>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  });

  /// Opens two box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
  Future<void> openTypeBox2<E1, E2>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  });

  /// Opens three box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
  Future<void> openTypeBox3<E1, E2, E3>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  });

  /// Opens four box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
  Future<void> openTypeBox4<E1, E2, E3, E4>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  });

  /// Opens five box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
  Future<void> openTypeBox5<E1, E2, E3, E4, E5>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  });

  /// Opens six box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
  Future<void> openTypeBox6<E1, E2, E3, E4, E5, E6>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  });

  /// Opens seven box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
  Future<void> openTypeBox7<E1, E2, E3, E4, E5, E6, E7>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  });

  /// Opens eight box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
  Future<void> openTypeBox8<E1, E2, E3, E4, E5, E6, E7, E8>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  });

  /// Opens night box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
  Future<void> openTypeBox9<E1, E2, E3, E4, E5, E6, E7, E8, E9>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  });

  /// Opens 10 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
  Future<void> openTypeBox10<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  });

  /// Opens 11 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
  Future<void> openTypeBox11<E1, E2, E3, E4, E5, E6, E7, E8, E9, E10, E11>({
    Box? oldBox,
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    StorageBackend? backend,
    String? collection,
  });

  /// Opens 12 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
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
  });

  /// Opens 13 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
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
  });

  /// Opens 14 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
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
  });

  /// Opens 15 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
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
  });

  /// Opens 16 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
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
  });

  /// Opens 17 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
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
  });

  /// Opens 18 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
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
  });

  /// Opens 19 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
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
  });

  /// Opens 20 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
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
  });

  /// Opens 21 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
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
  });

  /// Opens 22 box store types.
  ///
  /// If oldBox is not null, migrate the data of types in oldBox to the match
  /// type box at the first initialization.
  ///
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
  });

  /// Opens a lazy box.
  ///
  /// If the box is already open, the instance is returned and all provided
  /// parameters are being ignored.
  @Deprecated('Use [openLazyTypeBox] instead')
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
  });

  /// Opens a lazy box only store type E.
  ///
  /// If the box is already open, the instance is returned and all provided
  /// parameters are being ignored.
  Future<LazyBox<E>> openLazyTypeBox<E>({
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
    StorageBackend? backend,
  });

  /// Returns a previously opened box.
  @Deprecated('Use [typeBox] instead')
  Box<E> box<E>(String name);

  /// Returns a previously opened type box.
  Box<E> typeBox<E>([String? collection]);

  /// Returns a previously opened lazy box.
  @Deprecated('Use [lazyTypeBox] instead')
  LazyBox<E> lazyBox<E>(String name);

  /// Returns a previously opened lazy type box.
  Box<E> lazyTypeBox<E>([String? collection]);

  /// Checks if a specific box is currently open.
  @Deprecated('Use [isTypeBoxOpen] instead')
  bool isBoxOpen(String name);

  /// Checks if a specific type box is currently open.
  bool isTypeBoxOpen<E>();

  /// Closes all open boxes.
  Future<void> close();

  /// Removes the file which contains the box and closes the box.
  ///
  /// In the browser, the IndexedDB database is being removed.
  @Deprecated('Use [deleteTypeBoxFromDisk] instead')
  Future<void> deleteBoxFromDisk(String name,
      {String? path, String? collection});

  /// Removes the file which contains the type box and closes the box.
  ///
  /// In the browser, the IndexedDB database is being removed.
  Future<void> deleteTypeBoxFromDisk<E>({String? path, String? collection});

  /// Deletes all currently open boxes from disk.
  ///
  /// The home directory will not be deleted.
  Future<void> deleteFromDisk();

  /// Generates a secure encryption key using the fortuna random algorithm.
  List<int> generateSecureKey();

  /// Checks if a box exists
  @Deprecated('Use [typeBoxExists] instead')
  Future<bool> boxExists(String name, {String? path});

  /// Checks if a type box exists
  Future<bool> typeBoxExists<E>({String? path});

  /// Clears all registered adapters.
  ///
  /// To register an adapter use [registerAdapter].
  ///
  /// NOTE: [resetAdapters] also clears the default adapters registered
  /// by Hive.
  ///
  /// WARNING: This method is only intended to be used for integration and
  /// unit tests and SHOULD not be used in production code.
  @visibleForTesting
  void resetAdapters();
}

///
typedef KeyComparator = int Function(dynamic key1, dynamic key2);

/// A function which decides when to compact a box.
typedef CompactionStrategy = bool Function(int entries, int deletedEntries);
