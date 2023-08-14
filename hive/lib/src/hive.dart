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
