// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'behavior_dao.dart';

// ignore_for_file: type=lint
mixin _$BehaviorDaoMixin on DatabaseAccessor<AppDatabase> {
  $BehaviorMetricsTable get behaviorMetrics => attachedDatabase.behaviorMetrics;
  $ConfidenceMeterTable get confidenceMeter => attachedDatabase.confidenceMeter;
  BehaviorDaoManager get managers => BehaviorDaoManager(this);
}

class BehaviorDaoManager {
  final _$BehaviorDaoMixin _db;
  BehaviorDaoManager(this._db);
  $$BehaviorMetricsTableTableManager get behaviorMetrics =>
      $$BehaviorMetricsTableTableManager(
        _db.attachedDatabase,
        _db.behaviorMetrics,
      );
  $$ConfidenceMeterTableTableManager get confidenceMeter =>
      $$ConfidenceMeterTableTableManager(
        _db.attachedDatabase,
        _db.confidenceMeter,
      );
}
