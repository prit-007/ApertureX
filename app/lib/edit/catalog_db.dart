import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'catalog_db.g.dart';

/// SQLite table storing catalog metadata and serialized recipe JSON (#84).
@DataClassName('CatalogEntryRow')
class CatalogEntries extends Table {
  TextColumn get entryId => text()();
  TextColumn get sourceAssetId => text()();
  IntColumn get kind => integer()();
  TextColumn get label => text().nullable()();
  IntColumn get rating => integer().withDefault(const Constant(0))();
  BoolColumn get flag => boolean().withDefault(const Constant(false))();
  DateTimeColumn get created => dateTime()();
  TextColumn get recipeJson => text()();

  @override
  Set<Column> get primaryKey => {entryId};
}

/// SQLite table indexing explicit-save edit preview renders (#85).
@DataClassName('EditPreviewRow')
class EditPreviews extends Table {
  TextColumn get entryId => text()();
  TextColumn get path => text()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  TextColumn get recipeHash => text()();
  DateTimeColumn get created => dateTime()();

  @override
  Set<Column> get primaryKey => {entryId};
}

@DriftDatabase(tables: [CatalogEntries, EditPreviews])
class CatalogDb extends _$CatalogDb {
  CatalogDb([QueryExecutor? e]) : super(e ?? _openConnection()) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File('${dbFolder.path}/catalog.sqlite');
      return NativeDatabase.createInBackground(
        file,
        setup: (rawDb) {
          rawDb.execute('PRAGMA journal_mode = WAL;');
          rawDb.execute('PRAGMA synchronous = NORMAL;');
          rawDb.execute('PRAGMA foreign_keys = ON;');
          rawDb.execute('PRAGMA busy_timeout = 5000;');
        },
      );
    });
  }
}
