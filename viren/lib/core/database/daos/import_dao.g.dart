// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_dao.dart';

// ignore_for_file: type=lint
mixin _$ImportDaoMixin on DatabaseAccessor<AppDatabase> {
  $ImportsTable get imports => attachedDatabase.imports;
  ImportDaoManager get managers => ImportDaoManager(this);
}

class ImportDaoManager {
  final _$ImportDaoMixin _db;
  ImportDaoManager(this._db);
  $$ImportsTableTableManager get imports =>
      $$ImportsTableTableManager(_db.attachedDatabase, _db.imports);
}
