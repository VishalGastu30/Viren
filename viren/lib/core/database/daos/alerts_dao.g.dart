// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alerts_dao.dart';

// ignore_for_file: type=lint
mixin _$AlertsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AlertsTable get alerts => attachedDatabase.alerts;
  AlertsDaoManager get managers => AlertsDaoManager(this);
}

class AlertsDaoManager {
  final _$AlertsDaoMixin _db;
  AlertsDaoManager(this._db);
  $$AlertsTableTableManager get alerts =>
      $$AlertsTableTableManager(_db.attachedDatabase, _db.alerts);
}
