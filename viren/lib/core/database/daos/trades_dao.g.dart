// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trades_dao.dart';

// ignore_for_file: type=lint
mixin _$TradesDaoMixin on DatabaseAccessor<AppDatabase> {
  $TradesTable get trades => attachedDatabase.trades;
  $TradeReasonsTable get tradeReasons => attachedDatabase.tradeReasons;
  TradesDaoManager get managers => TradesDaoManager(this);
}

class TradesDaoManager {
  final _$TradesDaoMixin _db;
  TradesDaoManager(this._db);
  $$TradesTableTableManager get trades =>
      $$TradesTableTableManager(_db.attachedDatabase, _db.trades);
  $$TradeReasonsTableTableManager get tradeReasons =>
      $$TradeReasonsTableTableManager(_db.attachedDatabase, _db.tradeReasons);
}
