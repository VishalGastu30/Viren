// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'holdings_dao.dart';

// ignore_for_file: type=lint
mixin _$HoldingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $HoldingsTable get holdings => attachedDatabase.holdings;
  $TradesTable get trades => attachedDatabase.trades;
  HoldingsDaoManager get managers => HoldingsDaoManager(this);
}

class HoldingsDaoManager {
  final _$HoldingsDaoMixin _db;
  HoldingsDaoManager(this._db);
  $$HoldingsTableTableManager get holdings =>
      $$HoldingsTableTableManager(_db.attachedDatabase, _db.holdings);
  $$TradesTableTableManager get trades =>
      $$TradesTableTableManager(_db.attachedDatabase, _db.trades);
}
