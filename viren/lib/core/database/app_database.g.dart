// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TradesTable extends Trades with TableInfo<$TradesTable, Trade> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TradesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instrumentSymbolMeta = const VerificationMeta(
    'instrumentSymbol',
  );
  @override
  late final GeneratedColumn<String> instrumentSymbol = GeneratedColumn<String>(
    'instrument_symbol',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instrumentNameMeta = const VerificationMeta(
    'instrumentName',
  );
  @override
  late final GeneratedColumn<String> instrumentName = GeneratedColumn<String>(
    'instrument_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exchangeMeta = const VerificationMeta(
    'exchange',
  );
  @override
  late final GeneratedColumn<String> exchange = GeneratedColumn<String>(
    'exchange',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TradeType, int> tradeType =
      GeneratedColumn<int>(
        'trade_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<TradeType>($TradesTable.$convertertradeType);
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pricePerUnitMeta = const VerificationMeta(
    'pricePerUnit',
  );
  @override
  late final GeneratedColumn<double> pricePerUnit = GeneratedColumn<double>(
    'price_per_unit',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalValueMeta = const VerificationMeta(
    'totalValue',
  );
  @override
  late final GeneratedColumn<double> totalValue = GeneratedColumn<double>(
    'total_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tradeTimestampMeta = const VerificationMeta(
    'tradeTimestamp',
  );
  @override
  late final GeneratedColumn<DateTime> tradeTimestamp =
      GeneratedColumn<DateTime>(
        'trade_timestamp',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _brokerMeta = const VerificationMeta('broker');
  @override
  late final GeneratedColumn<String> broker = GeneratedColumn<String>(
    'broker',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Unknown'),
  );
  static const VerificationMeta _chargesMeta = const VerificationMeta(
    'charges',
  );
  @override
  late final GeneratedColumn<double> charges = GeneratedColumn<double>(
    'charges',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TradeSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<TradeSource>($TradesTable.$convertersource);
  static const VerificationMeta _sourceReferenceMeta = const VerificationMeta(
    'sourceReference',
  );
  @override
  late final GeneratedColumn<String> sourceReference = GeneratedColumn<String>(
    'source_reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importIdMeta = const VerificationMeta(
    'importId',
  );
  @override
  late final GeneratedColumn<String> importId = GeneratedColumn<String>(
    'import_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parseConfidenceMeta = const VerificationMeta(
    'parseConfidence',
  );
  @override
  late final GeneratedColumn<int> parseConfidence = GeneratedColumn<int>(
    'parse_confidence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _tamperHashMeta = const VerificationMeta(
    'tamperHash',
  );
  @override
  late final GeneratedColumn<String> tamperHash = GeneratedColumn<String>(
    'tamper_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    instrumentSymbol,
    instrumentName,
    exchange,
    tradeType,
    quantity,
    pricePerUnit,
    totalValue,
    tradeTimestamp,
    broker,
    charges,
    currency,
    source,
    sourceReference,
    importId,
    parseConfidence,
    createdAt,
    updatedAt,
    tamperHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trades';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trade> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('instrument_symbol')) {
      context.handle(
        _instrumentSymbolMeta,
        instrumentSymbol.isAcceptableOrUnknown(
          data['instrument_symbol']!,
          _instrumentSymbolMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instrumentSymbolMeta);
    }
    if (data.containsKey('instrument_name')) {
      context.handle(
        _instrumentNameMeta,
        instrumentName.isAcceptableOrUnknown(
          data['instrument_name']!,
          _instrumentNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instrumentNameMeta);
    }
    if (data.containsKey('exchange')) {
      context.handle(
        _exchangeMeta,
        exchange.isAcceptableOrUnknown(data['exchange']!, _exchangeMeta),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('price_per_unit')) {
      context.handle(
        _pricePerUnitMeta,
        pricePerUnit.isAcceptableOrUnknown(
          data['price_per_unit']!,
          _pricePerUnitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pricePerUnitMeta);
    }
    if (data.containsKey('total_value')) {
      context.handle(
        _totalValueMeta,
        totalValue.isAcceptableOrUnknown(data['total_value']!, _totalValueMeta),
      );
    } else if (isInserting) {
      context.missing(_totalValueMeta);
    }
    if (data.containsKey('trade_timestamp')) {
      context.handle(
        _tradeTimestampMeta,
        tradeTimestamp.isAcceptableOrUnknown(
          data['trade_timestamp']!,
          _tradeTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tradeTimestampMeta);
    }
    if (data.containsKey('broker')) {
      context.handle(
        _brokerMeta,
        broker.isAcceptableOrUnknown(data['broker']!, _brokerMeta),
      );
    }
    if (data.containsKey('charges')) {
      context.handle(
        _chargesMeta,
        charges.isAcceptableOrUnknown(data['charges']!, _chargesMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('source_reference')) {
      context.handle(
        _sourceReferenceMeta,
        sourceReference.isAcceptableOrUnknown(
          data['source_reference']!,
          _sourceReferenceMeta,
        ),
      );
    }
    if (data.containsKey('import_id')) {
      context.handle(
        _importIdMeta,
        importId.isAcceptableOrUnknown(data['import_id']!, _importIdMeta),
      );
    }
    if (data.containsKey('parse_confidence')) {
      context.handle(
        _parseConfidenceMeta,
        parseConfidence.isAcceptableOrUnknown(
          data['parse_confidence']!,
          _parseConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('tamper_hash')) {
      context.handle(
        _tamperHashMeta,
        tamperHash.isAcceptableOrUnknown(data['tamper_hash']!, _tamperHashMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trade map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trade(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      instrumentSymbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_symbol'],
      )!,
      instrumentName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_name'],
      )!,
      exchange: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange'],
      ),
      tradeType: $TradesTable.$convertertradeType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}trade_type'],
        )!,
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      pricePerUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price_per_unit'],
      )!,
      totalValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_value'],
      )!,
      tradeTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}trade_timestamp'],
      )!,
      broker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}broker'],
      )!,
      charges: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}charges'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      source: $TradesTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      sourceReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_reference'],
      ),
      importId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_id'],
      ),
      parseConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parse_confidence'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      tamperHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tamper_hash'],
      ),
    );
  }

  @override
  $TradesTable createAlias(String alias) {
    return $TradesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TradeType, int, int> $convertertradeType =
      const EnumIndexConverter<TradeType>(TradeType.values);
  static JsonTypeConverter2<TradeSource, int, int> $convertersource =
      const EnumIndexConverter<TradeSource>(TradeSource.values);
}

class Trade extends DataClass implements Insertable<Trade> {
  /// UUID primary key.
  final String id;

  /// Ticker / symbol (e.g. RELIANCE, TCS).
  final String instrumentSymbol;

  /// Human-readable name of the instrument.
  final String instrumentName;

  /// Exchange (e.g. NSE, BSE). Nullable — not always available.
  final String? exchange;

  /// Direction: BUY or SELL.
  final TradeType tradeType;

  /// Number of shares/units.
  final double quantity;

  /// Price per unit at execution time.
  final double pricePerUnit;

  /// Stored total (quantity × pricePerUnit). Derived but persisted to avoid
  /// floating point recomputation drift across schema versions.
  final double totalValue;

  /// UTC timestamp of trade execution.
  final DateTime tradeTimestamp;

  /// Broker name (e.g. Zerodha, Groww).
  final String broker;

  /// Brokerage + STT + other charges. Nullable when unknown.
  final double? charges;

  /// ISO 4217 currency code.
  final String currency;

  /// How the trade entered the system.
  final TradeSource source;

  /// Reference to the originating import (email message ID, file hash, etc.).
  final String? sourceReference;

  /// Reference to the originating import session.
  final String? importId;

  /// Parser confidence for auto-imported trades (0–100). 100 = manual entry.
  final int parseConfidence;

  /// Row creation time in UTC.
  final DateTime createdAt;

  /// Last update time in UTC.
  final DateTime updatedAt;

  /// Cryptographic hash for tamper detection (Rolling chain).
  /// sha256(row_data + prev_hash)
  final String? tamperHash;
  const Trade({
    required this.id,
    required this.instrumentSymbol,
    required this.instrumentName,
    this.exchange,
    required this.tradeType,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalValue,
    required this.tradeTimestamp,
    required this.broker,
    this.charges,
    required this.currency,
    required this.source,
    this.sourceReference,
    this.importId,
    required this.parseConfidence,
    required this.createdAt,
    required this.updatedAt,
    this.tamperHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['instrument_symbol'] = Variable<String>(instrumentSymbol);
    map['instrument_name'] = Variable<String>(instrumentName);
    if (!nullToAbsent || exchange != null) {
      map['exchange'] = Variable<String>(exchange);
    }
    {
      map['trade_type'] = Variable<int>(
        $TradesTable.$convertertradeType.toSql(tradeType),
      );
    }
    map['quantity'] = Variable<double>(quantity);
    map['price_per_unit'] = Variable<double>(pricePerUnit);
    map['total_value'] = Variable<double>(totalValue);
    map['trade_timestamp'] = Variable<DateTime>(tradeTimestamp);
    map['broker'] = Variable<String>(broker);
    if (!nullToAbsent || charges != null) {
      map['charges'] = Variable<double>(charges);
    }
    map['currency'] = Variable<String>(currency);
    {
      map['source'] = Variable<int>(
        $TradesTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || sourceReference != null) {
      map['source_reference'] = Variable<String>(sourceReference);
    }
    if (!nullToAbsent || importId != null) {
      map['import_id'] = Variable<String>(importId);
    }
    map['parse_confidence'] = Variable<int>(parseConfidence);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || tamperHash != null) {
      map['tamper_hash'] = Variable<String>(tamperHash);
    }
    return map;
  }

  TradesCompanion toCompanion(bool nullToAbsent) {
    return TradesCompanion(
      id: Value(id),
      instrumentSymbol: Value(instrumentSymbol),
      instrumentName: Value(instrumentName),
      exchange: exchange == null && nullToAbsent
          ? const Value.absent()
          : Value(exchange),
      tradeType: Value(tradeType),
      quantity: Value(quantity),
      pricePerUnit: Value(pricePerUnit),
      totalValue: Value(totalValue),
      tradeTimestamp: Value(tradeTimestamp),
      broker: Value(broker),
      charges: charges == null && nullToAbsent
          ? const Value.absent()
          : Value(charges),
      currency: Value(currency),
      source: Value(source),
      sourceReference: sourceReference == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceReference),
      importId: importId == null && nullToAbsent
          ? const Value.absent()
          : Value(importId),
      parseConfidence: Value(parseConfidence),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      tamperHash: tamperHash == null && nullToAbsent
          ? const Value.absent()
          : Value(tamperHash),
    );
  }

  factory Trade.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trade(
      id: serializer.fromJson<String>(json['id']),
      instrumentSymbol: serializer.fromJson<String>(json['instrumentSymbol']),
      instrumentName: serializer.fromJson<String>(json['instrumentName']),
      exchange: serializer.fromJson<String?>(json['exchange']),
      tradeType: $TradesTable.$convertertradeType.fromJson(
        serializer.fromJson<int>(json['tradeType']),
      ),
      quantity: serializer.fromJson<double>(json['quantity']),
      pricePerUnit: serializer.fromJson<double>(json['pricePerUnit']),
      totalValue: serializer.fromJson<double>(json['totalValue']),
      tradeTimestamp: serializer.fromJson<DateTime>(json['tradeTimestamp']),
      broker: serializer.fromJson<String>(json['broker']),
      charges: serializer.fromJson<double?>(json['charges']),
      currency: serializer.fromJson<String>(json['currency']),
      source: $TradesTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      sourceReference: serializer.fromJson<String?>(json['sourceReference']),
      importId: serializer.fromJson<String?>(json['importId']),
      parseConfidence: serializer.fromJson<int>(json['parseConfidence']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      tamperHash: serializer.fromJson<String?>(json['tamperHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'instrumentSymbol': serializer.toJson<String>(instrumentSymbol),
      'instrumentName': serializer.toJson<String>(instrumentName),
      'exchange': serializer.toJson<String?>(exchange),
      'tradeType': serializer.toJson<int>(
        $TradesTable.$convertertradeType.toJson(tradeType),
      ),
      'quantity': serializer.toJson<double>(quantity),
      'pricePerUnit': serializer.toJson<double>(pricePerUnit),
      'totalValue': serializer.toJson<double>(totalValue),
      'tradeTimestamp': serializer.toJson<DateTime>(tradeTimestamp),
      'broker': serializer.toJson<String>(broker),
      'charges': serializer.toJson<double?>(charges),
      'currency': serializer.toJson<String>(currency),
      'source': serializer.toJson<int>(
        $TradesTable.$convertersource.toJson(source),
      ),
      'sourceReference': serializer.toJson<String?>(sourceReference),
      'importId': serializer.toJson<String?>(importId),
      'parseConfidence': serializer.toJson<int>(parseConfidence),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'tamperHash': serializer.toJson<String?>(tamperHash),
    };
  }

  Trade copyWith({
    String? id,
    String? instrumentSymbol,
    String? instrumentName,
    Value<String?> exchange = const Value.absent(),
    TradeType? tradeType,
    double? quantity,
    double? pricePerUnit,
    double? totalValue,
    DateTime? tradeTimestamp,
    String? broker,
    Value<double?> charges = const Value.absent(),
    String? currency,
    TradeSource? source,
    Value<String?> sourceReference = const Value.absent(),
    Value<String?> importId = const Value.absent(),
    int? parseConfidence,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> tamperHash = const Value.absent(),
  }) => Trade(
    id: id ?? this.id,
    instrumentSymbol: instrumentSymbol ?? this.instrumentSymbol,
    instrumentName: instrumentName ?? this.instrumentName,
    exchange: exchange.present ? exchange.value : this.exchange,
    tradeType: tradeType ?? this.tradeType,
    quantity: quantity ?? this.quantity,
    pricePerUnit: pricePerUnit ?? this.pricePerUnit,
    totalValue: totalValue ?? this.totalValue,
    tradeTimestamp: tradeTimestamp ?? this.tradeTimestamp,
    broker: broker ?? this.broker,
    charges: charges.present ? charges.value : this.charges,
    currency: currency ?? this.currency,
    source: source ?? this.source,
    sourceReference: sourceReference.present
        ? sourceReference.value
        : this.sourceReference,
    importId: importId.present ? importId.value : this.importId,
    parseConfidence: parseConfidence ?? this.parseConfidence,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    tamperHash: tamperHash.present ? tamperHash.value : this.tamperHash,
  );
  Trade copyWithCompanion(TradesCompanion data) {
    return Trade(
      id: data.id.present ? data.id.value : this.id,
      instrumentSymbol: data.instrumentSymbol.present
          ? data.instrumentSymbol.value
          : this.instrumentSymbol,
      instrumentName: data.instrumentName.present
          ? data.instrumentName.value
          : this.instrumentName,
      exchange: data.exchange.present ? data.exchange.value : this.exchange,
      tradeType: data.tradeType.present ? data.tradeType.value : this.tradeType,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      pricePerUnit: data.pricePerUnit.present
          ? data.pricePerUnit.value
          : this.pricePerUnit,
      totalValue: data.totalValue.present
          ? data.totalValue.value
          : this.totalValue,
      tradeTimestamp: data.tradeTimestamp.present
          ? data.tradeTimestamp.value
          : this.tradeTimestamp,
      broker: data.broker.present ? data.broker.value : this.broker,
      charges: data.charges.present ? data.charges.value : this.charges,
      currency: data.currency.present ? data.currency.value : this.currency,
      source: data.source.present ? data.source.value : this.source,
      sourceReference: data.sourceReference.present
          ? data.sourceReference.value
          : this.sourceReference,
      importId: data.importId.present ? data.importId.value : this.importId,
      parseConfidence: data.parseConfidence.present
          ? data.parseConfidence.value
          : this.parseConfidence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      tamperHash: data.tamperHash.present
          ? data.tamperHash.value
          : this.tamperHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trade(')
          ..write('id: $id, ')
          ..write('instrumentSymbol: $instrumentSymbol, ')
          ..write('instrumentName: $instrumentName, ')
          ..write('exchange: $exchange, ')
          ..write('tradeType: $tradeType, ')
          ..write('quantity: $quantity, ')
          ..write('pricePerUnit: $pricePerUnit, ')
          ..write('totalValue: $totalValue, ')
          ..write('tradeTimestamp: $tradeTimestamp, ')
          ..write('broker: $broker, ')
          ..write('charges: $charges, ')
          ..write('currency: $currency, ')
          ..write('source: $source, ')
          ..write('sourceReference: $sourceReference, ')
          ..write('importId: $importId, ')
          ..write('parseConfidence: $parseConfidence, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('tamperHash: $tamperHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    instrumentSymbol,
    instrumentName,
    exchange,
    tradeType,
    quantity,
    pricePerUnit,
    totalValue,
    tradeTimestamp,
    broker,
    charges,
    currency,
    source,
    sourceReference,
    importId,
    parseConfidence,
    createdAt,
    updatedAt,
    tamperHash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trade &&
          other.id == this.id &&
          other.instrumentSymbol == this.instrumentSymbol &&
          other.instrumentName == this.instrumentName &&
          other.exchange == this.exchange &&
          other.tradeType == this.tradeType &&
          other.quantity == this.quantity &&
          other.pricePerUnit == this.pricePerUnit &&
          other.totalValue == this.totalValue &&
          other.tradeTimestamp == this.tradeTimestamp &&
          other.broker == this.broker &&
          other.charges == this.charges &&
          other.currency == this.currency &&
          other.source == this.source &&
          other.sourceReference == this.sourceReference &&
          other.importId == this.importId &&
          other.parseConfidence == this.parseConfidence &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.tamperHash == this.tamperHash);
}

class TradesCompanion extends UpdateCompanion<Trade> {
  final Value<String> id;
  final Value<String> instrumentSymbol;
  final Value<String> instrumentName;
  final Value<String?> exchange;
  final Value<TradeType> tradeType;
  final Value<double> quantity;
  final Value<double> pricePerUnit;
  final Value<double> totalValue;
  final Value<DateTime> tradeTimestamp;
  final Value<String> broker;
  final Value<double?> charges;
  final Value<String> currency;
  final Value<TradeSource> source;
  final Value<String?> sourceReference;
  final Value<String?> importId;
  final Value<int> parseConfidence;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> tamperHash;
  final Value<int> rowid;
  const TradesCompanion({
    this.id = const Value.absent(),
    this.instrumentSymbol = const Value.absent(),
    this.instrumentName = const Value.absent(),
    this.exchange = const Value.absent(),
    this.tradeType = const Value.absent(),
    this.quantity = const Value.absent(),
    this.pricePerUnit = const Value.absent(),
    this.totalValue = const Value.absent(),
    this.tradeTimestamp = const Value.absent(),
    this.broker = const Value.absent(),
    this.charges = const Value.absent(),
    this.currency = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceReference = const Value.absent(),
    this.importId = const Value.absent(),
    this.parseConfidence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.tamperHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TradesCompanion.insert({
    required String id,
    required String instrumentSymbol,
    required String instrumentName,
    this.exchange = const Value.absent(),
    required TradeType tradeType,
    required double quantity,
    required double pricePerUnit,
    required double totalValue,
    required DateTime tradeTimestamp,
    this.broker = const Value.absent(),
    this.charges = const Value.absent(),
    this.currency = const Value.absent(),
    required TradeSource source,
    this.sourceReference = const Value.absent(),
    this.importId = const Value.absent(),
    this.parseConfidence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.tamperHash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       instrumentSymbol = Value(instrumentSymbol),
       instrumentName = Value(instrumentName),
       tradeType = Value(tradeType),
       quantity = Value(quantity),
       pricePerUnit = Value(pricePerUnit),
       totalValue = Value(totalValue),
       tradeTimestamp = Value(tradeTimestamp),
       source = Value(source);
  static Insertable<Trade> custom({
    Expression<String>? id,
    Expression<String>? instrumentSymbol,
    Expression<String>? instrumentName,
    Expression<String>? exchange,
    Expression<int>? tradeType,
    Expression<double>? quantity,
    Expression<double>? pricePerUnit,
    Expression<double>? totalValue,
    Expression<DateTime>? tradeTimestamp,
    Expression<String>? broker,
    Expression<double>? charges,
    Expression<String>? currency,
    Expression<int>? source,
    Expression<String>? sourceReference,
    Expression<String>? importId,
    Expression<int>? parseConfidence,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? tamperHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (instrumentSymbol != null) 'instrument_symbol': instrumentSymbol,
      if (instrumentName != null) 'instrument_name': instrumentName,
      if (exchange != null) 'exchange': exchange,
      if (tradeType != null) 'trade_type': tradeType,
      if (quantity != null) 'quantity': quantity,
      if (pricePerUnit != null) 'price_per_unit': pricePerUnit,
      if (totalValue != null) 'total_value': totalValue,
      if (tradeTimestamp != null) 'trade_timestamp': tradeTimestamp,
      if (broker != null) 'broker': broker,
      if (charges != null) 'charges': charges,
      if (currency != null) 'currency': currency,
      if (source != null) 'source': source,
      if (sourceReference != null) 'source_reference': sourceReference,
      if (importId != null) 'import_id': importId,
      if (parseConfidence != null) 'parse_confidence': parseConfidence,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (tamperHash != null) 'tamper_hash': tamperHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TradesCompanion copyWith({
    Value<String>? id,
    Value<String>? instrumentSymbol,
    Value<String>? instrumentName,
    Value<String?>? exchange,
    Value<TradeType>? tradeType,
    Value<double>? quantity,
    Value<double>? pricePerUnit,
    Value<double>? totalValue,
    Value<DateTime>? tradeTimestamp,
    Value<String>? broker,
    Value<double?>? charges,
    Value<String>? currency,
    Value<TradeSource>? source,
    Value<String?>? sourceReference,
    Value<String?>? importId,
    Value<int>? parseConfidence,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? tamperHash,
    Value<int>? rowid,
  }) {
    return TradesCompanion(
      id: id ?? this.id,
      instrumentSymbol: instrumentSymbol ?? this.instrumentSymbol,
      instrumentName: instrumentName ?? this.instrumentName,
      exchange: exchange ?? this.exchange,
      tradeType: tradeType ?? this.tradeType,
      quantity: quantity ?? this.quantity,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      totalValue: totalValue ?? this.totalValue,
      tradeTimestamp: tradeTimestamp ?? this.tradeTimestamp,
      broker: broker ?? this.broker,
      charges: charges ?? this.charges,
      currency: currency ?? this.currency,
      source: source ?? this.source,
      sourceReference: sourceReference ?? this.sourceReference,
      importId: importId ?? this.importId,
      parseConfidence: parseConfidence ?? this.parseConfidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tamperHash: tamperHash ?? this.tamperHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (instrumentSymbol.present) {
      map['instrument_symbol'] = Variable<String>(instrumentSymbol.value);
    }
    if (instrumentName.present) {
      map['instrument_name'] = Variable<String>(instrumentName.value);
    }
    if (exchange.present) {
      map['exchange'] = Variable<String>(exchange.value);
    }
    if (tradeType.present) {
      map['trade_type'] = Variable<int>(
        $TradesTable.$convertertradeType.toSql(tradeType.value),
      );
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (pricePerUnit.present) {
      map['price_per_unit'] = Variable<double>(pricePerUnit.value);
    }
    if (totalValue.present) {
      map['total_value'] = Variable<double>(totalValue.value);
    }
    if (tradeTimestamp.present) {
      map['trade_timestamp'] = Variable<DateTime>(tradeTimestamp.value);
    }
    if (broker.present) {
      map['broker'] = Variable<String>(broker.value);
    }
    if (charges.present) {
      map['charges'] = Variable<double>(charges.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $TradesTable.$convertersource.toSql(source.value),
      );
    }
    if (sourceReference.present) {
      map['source_reference'] = Variable<String>(sourceReference.value);
    }
    if (importId.present) {
      map['import_id'] = Variable<String>(importId.value);
    }
    if (parseConfidence.present) {
      map['parse_confidence'] = Variable<int>(parseConfidence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (tamperHash.present) {
      map['tamper_hash'] = Variable<String>(tamperHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TradesCompanion(')
          ..write('id: $id, ')
          ..write('instrumentSymbol: $instrumentSymbol, ')
          ..write('instrumentName: $instrumentName, ')
          ..write('exchange: $exchange, ')
          ..write('tradeType: $tradeType, ')
          ..write('quantity: $quantity, ')
          ..write('pricePerUnit: $pricePerUnit, ')
          ..write('totalValue: $totalValue, ')
          ..write('tradeTimestamp: $tradeTimestamp, ')
          ..write('broker: $broker, ')
          ..write('charges: $charges, ')
          ..write('currency: $currency, ')
          ..write('source: $source, ')
          ..write('sourceReference: $sourceReference, ')
          ..write('importId: $importId, ')
          ..write('parseConfidence: $parseConfidence, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('tamperHash: $tamperHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TradeReasonsTable extends TradeReasons
    with TableInfo<$TradeReasonsTable, TradeReason> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TradeReasonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tradeIdMeta = const VerificationMeta(
    'tradeId',
  );
  @override
  late final GeneratedColumn<String> tradeId = GeneratedColumn<String>(
    'trade_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonTextEncryptedMeta =
      const VerificationMeta('reasonTextEncrypted');
  @override
  late final GeneratedColumn<String> reasonTextEncrypted =
      GeneratedColumn<String>(
        'reason_text_encrypted',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _emotionalStateEncryptedMeta =
      const VerificationMeta('emotionalStateEncrypted');
  @override
  late final GeneratedColumn<String> emotionalStateEncrypted =
      GeneratedColumn<String>(
        'emotional_state_encrypted',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _confidenceLevelMeta = const VerificationMeta(
    'confidenceLevel',
  );
  @override
  late final GeneratedColumn<int> confidenceLevel = GeneratedColumn<int>(
    'confidence_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _tamperHashMeta = const VerificationMeta(
    'tamperHash',
  );
  @override
  late final GeneratedColumn<String> tamperHash = GeneratedColumn<String>(
    'tamper_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tradeId,
    reasonTextEncrypted,
    tagsJson,
    emotionalStateEncrypted,
    confidenceLevel,
    createdAt,
    tamperHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trade_reasons';
  @override
  VerificationContext validateIntegrity(
    Insertable<TradeReason> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trade_id')) {
      context.handle(
        _tradeIdMeta,
        tradeId.isAcceptableOrUnknown(data['trade_id']!, _tradeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tradeIdMeta);
    }
    if (data.containsKey('reason_text_encrypted')) {
      context.handle(
        _reasonTextEncryptedMeta,
        reasonTextEncrypted.isAcceptableOrUnknown(
          data['reason_text_encrypted']!,
          _reasonTextEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('emotional_state_encrypted')) {
      context.handle(
        _emotionalStateEncryptedMeta,
        emotionalStateEncrypted.isAcceptableOrUnknown(
          data['emotional_state_encrypted']!,
          _emotionalStateEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('confidence_level')) {
      context.handle(
        _confidenceLevelMeta,
        confidenceLevel.isAcceptableOrUnknown(
          data['confidence_level']!,
          _confidenceLevelMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('tamper_hash')) {
      context.handle(
        _tamperHashMeta,
        tamperHash.isAcceptableOrUnknown(data['tamper_hash']!, _tamperHashMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TradeReason map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TradeReason(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tradeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trade_id'],
      )!,
      reasonTextEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_text_encrypted'],
      ),
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      emotionalStateEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emotional_state_encrypted'],
      ),
      confidenceLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confidence_level'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      tamperHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tamper_hash'],
      ),
    );
  }

  @override
  $TradeReasonsTable createAlias(String alias) {
    return $TradeReasonsTable(attachedDatabase, alias);
  }
}

class TradeReason extends DataClass implements Insertable<TradeReason> {
  /// UUID primary key.
  final String id;

  /// FK → trades.id (enforced at repository layer). Unique enforces 1:1.
  final String tradeId;

  /// Encrypted investment thesis / reason text.
  /// Format: base64(version_byte || iv[12] || ciphertext || tag[16])
  final String? reasonTextEncrypted;

  /// JSON array of conviction tags (e.g. ["Long-term", "Conviction"]).
  /// Stored as plain JSON — not sensitive.
  final String tagsJson;

  /// Encrypted emotional state enum index.
  /// Encrypted because emotional labels are considered sensitive.
  final String? emotionalStateEncrypted;

  /// Self-reported confidence in the decision at time of entry (0–100).
  final int? confidenceLevel;

  /// Row creation time in UTC.
  final DateTime createdAt;

  /// Cryptographic hash for tamper detection (Rolling chain).
  final String? tamperHash;
  const TradeReason({
    required this.id,
    required this.tradeId,
    this.reasonTextEncrypted,
    required this.tagsJson,
    this.emotionalStateEncrypted,
    this.confidenceLevel,
    required this.createdAt,
    this.tamperHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trade_id'] = Variable<String>(tradeId);
    if (!nullToAbsent || reasonTextEncrypted != null) {
      map['reason_text_encrypted'] = Variable<String>(reasonTextEncrypted);
    }
    map['tags_json'] = Variable<String>(tagsJson);
    if (!nullToAbsent || emotionalStateEncrypted != null) {
      map['emotional_state_encrypted'] = Variable<String>(
        emotionalStateEncrypted,
      );
    }
    if (!nullToAbsent || confidenceLevel != null) {
      map['confidence_level'] = Variable<int>(confidenceLevel);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || tamperHash != null) {
      map['tamper_hash'] = Variable<String>(tamperHash);
    }
    return map;
  }

  TradeReasonsCompanion toCompanion(bool nullToAbsent) {
    return TradeReasonsCompanion(
      id: Value(id),
      tradeId: Value(tradeId),
      reasonTextEncrypted: reasonTextEncrypted == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonTextEncrypted),
      tagsJson: Value(tagsJson),
      emotionalStateEncrypted: emotionalStateEncrypted == null && nullToAbsent
          ? const Value.absent()
          : Value(emotionalStateEncrypted),
      confidenceLevel: confidenceLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(confidenceLevel),
      createdAt: Value(createdAt),
      tamperHash: tamperHash == null && nullToAbsent
          ? const Value.absent()
          : Value(tamperHash),
    );
  }

  factory TradeReason.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TradeReason(
      id: serializer.fromJson<String>(json['id']),
      tradeId: serializer.fromJson<String>(json['tradeId']),
      reasonTextEncrypted: serializer.fromJson<String?>(
        json['reasonTextEncrypted'],
      ),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      emotionalStateEncrypted: serializer.fromJson<String?>(
        json['emotionalStateEncrypted'],
      ),
      confidenceLevel: serializer.fromJson<int?>(json['confidenceLevel']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      tamperHash: serializer.fromJson<String?>(json['tamperHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tradeId': serializer.toJson<String>(tradeId),
      'reasonTextEncrypted': serializer.toJson<String?>(reasonTextEncrypted),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'emotionalStateEncrypted': serializer.toJson<String?>(
        emotionalStateEncrypted,
      ),
      'confidenceLevel': serializer.toJson<int?>(confidenceLevel),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'tamperHash': serializer.toJson<String?>(tamperHash),
    };
  }

  TradeReason copyWith({
    String? id,
    String? tradeId,
    Value<String?> reasonTextEncrypted = const Value.absent(),
    String? tagsJson,
    Value<String?> emotionalStateEncrypted = const Value.absent(),
    Value<int?> confidenceLevel = const Value.absent(),
    DateTime? createdAt,
    Value<String?> tamperHash = const Value.absent(),
  }) => TradeReason(
    id: id ?? this.id,
    tradeId: tradeId ?? this.tradeId,
    reasonTextEncrypted: reasonTextEncrypted.present
        ? reasonTextEncrypted.value
        : this.reasonTextEncrypted,
    tagsJson: tagsJson ?? this.tagsJson,
    emotionalStateEncrypted: emotionalStateEncrypted.present
        ? emotionalStateEncrypted.value
        : this.emotionalStateEncrypted,
    confidenceLevel: confidenceLevel.present
        ? confidenceLevel.value
        : this.confidenceLevel,
    createdAt: createdAt ?? this.createdAt,
    tamperHash: tamperHash.present ? tamperHash.value : this.tamperHash,
  );
  TradeReason copyWithCompanion(TradeReasonsCompanion data) {
    return TradeReason(
      id: data.id.present ? data.id.value : this.id,
      tradeId: data.tradeId.present ? data.tradeId.value : this.tradeId,
      reasonTextEncrypted: data.reasonTextEncrypted.present
          ? data.reasonTextEncrypted.value
          : this.reasonTextEncrypted,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      emotionalStateEncrypted: data.emotionalStateEncrypted.present
          ? data.emotionalStateEncrypted.value
          : this.emotionalStateEncrypted,
      confidenceLevel: data.confidenceLevel.present
          ? data.confidenceLevel.value
          : this.confidenceLevel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      tamperHash: data.tamperHash.present
          ? data.tamperHash.value
          : this.tamperHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TradeReason(')
          ..write('id: $id, ')
          ..write('tradeId: $tradeId, ')
          ..write('reasonTextEncrypted: $reasonTextEncrypted, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('emotionalStateEncrypted: $emotionalStateEncrypted, ')
          ..write('confidenceLevel: $confidenceLevel, ')
          ..write('createdAt: $createdAt, ')
          ..write('tamperHash: $tamperHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tradeId,
    reasonTextEncrypted,
    tagsJson,
    emotionalStateEncrypted,
    confidenceLevel,
    createdAt,
    tamperHash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TradeReason &&
          other.id == this.id &&
          other.tradeId == this.tradeId &&
          other.reasonTextEncrypted == this.reasonTextEncrypted &&
          other.tagsJson == this.tagsJson &&
          other.emotionalStateEncrypted == this.emotionalStateEncrypted &&
          other.confidenceLevel == this.confidenceLevel &&
          other.createdAt == this.createdAt &&
          other.tamperHash == this.tamperHash);
}

class TradeReasonsCompanion extends UpdateCompanion<TradeReason> {
  final Value<String> id;
  final Value<String> tradeId;
  final Value<String?> reasonTextEncrypted;
  final Value<String> tagsJson;
  final Value<String?> emotionalStateEncrypted;
  final Value<int?> confidenceLevel;
  final Value<DateTime> createdAt;
  final Value<String?> tamperHash;
  final Value<int> rowid;
  const TradeReasonsCompanion({
    this.id = const Value.absent(),
    this.tradeId = const Value.absent(),
    this.reasonTextEncrypted = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.emotionalStateEncrypted = const Value.absent(),
    this.confidenceLevel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.tamperHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TradeReasonsCompanion.insert({
    required String id,
    required String tradeId,
    this.reasonTextEncrypted = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.emotionalStateEncrypted = const Value.absent(),
    this.confidenceLevel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.tamperHash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tradeId = Value(tradeId);
  static Insertable<TradeReason> custom({
    Expression<String>? id,
    Expression<String>? tradeId,
    Expression<String>? reasonTextEncrypted,
    Expression<String>? tagsJson,
    Expression<String>? emotionalStateEncrypted,
    Expression<int>? confidenceLevel,
    Expression<DateTime>? createdAt,
    Expression<String>? tamperHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tradeId != null) 'trade_id': tradeId,
      if (reasonTextEncrypted != null)
        'reason_text_encrypted': reasonTextEncrypted,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (emotionalStateEncrypted != null)
        'emotional_state_encrypted': emotionalStateEncrypted,
      if (confidenceLevel != null) 'confidence_level': confidenceLevel,
      if (createdAt != null) 'created_at': createdAt,
      if (tamperHash != null) 'tamper_hash': tamperHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TradeReasonsCompanion copyWith({
    Value<String>? id,
    Value<String>? tradeId,
    Value<String?>? reasonTextEncrypted,
    Value<String>? tagsJson,
    Value<String?>? emotionalStateEncrypted,
    Value<int?>? confidenceLevel,
    Value<DateTime>? createdAt,
    Value<String?>? tamperHash,
    Value<int>? rowid,
  }) {
    return TradeReasonsCompanion(
      id: id ?? this.id,
      tradeId: tradeId ?? this.tradeId,
      reasonTextEncrypted: reasonTextEncrypted ?? this.reasonTextEncrypted,
      tagsJson: tagsJson ?? this.tagsJson,
      emotionalStateEncrypted:
          emotionalStateEncrypted ?? this.emotionalStateEncrypted,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      createdAt: createdAt ?? this.createdAt,
      tamperHash: tamperHash ?? this.tamperHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tradeId.present) {
      map['trade_id'] = Variable<String>(tradeId.value);
    }
    if (reasonTextEncrypted.present) {
      map['reason_text_encrypted'] = Variable<String>(
        reasonTextEncrypted.value,
      );
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (emotionalStateEncrypted.present) {
      map['emotional_state_encrypted'] = Variable<String>(
        emotionalStateEncrypted.value,
      );
    }
    if (confidenceLevel.present) {
      map['confidence_level'] = Variable<int>(confidenceLevel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (tamperHash.present) {
      map['tamper_hash'] = Variable<String>(tamperHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TradeReasonsCompanion(')
          ..write('id: $id, ')
          ..write('tradeId: $tradeId, ')
          ..write('reasonTextEncrypted: $reasonTextEncrypted, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('emotionalStateEncrypted: $emotionalStateEncrypted, ')
          ..write('confidenceLevel: $confidenceLevel, ')
          ..write('createdAt: $createdAt, ')
          ..write('tamperHash: $tamperHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HoldingsTable extends Holdings with TableInfo<$HoldingsTable, Holding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoldingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _instrumentSymbolMeta = const VerificationMeta(
    'instrumentSymbol',
  );
  @override
  late final GeneratedColumn<String> instrumentSymbol = GeneratedColumn<String>(
    'instrument_symbol',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instrumentNameMeta = const VerificationMeta(
    'instrumentName',
  );
  @override
  late final GeneratedColumn<String> instrumentName = GeneratedColumn<String>(
    'instrument_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalQuantityMeta = const VerificationMeta(
    'totalQuantity',
  );
  @override
  late final GeneratedColumn<double> totalQuantity = GeneratedColumn<double>(
    'total_quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _averagePriceMeta = const VerificationMeta(
    'averagePrice',
  );
  @override
  late final GeneratedColumn<double> averagePrice = GeneratedColumn<double>(
    'average_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _investedValueMeta = const VerificationMeta(
    'investedValue',
  );
  @override
  late final GeneratedColumn<double> investedValue = GeneratedColumn<double>(
    'invested_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    instrumentSymbol,
    instrumentName,
    totalQuantity,
    averagePrice,
    investedValue,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holdings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Holding> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('instrument_symbol')) {
      context.handle(
        _instrumentSymbolMeta,
        instrumentSymbol.isAcceptableOrUnknown(
          data['instrument_symbol']!,
          _instrumentSymbolMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instrumentSymbolMeta);
    }
    if (data.containsKey('instrument_name')) {
      context.handle(
        _instrumentNameMeta,
        instrumentName.isAcceptableOrUnknown(
          data['instrument_name']!,
          _instrumentNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instrumentNameMeta);
    }
    if (data.containsKey('total_quantity')) {
      context.handle(
        _totalQuantityMeta,
        totalQuantity.isAcceptableOrUnknown(
          data['total_quantity']!,
          _totalQuantityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalQuantityMeta);
    }
    if (data.containsKey('average_price')) {
      context.handle(
        _averagePriceMeta,
        averagePrice.isAcceptableOrUnknown(
          data['average_price']!,
          _averagePriceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_averagePriceMeta);
    }
    if (data.containsKey('invested_value')) {
      context.handle(
        _investedValueMeta,
        investedValue.isAcceptableOrUnknown(
          data['invested_value']!,
          _investedValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_investedValueMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {instrumentSymbol};
  @override
  Holding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Holding(
      instrumentSymbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_symbol'],
      )!,
      instrumentName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_name'],
      )!,
      totalQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_quantity'],
      )!,
      averagePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}average_price'],
      )!,
      investedValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}invested_value'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  $HoldingsTable createAlias(String alias) {
    return $HoldingsTable(attachedDatabase, alias);
  }
}

class Holding extends DataClass implements Insertable<Holding> {
  /// Instrument symbol acts as the natural primary key for holdings.
  final String instrumentSymbol;

  /// Human-readable instrument name.
  final String instrumentName;

  /// Net quantity currently held (BUYs - SELLs).
  final double totalQuantity;

  /// Volume-weighted average purchase price.
  final double averagePrice;

  /// Total capital deployed (averagePrice × totalQuantity).
  final double investedValue;

  /// UTC timestamp of the last cache rebuild.
  final DateTime lastUpdated;
  const Holding({
    required this.instrumentSymbol,
    required this.instrumentName,
    required this.totalQuantity,
    required this.averagePrice,
    required this.investedValue,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['instrument_symbol'] = Variable<String>(instrumentSymbol);
    map['instrument_name'] = Variable<String>(instrumentName);
    map['total_quantity'] = Variable<double>(totalQuantity);
    map['average_price'] = Variable<double>(averagePrice);
    map['invested_value'] = Variable<double>(investedValue);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  HoldingsCompanion toCompanion(bool nullToAbsent) {
    return HoldingsCompanion(
      instrumentSymbol: Value(instrumentSymbol),
      instrumentName: Value(instrumentName),
      totalQuantity: Value(totalQuantity),
      averagePrice: Value(averagePrice),
      investedValue: Value(investedValue),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory Holding.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Holding(
      instrumentSymbol: serializer.fromJson<String>(json['instrumentSymbol']),
      instrumentName: serializer.fromJson<String>(json['instrumentName']),
      totalQuantity: serializer.fromJson<double>(json['totalQuantity']),
      averagePrice: serializer.fromJson<double>(json['averagePrice']),
      investedValue: serializer.fromJson<double>(json['investedValue']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'instrumentSymbol': serializer.toJson<String>(instrumentSymbol),
      'instrumentName': serializer.toJson<String>(instrumentName),
      'totalQuantity': serializer.toJson<double>(totalQuantity),
      'averagePrice': serializer.toJson<double>(averagePrice),
      'investedValue': serializer.toJson<double>(investedValue),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  Holding copyWith({
    String? instrumentSymbol,
    String? instrumentName,
    double? totalQuantity,
    double? averagePrice,
    double? investedValue,
    DateTime? lastUpdated,
  }) => Holding(
    instrumentSymbol: instrumentSymbol ?? this.instrumentSymbol,
    instrumentName: instrumentName ?? this.instrumentName,
    totalQuantity: totalQuantity ?? this.totalQuantity,
    averagePrice: averagePrice ?? this.averagePrice,
    investedValue: investedValue ?? this.investedValue,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  Holding copyWithCompanion(HoldingsCompanion data) {
    return Holding(
      instrumentSymbol: data.instrumentSymbol.present
          ? data.instrumentSymbol.value
          : this.instrumentSymbol,
      instrumentName: data.instrumentName.present
          ? data.instrumentName.value
          : this.instrumentName,
      totalQuantity: data.totalQuantity.present
          ? data.totalQuantity.value
          : this.totalQuantity,
      averagePrice: data.averagePrice.present
          ? data.averagePrice.value
          : this.averagePrice,
      investedValue: data.investedValue.present
          ? data.investedValue.value
          : this.investedValue,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Holding(')
          ..write('instrumentSymbol: $instrumentSymbol, ')
          ..write('instrumentName: $instrumentName, ')
          ..write('totalQuantity: $totalQuantity, ')
          ..write('averagePrice: $averagePrice, ')
          ..write('investedValue: $investedValue, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    instrumentSymbol,
    instrumentName,
    totalQuantity,
    averagePrice,
    investedValue,
    lastUpdated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Holding &&
          other.instrumentSymbol == this.instrumentSymbol &&
          other.instrumentName == this.instrumentName &&
          other.totalQuantity == this.totalQuantity &&
          other.averagePrice == this.averagePrice &&
          other.investedValue == this.investedValue &&
          other.lastUpdated == this.lastUpdated);
}

class HoldingsCompanion extends UpdateCompanion<Holding> {
  final Value<String> instrumentSymbol;
  final Value<String> instrumentName;
  final Value<double> totalQuantity;
  final Value<double> averagePrice;
  final Value<double> investedValue;
  final Value<DateTime> lastUpdated;
  final Value<int> rowid;
  const HoldingsCompanion({
    this.instrumentSymbol = const Value.absent(),
    this.instrumentName = const Value.absent(),
    this.totalQuantity = const Value.absent(),
    this.averagePrice = const Value.absent(),
    this.investedValue = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HoldingsCompanion.insert({
    required String instrumentSymbol,
    required String instrumentName,
    required double totalQuantity,
    required double averagePrice,
    required double investedValue,
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : instrumentSymbol = Value(instrumentSymbol),
       instrumentName = Value(instrumentName),
       totalQuantity = Value(totalQuantity),
       averagePrice = Value(averagePrice),
       investedValue = Value(investedValue);
  static Insertable<Holding> custom({
    Expression<String>? instrumentSymbol,
    Expression<String>? instrumentName,
    Expression<double>? totalQuantity,
    Expression<double>? averagePrice,
    Expression<double>? investedValue,
    Expression<DateTime>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (instrumentSymbol != null) 'instrument_symbol': instrumentSymbol,
      if (instrumentName != null) 'instrument_name': instrumentName,
      if (totalQuantity != null) 'total_quantity': totalQuantity,
      if (averagePrice != null) 'average_price': averagePrice,
      if (investedValue != null) 'invested_value': investedValue,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HoldingsCompanion copyWith({
    Value<String>? instrumentSymbol,
    Value<String>? instrumentName,
    Value<double>? totalQuantity,
    Value<double>? averagePrice,
    Value<double>? investedValue,
    Value<DateTime>? lastUpdated,
    Value<int>? rowid,
  }) {
    return HoldingsCompanion(
      instrumentSymbol: instrumentSymbol ?? this.instrumentSymbol,
      instrumentName: instrumentName ?? this.instrumentName,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      averagePrice: averagePrice ?? this.averagePrice,
      investedValue: investedValue ?? this.investedValue,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (instrumentSymbol.present) {
      map['instrument_symbol'] = Variable<String>(instrumentSymbol.value);
    }
    if (instrumentName.present) {
      map['instrument_name'] = Variable<String>(instrumentName.value);
    }
    if (totalQuantity.present) {
      map['total_quantity'] = Variable<double>(totalQuantity.value);
    }
    if (averagePrice.present) {
      map['average_price'] = Variable<double>(averagePrice.value);
    }
    if (investedValue.present) {
      map['invested_value'] = Variable<double>(investedValue.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoldingsCompanion(')
          ..write('instrumentSymbol: $instrumentSymbol, ')
          ..write('instrumentName: $instrumentName, ')
          ..write('totalQuantity: $totalQuantity, ')
          ..write('averagePrice: $averagePrice, ')
          ..write('investedValue: $investedValue, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PriceHistoryTable extends PriceHistory
    with TableInfo<$PriceHistoryTable, PriceHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PriceHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instrumentSymbolMeta = const VerificationMeta(
    'instrumentSymbol',
  );
  @override
  late final GeneratedColumn<String> instrumentSymbol = GeneratedColumn<String>(
    'instrument_symbol',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PriceSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<PriceSource>($PriceHistoryTable.$convertersource);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    instrumentSymbol,
    price,
    timestamp,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'price_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<PriceHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('instrument_symbol')) {
      context.handle(
        _instrumentSymbolMeta,
        instrumentSymbol.isAcceptableOrUnknown(
          data['instrument_symbol']!,
          _instrumentSymbolMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instrumentSymbolMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PriceHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PriceHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      instrumentSymbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instrument_symbol'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      source: $PriceHistoryTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
    );
  }

  @override
  $PriceHistoryTable createAlias(String alias) {
    return $PriceHistoryTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PriceSource, int, int> $convertersource =
      const EnumIndexConverter<PriceSource>(PriceSource.values);
}

class PriceHistoryData extends DataClass
    implements Insertable<PriceHistoryData> {
  /// UUID primary key.
  final String id;

  /// Ticker / symbol.
  final String instrumentSymbol;

  /// Price at this point in time.
  final double price;

  /// UTC timestamp of this price reading.
  final DateTime timestamp;

  /// Origin of this price data point.
  final PriceSource source;
  const PriceHistoryData({
    required this.id,
    required this.instrumentSymbol,
    required this.price,
    required this.timestamp,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['instrument_symbol'] = Variable<String>(instrumentSymbol);
    map['price'] = Variable<double>(price);
    map['timestamp'] = Variable<DateTime>(timestamp);
    {
      map['source'] = Variable<int>(
        $PriceHistoryTable.$convertersource.toSql(source),
      );
    }
    return map;
  }

  PriceHistoryCompanion toCompanion(bool nullToAbsent) {
    return PriceHistoryCompanion(
      id: Value(id),
      instrumentSymbol: Value(instrumentSymbol),
      price: Value(price),
      timestamp: Value(timestamp),
      source: Value(source),
    );
  }

  factory PriceHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PriceHistoryData(
      id: serializer.fromJson<String>(json['id']),
      instrumentSymbol: serializer.fromJson<String>(json['instrumentSymbol']),
      price: serializer.fromJson<double>(json['price']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      source: $PriceHistoryTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'instrumentSymbol': serializer.toJson<String>(instrumentSymbol),
      'price': serializer.toJson<double>(price),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'source': serializer.toJson<int>(
        $PriceHistoryTable.$convertersource.toJson(source),
      ),
    };
  }

  PriceHistoryData copyWith({
    String? id,
    String? instrumentSymbol,
    double? price,
    DateTime? timestamp,
    PriceSource? source,
  }) => PriceHistoryData(
    id: id ?? this.id,
    instrumentSymbol: instrumentSymbol ?? this.instrumentSymbol,
    price: price ?? this.price,
    timestamp: timestamp ?? this.timestamp,
    source: source ?? this.source,
  );
  PriceHistoryData copyWithCompanion(PriceHistoryCompanion data) {
    return PriceHistoryData(
      id: data.id.present ? data.id.value : this.id,
      instrumentSymbol: data.instrumentSymbol.present
          ? data.instrumentSymbol.value
          : this.instrumentSymbol,
      price: data.price.present ? data.price.value : this.price,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PriceHistoryData(')
          ..write('id: $id, ')
          ..write('instrumentSymbol: $instrumentSymbol, ')
          ..write('price: $price, ')
          ..write('timestamp: $timestamp, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, instrumentSymbol, price, timestamp, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceHistoryData &&
          other.id == this.id &&
          other.instrumentSymbol == this.instrumentSymbol &&
          other.price == this.price &&
          other.timestamp == this.timestamp &&
          other.source == this.source);
}

class PriceHistoryCompanion extends UpdateCompanion<PriceHistoryData> {
  final Value<String> id;
  final Value<String> instrumentSymbol;
  final Value<double> price;
  final Value<DateTime> timestamp;
  final Value<PriceSource> source;
  final Value<int> rowid;
  const PriceHistoryCompanion({
    this.id = const Value.absent(),
    this.instrumentSymbol = const Value.absent(),
    this.price = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PriceHistoryCompanion.insert({
    required String id,
    required String instrumentSymbol,
    required double price,
    required DateTime timestamp,
    required PriceSource source,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       instrumentSymbol = Value(instrumentSymbol),
       price = Value(price),
       timestamp = Value(timestamp),
       source = Value(source);
  static Insertable<PriceHistoryData> custom({
    Expression<String>? id,
    Expression<String>? instrumentSymbol,
    Expression<double>? price,
    Expression<DateTime>? timestamp,
    Expression<int>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (instrumentSymbol != null) 'instrument_symbol': instrumentSymbol,
      if (price != null) 'price': price,
      if (timestamp != null) 'timestamp': timestamp,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PriceHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? instrumentSymbol,
    Value<double>? price,
    Value<DateTime>? timestamp,
    Value<PriceSource>? source,
    Value<int>? rowid,
  }) {
    return PriceHistoryCompanion(
      id: id ?? this.id,
      instrumentSymbol: instrumentSymbol ?? this.instrumentSymbol,
      price: price ?? this.price,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (instrumentSymbol.present) {
      map['instrument_symbol'] = Variable<String>(instrumentSymbol.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $PriceHistoryTable.$convertersource.toSql(source.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PriceHistoryCompanion(')
          ..write('id: $id, ')
          ..write('instrumentSymbol: $instrumentSymbol, ')
          ..write('price: $price, ')
          ..write('timestamp: $timestamp, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PortfolioSnapshotsTable extends PortfolioSnapshots
    with TableInfo<$PortfolioSnapshotsTable, PortfolioSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortfolioSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snapshotDateMeta = const VerificationMeta(
    'snapshotDate',
  );
  @override
  late final GeneratedColumn<String> snapshotDate = GeneratedColumn<String>(
    'snapshot_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalInvestedMeta = const VerificationMeta(
    'totalInvested',
  );
  @override
  late final GeneratedColumn<double> totalInvested = GeneratedColumn<double>(
    'total_invested',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentValueMeta = const VerificationMeta(
    'currentValue',
  );
  @override
  late final GeneratedColumn<double> currentValue = GeneratedColumn<double>(
    'current_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unrealizedPnlMeta = const VerificationMeta(
    'unrealizedPnl',
  );
  @override
  late final GeneratedColumn<double> unrealizedPnl = GeneratedColumn<double>(
    'unrealized_pnl',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _realizedPnlMeta = const VerificationMeta(
    'realizedPnl',
  );
  @override
  late final GeneratedColumn<double> realizedPnl = GeneratedColumn<double>(
    'realized_pnl',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceScoreMeta = const VerificationMeta(
    'confidenceScore',
  );
  @override
  late final GeneratedColumn<double> confidenceScore = GeneratedColumn<double>(
    'confidence_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    snapshotDate,
    totalInvested,
    currentValue,
    unrealizedPnl,
    realizedPnl,
    confidenceScore,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'portfolio_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<PortfolioSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('snapshot_date')) {
      context.handle(
        _snapshotDateMeta,
        snapshotDate.isAcceptableOrUnknown(
          data['snapshot_date']!,
          _snapshotDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotDateMeta);
    }
    if (data.containsKey('total_invested')) {
      context.handle(
        _totalInvestedMeta,
        totalInvested.isAcceptableOrUnknown(
          data['total_invested']!,
          _totalInvestedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalInvestedMeta);
    }
    if (data.containsKey('current_value')) {
      context.handle(
        _currentValueMeta,
        currentValue.isAcceptableOrUnknown(
          data['current_value']!,
          _currentValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentValueMeta);
    }
    if (data.containsKey('unrealized_pnl')) {
      context.handle(
        _unrealizedPnlMeta,
        unrealizedPnl.isAcceptableOrUnknown(
          data['unrealized_pnl']!,
          _unrealizedPnlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unrealizedPnlMeta);
    }
    if (data.containsKey('realized_pnl')) {
      context.handle(
        _realizedPnlMeta,
        realizedPnl.isAcceptableOrUnknown(
          data['realized_pnl']!,
          _realizedPnlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_realizedPnlMeta);
    }
    if (data.containsKey('confidence_score')) {
      context.handle(
        _confidenceScoreMeta,
        confidenceScore.isAcceptableOrUnknown(
          data['confidence_score']!,
          _confidenceScoreMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PortfolioSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PortfolioSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      snapshotDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_date'],
      )!,
      totalInvested: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_invested'],
      )!,
      currentValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_value'],
      )!,
      unrealizedPnl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unrealized_pnl'],
      )!,
      realizedPnl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}realized_pnl'],
      )!,
      confidenceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence_score'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PortfolioSnapshotsTable createAlias(String alias) {
    return $PortfolioSnapshotsTable(attachedDatabase, alias);
  }
}

class PortfolioSnapshot extends DataClass
    implements Insertable<PortfolioSnapshot> {
  /// UUID primary key.
  final String id;

  /// The date this snapshot represents (stored as ISO-8601 date string).
  final String snapshotDate;

  /// Total capital deployed on this date.
  final double totalInvested;

  /// Estimated portfolio market value on this date.
  final double currentValue;

  /// Unrealized P&L (currentValue - totalInvested) at snapshot time.
  final double unrealizedPnl;

  /// Cumulative realized P&L from closed positions up to this date.
  final double realizedPnl;

  /// Confidence score at snapshot time (0.0–100.0).
  final double confidenceScore;

  /// UTC row creation time.
  final DateTime createdAt;
  const PortfolioSnapshot({
    required this.id,
    required this.snapshotDate,
    required this.totalInvested,
    required this.currentValue,
    required this.unrealizedPnl,
    required this.realizedPnl,
    required this.confidenceScore,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['snapshot_date'] = Variable<String>(snapshotDate);
    map['total_invested'] = Variable<double>(totalInvested);
    map['current_value'] = Variable<double>(currentValue);
    map['unrealized_pnl'] = Variable<double>(unrealizedPnl);
    map['realized_pnl'] = Variable<double>(realizedPnl);
    map['confidence_score'] = Variable<double>(confidenceScore);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PortfolioSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return PortfolioSnapshotsCompanion(
      id: Value(id),
      snapshotDate: Value(snapshotDate),
      totalInvested: Value(totalInvested),
      currentValue: Value(currentValue),
      unrealizedPnl: Value(unrealizedPnl),
      realizedPnl: Value(realizedPnl),
      confidenceScore: Value(confidenceScore),
      createdAt: Value(createdAt),
    );
  }

  factory PortfolioSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PortfolioSnapshot(
      id: serializer.fromJson<String>(json['id']),
      snapshotDate: serializer.fromJson<String>(json['snapshotDate']),
      totalInvested: serializer.fromJson<double>(json['totalInvested']),
      currentValue: serializer.fromJson<double>(json['currentValue']),
      unrealizedPnl: serializer.fromJson<double>(json['unrealizedPnl']),
      realizedPnl: serializer.fromJson<double>(json['realizedPnl']),
      confidenceScore: serializer.fromJson<double>(json['confidenceScore']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'snapshotDate': serializer.toJson<String>(snapshotDate),
      'totalInvested': serializer.toJson<double>(totalInvested),
      'currentValue': serializer.toJson<double>(currentValue),
      'unrealizedPnl': serializer.toJson<double>(unrealizedPnl),
      'realizedPnl': serializer.toJson<double>(realizedPnl),
      'confidenceScore': serializer.toJson<double>(confidenceScore),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PortfolioSnapshot copyWith({
    String? id,
    String? snapshotDate,
    double? totalInvested,
    double? currentValue,
    double? unrealizedPnl,
    double? realizedPnl,
    double? confidenceScore,
    DateTime? createdAt,
  }) => PortfolioSnapshot(
    id: id ?? this.id,
    snapshotDate: snapshotDate ?? this.snapshotDate,
    totalInvested: totalInvested ?? this.totalInvested,
    currentValue: currentValue ?? this.currentValue,
    unrealizedPnl: unrealizedPnl ?? this.unrealizedPnl,
    realizedPnl: realizedPnl ?? this.realizedPnl,
    confidenceScore: confidenceScore ?? this.confidenceScore,
    createdAt: createdAt ?? this.createdAt,
  );
  PortfolioSnapshot copyWithCompanion(PortfolioSnapshotsCompanion data) {
    return PortfolioSnapshot(
      id: data.id.present ? data.id.value : this.id,
      snapshotDate: data.snapshotDate.present
          ? data.snapshotDate.value
          : this.snapshotDate,
      totalInvested: data.totalInvested.present
          ? data.totalInvested.value
          : this.totalInvested,
      currentValue: data.currentValue.present
          ? data.currentValue.value
          : this.currentValue,
      unrealizedPnl: data.unrealizedPnl.present
          ? data.unrealizedPnl.value
          : this.unrealizedPnl,
      realizedPnl: data.realizedPnl.present
          ? data.realizedPnl.value
          : this.realizedPnl,
      confidenceScore: data.confidenceScore.present
          ? data.confidenceScore.value
          : this.confidenceScore,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioSnapshot(')
          ..write('id: $id, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('totalInvested: $totalInvested, ')
          ..write('currentValue: $currentValue, ')
          ..write('unrealizedPnl: $unrealizedPnl, ')
          ..write('realizedPnl: $realizedPnl, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    snapshotDate,
    totalInvested,
    currentValue,
    unrealizedPnl,
    realizedPnl,
    confidenceScore,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PortfolioSnapshot &&
          other.id == this.id &&
          other.snapshotDate == this.snapshotDate &&
          other.totalInvested == this.totalInvested &&
          other.currentValue == this.currentValue &&
          other.unrealizedPnl == this.unrealizedPnl &&
          other.realizedPnl == this.realizedPnl &&
          other.confidenceScore == this.confidenceScore &&
          other.createdAt == this.createdAt);
}

class PortfolioSnapshotsCompanion extends UpdateCompanion<PortfolioSnapshot> {
  final Value<String> id;
  final Value<String> snapshotDate;
  final Value<double> totalInvested;
  final Value<double> currentValue;
  final Value<double> unrealizedPnl;
  final Value<double> realizedPnl;
  final Value<double> confidenceScore;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PortfolioSnapshotsCompanion({
    this.id = const Value.absent(),
    this.snapshotDate = const Value.absent(),
    this.totalInvested = const Value.absent(),
    this.currentValue = const Value.absent(),
    this.unrealizedPnl = const Value.absent(),
    this.realizedPnl = const Value.absent(),
    this.confidenceScore = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PortfolioSnapshotsCompanion.insert({
    required String id,
    required String snapshotDate,
    required double totalInvested,
    required double currentValue,
    required double unrealizedPnl,
    required double realizedPnl,
    this.confidenceScore = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       snapshotDate = Value(snapshotDate),
       totalInvested = Value(totalInvested),
       currentValue = Value(currentValue),
       unrealizedPnl = Value(unrealizedPnl),
       realizedPnl = Value(realizedPnl);
  static Insertable<PortfolioSnapshot> custom({
    Expression<String>? id,
    Expression<String>? snapshotDate,
    Expression<double>? totalInvested,
    Expression<double>? currentValue,
    Expression<double>? unrealizedPnl,
    Expression<double>? realizedPnl,
    Expression<double>? confidenceScore,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (snapshotDate != null) 'snapshot_date': snapshotDate,
      if (totalInvested != null) 'total_invested': totalInvested,
      if (currentValue != null) 'current_value': currentValue,
      if (unrealizedPnl != null) 'unrealized_pnl': unrealizedPnl,
      if (realizedPnl != null) 'realized_pnl': realizedPnl,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PortfolioSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? snapshotDate,
    Value<double>? totalInvested,
    Value<double>? currentValue,
    Value<double>? unrealizedPnl,
    Value<double>? realizedPnl,
    Value<double>? confidenceScore,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PortfolioSnapshotsCompanion(
      id: id ?? this.id,
      snapshotDate: snapshotDate ?? this.snapshotDate,
      totalInvested: totalInvested ?? this.totalInvested,
      currentValue: currentValue ?? this.currentValue,
      unrealizedPnl: unrealizedPnl ?? this.unrealizedPnl,
      realizedPnl: realizedPnl ?? this.realizedPnl,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (snapshotDate.present) {
      map['snapshot_date'] = Variable<String>(snapshotDate.value);
    }
    if (totalInvested.present) {
      map['total_invested'] = Variable<double>(totalInvested.value);
    }
    if (currentValue.present) {
      map['current_value'] = Variable<double>(currentValue.value);
    }
    if (unrealizedPnl.present) {
      map['unrealized_pnl'] = Variable<double>(unrealizedPnl.value);
    }
    if (realizedPnl.present) {
      map['realized_pnl'] = Variable<double>(realizedPnl.value);
    }
    if (confidenceScore.present) {
      map['confidence_score'] = Variable<double>(confidenceScore.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('totalInvested: $totalInvested, ')
          ..write('currentValue: $currentValue, ')
          ..write('unrealizedPnl: $unrealizedPnl, ')
          ..write('realizedPnl: $realizedPnl, ')
          ..write('confidenceScore: $confidenceScore, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlertsTable extends Alerts with TableInfo<$AlertsTable, Alert> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlertsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alertTypeMeta = const VerificationMeta(
    'alertType',
  );
  @override
  late final GeneratedColumn<String> alertType = GeneratedColumn<String>(
    'alert_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AlertSeverity, int> severity =
      GeneratedColumn<int>(
        'severity',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<AlertSeverity>($AlertsTable.$converterseverity);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<int> confidence = GeneratedColumn<int>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _relatedInstrumentMeta = const VerificationMeta(
    'relatedInstrument',
  );
  @override
  late final GeneratedColumn<String> relatedInstrument =
      GeneratedColumn<String>(
        'related_instrument',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _triggerDataMeta = const VerificationMeta(
    'triggerData',
  );
  @override
  late final GeneratedColumn<String> triggerData = GeneratedColumn<String>(
    'trigger_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _dismissedAtMeta = const VerificationMeta(
    'dismissedAt',
  );
  @override
  late final GeneratedColumn<DateTime> dismissedAt = GeneratedColumn<DateTime>(
    'dismissed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> snoozedUntil = GeneratedColumn<DateTime>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importIdMeta = const VerificationMeta(
    'importId',
  );
  @override
  late final GeneratedColumn<String> importId = GeneratedColumn<String>(
    'import_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tamperHashMeta = const VerificationMeta(
    'tamperHash',
  );
  @override
  late final GeneratedColumn<String> tamperHash = GeneratedColumn<String>(
    'tamper_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    alertType,
    severity,
    title,
    description,
    confidence,
    relatedInstrument,
    triggerData,
    createdAt,
    dismissedAt,
    snoozedUntil,
    importId,
    tamperHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alerts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Alert> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('alert_type')) {
      context.handle(
        _alertTypeMeta,
        alertType.isAcceptableOrUnknown(data['alert_type']!, _alertTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_alertTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('related_instrument')) {
      context.handle(
        _relatedInstrumentMeta,
        relatedInstrument.isAcceptableOrUnknown(
          data['related_instrument']!,
          _relatedInstrumentMeta,
        ),
      );
    }
    if (data.containsKey('trigger_data')) {
      context.handle(
        _triggerDataMeta,
        triggerData.isAcceptableOrUnknown(
          data['trigger_data']!,
          _triggerDataMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('dismissed_at')) {
      context.handle(
        _dismissedAtMeta,
        dismissedAt.isAcceptableOrUnknown(
          data['dismissed_at']!,
          _dismissedAtMeta,
        ),
      );
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('import_id')) {
      context.handle(
        _importIdMeta,
        importId.isAcceptableOrUnknown(data['import_id']!, _importIdMeta),
      );
    }
    if (data.containsKey('tamper_hash')) {
      context.handle(
        _tamperHashMeta,
        tamperHash.isAcceptableOrUnknown(data['tamper_hash']!, _tamperHashMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Alert map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Alert(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      alertType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alert_type'],
      )!,
      severity: $AlertsTable.$converterseverity.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}severity'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confidence'],
      )!,
      relatedInstrument: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_instrument'],
      ),
      triggerData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_data'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      dismissedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dismissed_at'],
      ),
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snoozed_until'],
      ),
      importId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_id'],
      ),
      tamperHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tamper_hash'],
      ),
    );
  }

  @override
  $AlertsTable createAlias(String alias) {
    return $AlertsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AlertSeverity, int, int> $converterseverity =
      const EnumIndexConverter<AlertSeverity>(AlertSeverity.values);
}

class Alert extends DataClass implements Insertable<Alert> {
  /// UUID primary key.
  final String id;

  /// Machine-readable alert type tag (e.g. "SUPPORT_BREAK", "52_WEEK_HIGH").
  final String alertType;

  /// Severity level.
  final AlertSeverity severity;

  /// Short headline shown to the user.
  final String title;

  /// Full explanatory description.
  final String description;

  /// Confidence score (0–100) for this alert's trigger.
  final int confidence;

  /// Symbol this alert relates to. Nullable for portfolio-wide alerts.
  final String? relatedInstrument;

  /// JSON object representing the raw data that triggered this alert.
  /// Stored for explainability — the app can always re-derive why.
  final String triggerData;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// Non-null when the user explicitly dismissed this alert.
  final DateTime? dismissedAt;

  /// Non-null when the user has snoozed this alert until a future time.
  final DateTime? snoozedUntil;

  /// Reference to the import session that triggered this alert.
  final String? importId;

  /// Cryptographic hash for tamper detection (Rolling chain).
  final String? tamperHash;
  const Alert({
    required this.id,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.description,
    required this.confidence,
    this.relatedInstrument,
    required this.triggerData,
    required this.createdAt,
    this.dismissedAt,
    this.snoozedUntil,
    this.importId,
    this.tamperHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['alert_type'] = Variable<String>(alertType);
    {
      map['severity'] = Variable<int>(
        $AlertsTable.$converterseverity.toSql(severity),
      );
    }
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['confidence'] = Variable<int>(confidence);
    if (!nullToAbsent || relatedInstrument != null) {
      map['related_instrument'] = Variable<String>(relatedInstrument);
    }
    map['trigger_data'] = Variable<String>(triggerData);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || dismissedAt != null) {
      map['dismissed_at'] = Variable<DateTime>(dismissedAt);
    }
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil);
    }
    if (!nullToAbsent || importId != null) {
      map['import_id'] = Variable<String>(importId);
    }
    if (!nullToAbsent || tamperHash != null) {
      map['tamper_hash'] = Variable<String>(tamperHash);
    }
    return map;
  }

  AlertsCompanion toCompanion(bool nullToAbsent) {
    return AlertsCompanion(
      id: Value(id),
      alertType: Value(alertType),
      severity: Value(severity),
      title: Value(title),
      description: Value(description),
      confidence: Value(confidence),
      relatedInstrument: relatedInstrument == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedInstrument),
      triggerData: Value(triggerData),
      createdAt: Value(createdAt),
      dismissedAt: dismissedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dismissedAt),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      importId: importId == null && nullToAbsent
          ? const Value.absent()
          : Value(importId),
      tamperHash: tamperHash == null && nullToAbsent
          ? const Value.absent()
          : Value(tamperHash),
    );
  }

  factory Alert.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Alert(
      id: serializer.fromJson<String>(json['id']),
      alertType: serializer.fromJson<String>(json['alertType']),
      severity: $AlertsTable.$converterseverity.fromJson(
        serializer.fromJson<int>(json['severity']),
      ),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      confidence: serializer.fromJson<int>(json['confidence']),
      relatedInstrument: serializer.fromJson<String?>(
        json['relatedInstrument'],
      ),
      triggerData: serializer.fromJson<String>(json['triggerData']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      dismissedAt: serializer.fromJson<DateTime?>(json['dismissedAt']),
      snoozedUntil: serializer.fromJson<DateTime?>(json['snoozedUntil']),
      importId: serializer.fromJson<String?>(json['importId']),
      tamperHash: serializer.fromJson<String?>(json['tamperHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'alertType': serializer.toJson<String>(alertType),
      'severity': serializer.toJson<int>(
        $AlertsTable.$converterseverity.toJson(severity),
      ),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'confidence': serializer.toJson<int>(confidence),
      'relatedInstrument': serializer.toJson<String?>(relatedInstrument),
      'triggerData': serializer.toJson<String>(triggerData),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'dismissedAt': serializer.toJson<DateTime?>(dismissedAt),
      'snoozedUntil': serializer.toJson<DateTime?>(snoozedUntil),
      'importId': serializer.toJson<String?>(importId),
      'tamperHash': serializer.toJson<String?>(tamperHash),
    };
  }

  Alert copyWith({
    String? id,
    String? alertType,
    AlertSeverity? severity,
    String? title,
    String? description,
    int? confidence,
    Value<String?> relatedInstrument = const Value.absent(),
    String? triggerData,
    DateTime? createdAt,
    Value<DateTime?> dismissedAt = const Value.absent(),
    Value<DateTime?> snoozedUntil = const Value.absent(),
    Value<String?> importId = const Value.absent(),
    Value<String?> tamperHash = const Value.absent(),
  }) => Alert(
    id: id ?? this.id,
    alertType: alertType ?? this.alertType,
    severity: severity ?? this.severity,
    title: title ?? this.title,
    description: description ?? this.description,
    confidence: confidence ?? this.confidence,
    relatedInstrument: relatedInstrument.present
        ? relatedInstrument.value
        : this.relatedInstrument,
    triggerData: triggerData ?? this.triggerData,
    createdAt: createdAt ?? this.createdAt,
    dismissedAt: dismissedAt.present ? dismissedAt.value : this.dismissedAt,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    importId: importId.present ? importId.value : this.importId,
    tamperHash: tamperHash.present ? tamperHash.value : this.tamperHash,
  );
  Alert copyWithCompanion(AlertsCompanion data) {
    return Alert(
      id: data.id.present ? data.id.value : this.id,
      alertType: data.alertType.present ? data.alertType.value : this.alertType,
      severity: data.severity.present ? data.severity.value : this.severity,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      relatedInstrument: data.relatedInstrument.present
          ? data.relatedInstrument.value
          : this.relatedInstrument,
      triggerData: data.triggerData.present
          ? data.triggerData.value
          : this.triggerData,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      dismissedAt: data.dismissedAt.present
          ? data.dismissedAt.value
          : this.dismissedAt,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      importId: data.importId.present ? data.importId.value : this.importId,
      tamperHash: data.tamperHash.present
          ? data.tamperHash.value
          : this.tamperHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Alert(')
          ..write('id: $id, ')
          ..write('alertType: $alertType, ')
          ..write('severity: $severity, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('confidence: $confidence, ')
          ..write('relatedInstrument: $relatedInstrument, ')
          ..write('triggerData: $triggerData, ')
          ..write('createdAt: $createdAt, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('importId: $importId, ')
          ..write('tamperHash: $tamperHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    alertType,
    severity,
    title,
    description,
    confidence,
    relatedInstrument,
    triggerData,
    createdAt,
    dismissedAt,
    snoozedUntil,
    importId,
    tamperHash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Alert &&
          other.id == this.id &&
          other.alertType == this.alertType &&
          other.severity == this.severity &&
          other.title == this.title &&
          other.description == this.description &&
          other.confidence == this.confidence &&
          other.relatedInstrument == this.relatedInstrument &&
          other.triggerData == this.triggerData &&
          other.createdAt == this.createdAt &&
          other.dismissedAt == this.dismissedAt &&
          other.snoozedUntil == this.snoozedUntil &&
          other.importId == this.importId &&
          other.tamperHash == this.tamperHash);
}

class AlertsCompanion extends UpdateCompanion<Alert> {
  final Value<String> id;
  final Value<String> alertType;
  final Value<AlertSeverity> severity;
  final Value<String> title;
  final Value<String> description;
  final Value<int> confidence;
  final Value<String?> relatedInstrument;
  final Value<String> triggerData;
  final Value<DateTime> createdAt;
  final Value<DateTime?> dismissedAt;
  final Value<DateTime?> snoozedUntil;
  final Value<String?> importId;
  final Value<String?> tamperHash;
  final Value<int> rowid;
  const AlertsCompanion({
    this.id = const Value.absent(),
    this.alertType = const Value.absent(),
    this.severity = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.confidence = const Value.absent(),
    this.relatedInstrument = const Value.absent(),
    this.triggerData = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.importId = const Value.absent(),
    this.tamperHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlertsCompanion.insert({
    required String id,
    required String alertType,
    required AlertSeverity severity,
    required String title,
    required String description,
    this.confidence = const Value.absent(),
    this.relatedInstrument = const Value.absent(),
    this.triggerData = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.importId = const Value.absent(),
    this.tamperHash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       alertType = Value(alertType),
       severity = Value(severity),
       title = Value(title),
       description = Value(description);
  static Insertable<Alert> custom({
    Expression<String>? id,
    Expression<String>? alertType,
    Expression<int>? severity,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? confidence,
    Expression<String>? relatedInstrument,
    Expression<String>? triggerData,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? dismissedAt,
    Expression<DateTime>? snoozedUntil,
    Expression<String>? importId,
    Expression<String>? tamperHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (alertType != null) 'alert_type': alertType,
      if (severity != null) 'severity': severity,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (confidence != null) 'confidence': confidence,
      if (relatedInstrument != null) 'related_instrument': relatedInstrument,
      if (triggerData != null) 'trigger_data': triggerData,
      if (createdAt != null) 'created_at': createdAt,
      if (dismissedAt != null) 'dismissed_at': dismissedAt,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (importId != null) 'import_id': importId,
      if (tamperHash != null) 'tamper_hash': tamperHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlertsCompanion copyWith({
    Value<String>? id,
    Value<String>? alertType,
    Value<AlertSeverity>? severity,
    Value<String>? title,
    Value<String>? description,
    Value<int>? confidence,
    Value<String?>? relatedInstrument,
    Value<String>? triggerData,
    Value<DateTime>? createdAt,
    Value<DateTime?>? dismissedAt,
    Value<DateTime?>? snoozedUntil,
    Value<String?>? importId,
    Value<String?>? tamperHash,
    Value<int>? rowid,
  }) {
    return AlertsCompanion(
      id: id ?? this.id,
      alertType: alertType ?? this.alertType,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      confidence: confidence ?? this.confidence,
      relatedInstrument: relatedInstrument ?? this.relatedInstrument,
      triggerData: triggerData ?? this.triggerData,
      createdAt: createdAt ?? this.createdAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      importId: importId ?? this.importId,
      tamperHash: tamperHash ?? this.tamperHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (alertType.present) {
      map['alert_type'] = Variable<String>(alertType.value);
    }
    if (severity.present) {
      map['severity'] = Variable<int>(
        $AlertsTable.$converterseverity.toSql(severity.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<int>(confidence.value);
    }
    if (relatedInstrument.present) {
      map['related_instrument'] = Variable<String>(relatedInstrument.value);
    }
    if (triggerData.present) {
      map['trigger_data'] = Variable<String>(triggerData.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (dismissedAt.present) {
      map['dismissed_at'] = Variable<DateTime>(dismissedAt.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil.value);
    }
    if (importId.present) {
      map['import_id'] = Variable<String>(importId.value);
    }
    if (tamperHash.present) {
      map['tamper_hash'] = Variable<String>(tamperHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlertsCompanion(')
          ..write('id: $id, ')
          ..write('alertType: $alertType, ')
          ..write('severity: $severity, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('confidence: $confidence, ')
          ..write('relatedInstrument: $relatedInstrument, ')
          ..write('triggerData: $triggerData, ')
          ..write('createdAt: $createdAt, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('importId: $importId, ')
          ..write('tamperHash: $tamperHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BehaviorMetricsTable extends BehaviorMetrics
    with TableInfo<$BehaviorMetricsTable, BehaviorMetric> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BehaviorMetricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BehaviorMetricType, int>
  metricType =
      GeneratedColumn<int>(
        'metric_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<BehaviorMetricType>(
        $BehaviorMetricsTable.$convertermetricType,
      );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeWindowStartMeta = const VerificationMeta(
    'timeWindowStart',
  );
  @override
  late final GeneratedColumn<String> timeWindowStart = GeneratedColumn<String>(
    'time_window_start',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeWindowEndMeta = const VerificationMeta(
    'timeWindowEnd',
  );
  @override
  late final GeneratedColumn<String> timeWindowEnd = GeneratedColumn<String>(
    'time_window_end',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<int> confidence = GeneratedColumn<int>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    metricType,
    value,
    timeWindowStart,
    timeWindowEnd,
    confidence,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'behavior_metrics';
  @override
  VerificationContext validateIntegrity(
    Insertable<BehaviorMetric> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('time_window_start')) {
      context.handle(
        _timeWindowStartMeta,
        timeWindowStart.isAcceptableOrUnknown(
          data['time_window_start']!,
          _timeWindowStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timeWindowStartMeta);
    }
    if (data.containsKey('time_window_end')) {
      context.handle(
        _timeWindowEndMeta,
        timeWindowEnd.isAcceptableOrUnknown(
          data['time_window_end']!,
          _timeWindowEndMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timeWindowEndMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BehaviorMetric map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BehaviorMetric(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      metricType: $BehaviorMetricsTable.$convertermetricType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}metric_type'],
        )!,
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      timeWindowStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_window_start'],
      )!,
      timeWindowEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_window_end'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confidence'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BehaviorMetricsTable createAlias(String alias) {
    return $BehaviorMetricsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BehaviorMetricType, int, int> $convertermetricType =
      const EnumIndexConverter<BehaviorMetricType>(BehaviorMetricType.values);
}

class BehaviorMetric extends DataClass implements Insertable<BehaviorMetric> {
  /// UUID primary key.
  final String id;

  /// The class of behavioral signal detected.
  final BehaviorMetricType metricType;

  /// Numeric value of this metric (interpretation depends on metricType).
  final double value;

  /// Start of the analysis window (ISO-8601 date string, e.g. "2024-01-01").
  final String timeWindowStart;

  /// End of the analysis window (ISO-8601 date string, e.g. "2024-01-31").
  final String timeWindowEnd;

  /// Detection confidence (0–100).
  final int confidence;

  /// UTC row creation time.
  final DateTime createdAt;
  const BehaviorMetric({
    required this.id,
    required this.metricType,
    required this.value,
    required this.timeWindowStart,
    required this.timeWindowEnd,
    required this.confidence,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['metric_type'] = Variable<int>(
        $BehaviorMetricsTable.$convertermetricType.toSql(metricType),
      );
    }
    map['value'] = Variable<double>(value);
    map['time_window_start'] = Variable<String>(timeWindowStart);
    map['time_window_end'] = Variable<String>(timeWindowEnd);
    map['confidence'] = Variable<int>(confidence);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BehaviorMetricsCompanion toCompanion(bool nullToAbsent) {
    return BehaviorMetricsCompanion(
      id: Value(id),
      metricType: Value(metricType),
      value: Value(value),
      timeWindowStart: Value(timeWindowStart),
      timeWindowEnd: Value(timeWindowEnd),
      confidence: Value(confidence),
      createdAt: Value(createdAt),
    );
  }

  factory BehaviorMetric.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BehaviorMetric(
      id: serializer.fromJson<String>(json['id']),
      metricType: $BehaviorMetricsTable.$convertermetricType.fromJson(
        serializer.fromJson<int>(json['metricType']),
      ),
      value: serializer.fromJson<double>(json['value']),
      timeWindowStart: serializer.fromJson<String>(json['timeWindowStart']),
      timeWindowEnd: serializer.fromJson<String>(json['timeWindowEnd']),
      confidence: serializer.fromJson<int>(json['confidence']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'metricType': serializer.toJson<int>(
        $BehaviorMetricsTable.$convertermetricType.toJson(metricType),
      ),
      'value': serializer.toJson<double>(value),
      'timeWindowStart': serializer.toJson<String>(timeWindowStart),
      'timeWindowEnd': serializer.toJson<String>(timeWindowEnd),
      'confidence': serializer.toJson<int>(confidence),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BehaviorMetric copyWith({
    String? id,
    BehaviorMetricType? metricType,
    double? value,
    String? timeWindowStart,
    String? timeWindowEnd,
    int? confidence,
    DateTime? createdAt,
  }) => BehaviorMetric(
    id: id ?? this.id,
    metricType: metricType ?? this.metricType,
    value: value ?? this.value,
    timeWindowStart: timeWindowStart ?? this.timeWindowStart,
    timeWindowEnd: timeWindowEnd ?? this.timeWindowEnd,
    confidence: confidence ?? this.confidence,
    createdAt: createdAt ?? this.createdAt,
  );
  BehaviorMetric copyWithCompanion(BehaviorMetricsCompanion data) {
    return BehaviorMetric(
      id: data.id.present ? data.id.value : this.id,
      metricType: data.metricType.present
          ? data.metricType.value
          : this.metricType,
      value: data.value.present ? data.value.value : this.value,
      timeWindowStart: data.timeWindowStart.present
          ? data.timeWindowStart.value
          : this.timeWindowStart,
      timeWindowEnd: data.timeWindowEnd.present
          ? data.timeWindowEnd.value
          : this.timeWindowEnd,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BehaviorMetric(')
          ..write('id: $id, ')
          ..write('metricType: $metricType, ')
          ..write('value: $value, ')
          ..write('timeWindowStart: $timeWindowStart, ')
          ..write('timeWindowEnd: $timeWindowEnd, ')
          ..write('confidence: $confidence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    metricType,
    value,
    timeWindowStart,
    timeWindowEnd,
    confidence,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BehaviorMetric &&
          other.id == this.id &&
          other.metricType == this.metricType &&
          other.value == this.value &&
          other.timeWindowStart == this.timeWindowStart &&
          other.timeWindowEnd == this.timeWindowEnd &&
          other.confidence == this.confidence &&
          other.createdAt == this.createdAt);
}

class BehaviorMetricsCompanion extends UpdateCompanion<BehaviorMetric> {
  final Value<String> id;
  final Value<BehaviorMetricType> metricType;
  final Value<double> value;
  final Value<String> timeWindowStart;
  final Value<String> timeWindowEnd;
  final Value<int> confidence;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BehaviorMetricsCompanion({
    this.id = const Value.absent(),
    this.metricType = const Value.absent(),
    this.value = const Value.absent(),
    this.timeWindowStart = const Value.absent(),
    this.timeWindowEnd = const Value.absent(),
    this.confidence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BehaviorMetricsCompanion.insert({
    required String id,
    required BehaviorMetricType metricType,
    required double value,
    required String timeWindowStart,
    required String timeWindowEnd,
    this.confidence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       metricType = Value(metricType),
       value = Value(value),
       timeWindowStart = Value(timeWindowStart),
       timeWindowEnd = Value(timeWindowEnd);
  static Insertable<BehaviorMetric> custom({
    Expression<String>? id,
    Expression<int>? metricType,
    Expression<double>? value,
    Expression<String>? timeWindowStart,
    Expression<String>? timeWindowEnd,
    Expression<int>? confidence,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (metricType != null) 'metric_type': metricType,
      if (value != null) 'value': value,
      if (timeWindowStart != null) 'time_window_start': timeWindowStart,
      if (timeWindowEnd != null) 'time_window_end': timeWindowEnd,
      if (confidence != null) 'confidence': confidence,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BehaviorMetricsCompanion copyWith({
    Value<String>? id,
    Value<BehaviorMetricType>? metricType,
    Value<double>? value,
    Value<String>? timeWindowStart,
    Value<String>? timeWindowEnd,
    Value<int>? confidence,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BehaviorMetricsCompanion(
      id: id ?? this.id,
      metricType: metricType ?? this.metricType,
      value: value ?? this.value,
      timeWindowStart: timeWindowStart ?? this.timeWindowStart,
      timeWindowEnd: timeWindowEnd ?? this.timeWindowEnd,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (metricType.present) {
      map['metric_type'] = Variable<int>(
        $BehaviorMetricsTable.$convertermetricType.toSql(metricType.value),
      );
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (timeWindowStart.present) {
      map['time_window_start'] = Variable<String>(timeWindowStart.value);
    }
    if (timeWindowEnd.present) {
      map['time_window_end'] = Variable<String>(timeWindowEnd.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<int>(confidence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BehaviorMetricsCompanion(')
          ..write('id: $id, ')
          ..write('metricType: $metricType, ')
          ..write('value: $value, ')
          ..write('timeWindowStart: $timeWindowStart, ')
          ..write('timeWindowEnd: $timeWindowEnd, ')
          ..write('confidence: $confidence, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConfidenceMeterTable extends ConfidenceMeter
    with TableInfo<$ConfidenceMeterTable, ConfidenceMeterData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConfidenceMeterTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _strategyAdherenceMeta = const VerificationMeta(
    'strategyAdherence',
  );
  @override
  late final GeneratedColumn<double> strategyAdherence =
      GeneratedColumn<double>(
        'strategy_adherence',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _consistencyMeta = const VerificationMeta(
    'consistency',
  );
  @override
  late final GeneratedColumn<double> consistency = GeneratedColumn<double>(
    'consistency',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emotionalStabilityMeta =
      const VerificationMeta('emotionalStability');
  @override
  late final GeneratedColumn<double> emotionalStability =
      GeneratedColumn<double>(
        'emotional_stability',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _calculatedAtMeta = const VerificationMeta(
    'calculatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> calculatedAt = GeneratedColumn<DateTime>(
    'calculated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    score,
    strategyAdherence,
    consistency,
    emotionalStability,
    calculatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'confidence_meter';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConfidenceMeterData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('strategy_adherence')) {
      context.handle(
        _strategyAdherenceMeta,
        strategyAdherence.isAcceptableOrUnknown(
          data['strategy_adherence']!,
          _strategyAdherenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_strategyAdherenceMeta);
    }
    if (data.containsKey('consistency')) {
      context.handle(
        _consistencyMeta,
        consistency.isAcceptableOrUnknown(
          data['consistency']!,
          _consistencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_consistencyMeta);
    }
    if (data.containsKey('emotional_stability')) {
      context.handle(
        _emotionalStabilityMeta,
        emotionalStability.isAcceptableOrUnknown(
          data['emotional_stability']!,
          _emotionalStabilityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_emotionalStabilityMeta);
    }
    if (data.containsKey('calculated_at')) {
      context.handle(
        _calculatedAtMeta,
        calculatedAt.isAcceptableOrUnknown(
          data['calculated_at']!,
          _calculatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConfidenceMeterData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConfidenceMeterData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      strategyAdherence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}strategy_adherence'],
      )!,
      consistency: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}consistency'],
      )!,
      emotionalStability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}emotional_stability'],
      )!,
      calculatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}calculated_at'],
      )!,
    );
  }

  @override
  $ConfidenceMeterTable createAlias(String alias) {
    return $ConfidenceMeterTable(attachedDatabase, alias);
  }
}

class ConfidenceMeterData extends DataClass
    implements Insertable<ConfidenceMeterData> {
  /// UUID primary key.
  final String id;

  /// Overall composite confidence score (0.0–100.0).
  final double score;

  /// Sub-score: how well actions matched stated strategy (0.0–100.0).
  final double strategyAdherence;

  /// Sub-score: consistency of decision-making cadence (0.0–100.0).
  final double consistency;

  /// Sub-score: absence of emotionally-driven decisions (0.0–100.0).
  final double emotionalStability;

  /// UTC timestamp when this score was calculated.
  final DateTime calculatedAt;
  const ConfidenceMeterData({
    required this.id,
    required this.score,
    required this.strategyAdherence,
    required this.consistency,
    required this.emotionalStability,
    required this.calculatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['score'] = Variable<double>(score);
    map['strategy_adherence'] = Variable<double>(strategyAdherence);
    map['consistency'] = Variable<double>(consistency);
    map['emotional_stability'] = Variable<double>(emotionalStability);
    map['calculated_at'] = Variable<DateTime>(calculatedAt);
    return map;
  }

  ConfidenceMeterCompanion toCompanion(bool nullToAbsent) {
    return ConfidenceMeterCompanion(
      id: Value(id),
      score: Value(score),
      strategyAdherence: Value(strategyAdherence),
      consistency: Value(consistency),
      emotionalStability: Value(emotionalStability),
      calculatedAt: Value(calculatedAt),
    );
  }

  factory ConfidenceMeterData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConfidenceMeterData(
      id: serializer.fromJson<String>(json['id']),
      score: serializer.fromJson<double>(json['score']),
      strategyAdherence: serializer.fromJson<double>(json['strategyAdherence']),
      consistency: serializer.fromJson<double>(json['consistency']),
      emotionalStability: serializer.fromJson<double>(
        json['emotionalStability'],
      ),
      calculatedAt: serializer.fromJson<DateTime>(json['calculatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'score': serializer.toJson<double>(score),
      'strategyAdherence': serializer.toJson<double>(strategyAdherence),
      'consistency': serializer.toJson<double>(consistency),
      'emotionalStability': serializer.toJson<double>(emotionalStability),
      'calculatedAt': serializer.toJson<DateTime>(calculatedAt),
    };
  }

  ConfidenceMeterData copyWith({
    String? id,
    double? score,
    double? strategyAdherence,
    double? consistency,
    double? emotionalStability,
    DateTime? calculatedAt,
  }) => ConfidenceMeterData(
    id: id ?? this.id,
    score: score ?? this.score,
    strategyAdherence: strategyAdherence ?? this.strategyAdherence,
    consistency: consistency ?? this.consistency,
    emotionalStability: emotionalStability ?? this.emotionalStability,
    calculatedAt: calculatedAt ?? this.calculatedAt,
  );
  ConfidenceMeterData copyWithCompanion(ConfidenceMeterCompanion data) {
    return ConfidenceMeterData(
      id: data.id.present ? data.id.value : this.id,
      score: data.score.present ? data.score.value : this.score,
      strategyAdherence: data.strategyAdherence.present
          ? data.strategyAdherence.value
          : this.strategyAdherence,
      consistency: data.consistency.present
          ? data.consistency.value
          : this.consistency,
      emotionalStability: data.emotionalStability.present
          ? data.emotionalStability.value
          : this.emotionalStability,
      calculatedAt: data.calculatedAt.present
          ? data.calculatedAt.value
          : this.calculatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConfidenceMeterData(')
          ..write('id: $id, ')
          ..write('score: $score, ')
          ..write('strategyAdherence: $strategyAdherence, ')
          ..write('consistency: $consistency, ')
          ..write('emotionalStability: $emotionalStability, ')
          ..write('calculatedAt: $calculatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    score,
    strategyAdherence,
    consistency,
    emotionalStability,
    calculatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfidenceMeterData &&
          other.id == this.id &&
          other.score == this.score &&
          other.strategyAdherence == this.strategyAdherence &&
          other.consistency == this.consistency &&
          other.emotionalStability == this.emotionalStability &&
          other.calculatedAt == this.calculatedAt);
}

class ConfidenceMeterCompanion extends UpdateCompanion<ConfidenceMeterData> {
  final Value<String> id;
  final Value<double> score;
  final Value<double> strategyAdherence;
  final Value<double> consistency;
  final Value<double> emotionalStability;
  final Value<DateTime> calculatedAt;
  final Value<int> rowid;
  const ConfidenceMeterCompanion({
    this.id = const Value.absent(),
    this.score = const Value.absent(),
    this.strategyAdherence = const Value.absent(),
    this.consistency = const Value.absent(),
    this.emotionalStability = const Value.absent(),
    this.calculatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConfidenceMeterCompanion.insert({
    required String id,
    required double score,
    required double strategyAdherence,
    required double consistency,
    required double emotionalStability,
    this.calculatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       score = Value(score),
       strategyAdherence = Value(strategyAdherence),
       consistency = Value(consistency),
       emotionalStability = Value(emotionalStability);
  static Insertable<ConfidenceMeterData> custom({
    Expression<String>? id,
    Expression<double>? score,
    Expression<double>? strategyAdherence,
    Expression<double>? consistency,
    Expression<double>? emotionalStability,
    Expression<DateTime>? calculatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (score != null) 'score': score,
      if (strategyAdherence != null) 'strategy_adherence': strategyAdherence,
      if (consistency != null) 'consistency': consistency,
      if (emotionalStability != null) 'emotional_stability': emotionalStability,
      if (calculatedAt != null) 'calculated_at': calculatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConfidenceMeterCompanion copyWith({
    Value<String>? id,
    Value<double>? score,
    Value<double>? strategyAdherence,
    Value<double>? consistency,
    Value<double>? emotionalStability,
    Value<DateTime>? calculatedAt,
    Value<int>? rowid,
  }) {
    return ConfidenceMeterCompanion(
      id: id ?? this.id,
      score: score ?? this.score,
      strategyAdherence: strategyAdherence ?? this.strategyAdherence,
      consistency: consistency ?? this.consistency,
      emotionalStability: emotionalStability ?? this.emotionalStability,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (strategyAdherence.present) {
      map['strategy_adherence'] = Variable<double>(strategyAdherence.value);
    }
    if (consistency.present) {
      map['consistency'] = Variable<double>(consistency.value);
    }
    if (emotionalStability.present) {
      map['emotional_stability'] = Variable<double>(emotionalStability.value);
    }
    if (calculatedAt.present) {
      map['calculated_at'] = Variable<DateTime>(calculatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConfidenceMeterCompanion(')
          ..write('id: $id, ')
          ..write('score: $score, ')
          ..write('strategyAdherence: $strategyAdherence, ')
          ..write('consistency: $consistency, ')
          ..write('emotionalStability: $emotionalStability, ')
          ..write('calculatedAt: $calculatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportsTable extends Imports with TableInfo<$ImportsTable, Import> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ImportType, int> importType =
      GeneratedColumn<int>(
        'import_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ImportType>($ImportsTable.$converterimportType);
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowsImportedMeta = const VerificationMeta(
    'rowsImported',
  );
  @override
  late final GeneratedColumn<int> rowsImported = GeneratedColumn<int>(
    'rows_imported',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _successRateMeta = const VerificationMeta(
    'successRate',
  );
  @override
  late final GeneratedColumn<int> successRate = GeneratedColumn<int>(
    'success_rate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    importType,
    sourceName,
    rowsImported,
    successRate,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'imports';
  @override
  VerificationContext validateIntegrity(
    Insertable<Import> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceNameMeta);
    }
    if (data.containsKey('rows_imported')) {
      context.handle(
        _rowsImportedMeta,
        rowsImported.isAcceptableOrUnknown(
          data['rows_imported']!,
          _rowsImportedMeta,
        ),
      );
    }
    if (data.containsKey('success_rate')) {
      context.handle(
        _successRateMeta,
        successRate.isAcceptableOrUnknown(
          data['success_rate']!,
          _successRateMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Import map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Import(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      importType: $ImportsTable.$converterimportType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}import_type'],
        )!,
      ),
      sourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_name'],
      )!,
      rowsImported: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rows_imported'],
      )!,
      successRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}success_rate'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ImportsTable createAlias(String alias) {
    return $ImportsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ImportType, int, int> $converterimportType =
      const EnumIndexConverter<ImportType>(ImportType.values);
}

class Import extends DataClass implements Insertable<Import> {
  /// UUID primary key.
  final String id;

  /// Whether this was an email or CSV import.
  final ImportType importType;

  /// Human-readable source (e.g. "Zerodha CSV", "HDFC Securities Email").
  final String sourceName;

  /// Number of trade rows imported in this session.
  final int rowsImported;

  /// Percentage of rows that were successfully parsed (0–100).
  final int successRate;

  /// UTC timestamp of ingestion.
  final DateTime createdAt;
  const Import({
    required this.id,
    required this.importType,
    required this.sourceName,
    required this.rowsImported,
    required this.successRate,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['import_type'] = Variable<int>(
        $ImportsTable.$converterimportType.toSql(importType),
      );
    }
    map['source_name'] = Variable<String>(sourceName);
    map['rows_imported'] = Variable<int>(rowsImported);
    map['success_rate'] = Variable<int>(successRate);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ImportsCompanion toCompanion(bool nullToAbsent) {
    return ImportsCompanion(
      id: Value(id),
      importType: Value(importType),
      sourceName: Value(sourceName),
      rowsImported: Value(rowsImported),
      successRate: Value(successRate),
      createdAt: Value(createdAt),
    );
  }

  factory Import.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Import(
      id: serializer.fromJson<String>(json['id']),
      importType: $ImportsTable.$converterimportType.fromJson(
        serializer.fromJson<int>(json['importType']),
      ),
      sourceName: serializer.fromJson<String>(json['sourceName']),
      rowsImported: serializer.fromJson<int>(json['rowsImported']),
      successRate: serializer.fromJson<int>(json['successRate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'importType': serializer.toJson<int>(
        $ImportsTable.$converterimportType.toJson(importType),
      ),
      'sourceName': serializer.toJson<String>(sourceName),
      'rowsImported': serializer.toJson<int>(rowsImported),
      'successRate': serializer.toJson<int>(successRate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Import copyWith({
    String? id,
    ImportType? importType,
    String? sourceName,
    int? rowsImported,
    int? successRate,
    DateTime? createdAt,
  }) => Import(
    id: id ?? this.id,
    importType: importType ?? this.importType,
    sourceName: sourceName ?? this.sourceName,
    rowsImported: rowsImported ?? this.rowsImported,
    successRate: successRate ?? this.successRate,
    createdAt: createdAt ?? this.createdAt,
  );
  Import copyWithCompanion(ImportsCompanion data) {
    return Import(
      id: data.id.present ? data.id.value : this.id,
      importType: data.importType.present
          ? data.importType.value
          : this.importType,
      sourceName: data.sourceName.present
          ? data.sourceName.value
          : this.sourceName,
      rowsImported: data.rowsImported.present
          ? data.rowsImported.value
          : this.rowsImported,
      successRate: data.successRate.present
          ? data.successRate.value
          : this.successRate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Import(')
          ..write('id: $id, ')
          ..write('importType: $importType, ')
          ..write('sourceName: $sourceName, ')
          ..write('rowsImported: $rowsImported, ')
          ..write('successRate: $successRate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    importType,
    sourceName,
    rowsImported,
    successRate,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Import &&
          other.id == this.id &&
          other.importType == this.importType &&
          other.sourceName == this.sourceName &&
          other.rowsImported == this.rowsImported &&
          other.successRate == this.successRate &&
          other.createdAt == this.createdAt);
}

class ImportsCompanion extends UpdateCompanion<Import> {
  final Value<String> id;
  final Value<ImportType> importType;
  final Value<String> sourceName;
  final Value<int> rowsImported;
  final Value<int> successRate;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ImportsCompanion({
    this.id = const Value.absent(),
    this.importType = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.rowsImported = const Value.absent(),
    this.successRate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportsCompanion.insert({
    required String id,
    required ImportType importType,
    required String sourceName,
    this.rowsImported = const Value.absent(),
    this.successRate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       importType = Value(importType),
       sourceName = Value(sourceName);
  static Insertable<Import> custom({
    Expression<String>? id,
    Expression<int>? importType,
    Expression<String>? sourceName,
    Expression<int>? rowsImported,
    Expression<int>? successRate,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (importType != null) 'import_type': importType,
      if (sourceName != null) 'source_name': sourceName,
      if (rowsImported != null) 'rows_imported': rowsImported,
      if (successRate != null) 'success_rate': successRate,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportsCompanion copyWith({
    Value<String>? id,
    Value<ImportType>? importType,
    Value<String>? sourceName,
    Value<int>? rowsImported,
    Value<int>? successRate,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ImportsCompanion(
      id: id ?? this.id,
      importType: importType ?? this.importType,
      sourceName: sourceName ?? this.sourceName,
      rowsImported: rowsImported ?? this.rowsImported,
      successRate: successRate ?? this.successRate,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (importType.present) {
      map['import_type'] = Variable<int>(
        $ImportsTable.$converterimportType.toSql(importType.value),
      );
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (rowsImported.present) {
      map['rows_imported'] = Variable<int>(rowsImported.value);
    }
    if (successRate.present) {
      map['success_rate'] = Variable<int>(successRate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportsCompanion(')
          ..write('id: $id, ')
          ..write('importType: $importType, ')
          ..write('sourceName: $sourceName, ')
          ..write('rowsImported: $rowsImported, ')
          ..write('successRate: $successRate, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IntegrityMetadataTable extends IntegrityMetadata
    with TableInfo<$IntegrityMetadataTable, IntegrityMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IntegrityMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chainIdMeta = const VerificationMeta(
    'chainId',
  );
  @override
  late final GeneratedColumn<String> chainId = GeneratedColumn<String>(
    'chain_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tailHashMeta = const VerificationMeta(
    'tailHash',
  );
  @override
  late final GeneratedColumn<String> tailHash = GeneratedColumn<String>(
    'tail_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowCountMeta = const VerificationMeta(
    'rowCount',
  );
  @override
  late final GeneratedColumn<int> rowCount = GeneratedColumn<int>(
    'row_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastVerifiedAtMeta = const VerificationMeta(
    'lastVerifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastVerifiedAt =
      GeneratedColumn<DateTime>(
        'last_verified_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  @override
  List<GeneratedColumn> get $columns => [
    chainId,
    tailHash,
    rowCount,
    lastVerifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'integrity_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<IntegrityMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chain_id')) {
      context.handle(
        _chainIdMeta,
        chainId.isAcceptableOrUnknown(data['chain_id']!, _chainIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chainIdMeta);
    }
    if (data.containsKey('tail_hash')) {
      context.handle(
        _tailHashMeta,
        tailHash.isAcceptableOrUnknown(data['tail_hash']!, _tailHashMeta),
      );
    } else if (isInserting) {
      context.missing(_tailHashMeta);
    }
    if (data.containsKey('row_count')) {
      context.handle(
        _rowCountMeta,
        rowCount.isAcceptableOrUnknown(data['row_count']!, _rowCountMeta),
      );
    }
    if (data.containsKey('last_verified_at')) {
      context.handle(
        _lastVerifiedAtMeta,
        lastVerifiedAt.isAcceptableOrUnknown(
          data['last_verified_at']!,
          _lastVerifiedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chainId};
  @override
  IntegrityMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IntegrityMetadataData(
      chainId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chain_id'],
      )!,
      tailHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tail_hash'],
      )!,
      rowCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_count'],
      )!,
      lastVerifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_verified_at'],
      )!,
    );
  }

  @override
  $IntegrityMetadataTable createAlias(String alias) {
    return $IntegrityMetadataTable(attachedDatabase, alias);
  }
}

class IntegrityMetadataData extends DataClass
    implements Insertable<IntegrityMetadataData> {
  /// The table name or chain identifier (e.g., 'trades', 'alerts').
  final String chainId;

  /// The SHA-256 hash of the last successfully committed row in this chain.
  final String tailHash;

  /// Total number of rows verified in this chain.
  final int rowCount;

  /// Last verification timestamp.
  final DateTime lastVerifiedAt;
  const IntegrityMetadataData({
    required this.chainId,
    required this.tailHash,
    required this.rowCount,
    required this.lastVerifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chain_id'] = Variable<String>(chainId);
    map['tail_hash'] = Variable<String>(tailHash);
    map['row_count'] = Variable<int>(rowCount);
    map['last_verified_at'] = Variable<DateTime>(lastVerifiedAt);
    return map;
  }

  IntegrityMetadataCompanion toCompanion(bool nullToAbsent) {
    return IntegrityMetadataCompanion(
      chainId: Value(chainId),
      tailHash: Value(tailHash),
      rowCount: Value(rowCount),
      lastVerifiedAt: Value(lastVerifiedAt),
    );
  }

  factory IntegrityMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IntegrityMetadataData(
      chainId: serializer.fromJson<String>(json['chainId']),
      tailHash: serializer.fromJson<String>(json['tailHash']),
      rowCount: serializer.fromJson<int>(json['rowCount']),
      lastVerifiedAt: serializer.fromJson<DateTime>(json['lastVerifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chainId': serializer.toJson<String>(chainId),
      'tailHash': serializer.toJson<String>(tailHash),
      'rowCount': serializer.toJson<int>(rowCount),
      'lastVerifiedAt': serializer.toJson<DateTime>(lastVerifiedAt),
    };
  }

  IntegrityMetadataData copyWith({
    String? chainId,
    String? tailHash,
    int? rowCount,
    DateTime? lastVerifiedAt,
  }) => IntegrityMetadataData(
    chainId: chainId ?? this.chainId,
    tailHash: tailHash ?? this.tailHash,
    rowCount: rowCount ?? this.rowCount,
    lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
  );
  IntegrityMetadataData copyWithCompanion(IntegrityMetadataCompanion data) {
    return IntegrityMetadataData(
      chainId: data.chainId.present ? data.chainId.value : this.chainId,
      tailHash: data.tailHash.present ? data.tailHash.value : this.tailHash,
      rowCount: data.rowCount.present ? data.rowCount.value : this.rowCount,
      lastVerifiedAt: data.lastVerifiedAt.present
          ? data.lastVerifiedAt.value
          : this.lastVerifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IntegrityMetadataData(')
          ..write('chainId: $chainId, ')
          ..write('tailHash: $tailHash, ')
          ..write('rowCount: $rowCount, ')
          ..write('lastVerifiedAt: $lastVerifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chainId, tailHash, rowCount, lastVerifiedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrityMetadataData &&
          other.chainId == this.chainId &&
          other.tailHash == this.tailHash &&
          other.rowCount == this.rowCount &&
          other.lastVerifiedAt == this.lastVerifiedAt);
}

class IntegrityMetadataCompanion
    extends UpdateCompanion<IntegrityMetadataData> {
  final Value<String> chainId;
  final Value<String> tailHash;
  final Value<int> rowCount;
  final Value<DateTime> lastVerifiedAt;
  final Value<int> rowid;
  const IntegrityMetadataCompanion({
    this.chainId = const Value.absent(),
    this.tailHash = const Value.absent(),
    this.rowCount = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IntegrityMetadataCompanion.insert({
    required String chainId,
    required String tailHash,
    this.rowCount = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : chainId = Value(chainId),
       tailHash = Value(tailHash);
  static Insertable<IntegrityMetadataData> custom({
    Expression<String>? chainId,
    Expression<String>? tailHash,
    Expression<int>? rowCount,
    Expression<DateTime>? lastVerifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chainId != null) 'chain_id': chainId,
      if (tailHash != null) 'tail_hash': tailHash,
      if (rowCount != null) 'row_count': rowCount,
      if (lastVerifiedAt != null) 'last_verified_at': lastVerifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IntegrityMetadataCompanion copyWith({
    Value<String>? chainId,
    Value<String>? tailHash,
    Value<int>? rowCount,
    Value<DateTime>? lastVerifiedAt,
    Value<int>? rowid,
  }) {
    return IntegrityMetadataCompanion(
      chainId: chainId ?? this.chainId,
      tailHash: tailHash ?? this.tailHash,
      rowCount: rowCount ?? this.rowCount,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chainId.present) {
      map['chain_id'] = Variable<String>(chainId.value);
    }
    if (tailHash.present) {
      map['tail_hash'] = Variable<String>(tailHash.value);
    }
    if (rowCount.present) {
      map['row_count'] = Variable<int>(rowCount.value);
    }
    if (lastVerifiedAt.present) {
      map['last_verified_at'] = Variable<DateTime>(lastVerifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntegrityMetadataCompanion(')
          ..write('chainId: $chainId, ')
          ..write('tailHash: $tailHash, ')
          ..write('rowCount: $rowCount, ')
          ..write('lastVerifiedAt: $lastVerifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ColumnMappingsTable extends ColumnMappings
    with TableInfo<$ColumnMappingsTable, ColumnMapping> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ColumnMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mappingJsonMeta = const VerificationMeta(
    'mappingJson',
  );
  @override
  late final GeneratedColumn<String> mappingJson = GeneratedColumn<String>(
    'mapping_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceName,
    mappingJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'column_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ColumnMapping> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceNameMeta);
    }
    if (data.containsKey('mapping_json')) {
      context.handle(
        _mappingJsonMeta,
        mappingJson.isAcceptableOrUnknown(
          data['mapping_json']!,
          _mappingJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mappingJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ColumnMapping map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ColumnMapping(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_name'],
      )!,
      mappingJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mapping_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ColumnMappingsTable createAlias(String alias) {
    return $ColumnMappingsTable(attachedDatabase, alias);
  }
}

class ColumnMapping extends DataClass implements Insertable<ColumnMapping> {
  /// UUID primary key.
  final String id;

  /// Broker/source label (e.g. "Zerodha Tradebook", "Groww Equity").
  final String sourceName;

  /// Serialized column→field mapping as JSON.
  final String mappingJson;

  /// UTC row creation time.
  final DateTime createdAt;
  const ColumnMapping({
    required this.id,
    required this.sourceName,
    required this.mappingJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_name'] = Variable<String>(sourceName);
    map['mapping_json'] = Variable<String>(mappingJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ColumnMappingsCompanion toCompanion(bool nullToAbsent) {
    return ColumnMappingsCompanion(
      id: Value(id),
      sourceName: Value(sourceName),
      mappingJson: Value(mappingJson),
      createdAt: Value(createdAt),
    );
  }

  factory ColumnMapping.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ColumnMapping(
      id: serializer.fromJson<String>(json['id']),
      sourceName: serializer.fromJson<String>(json['sourceName']),
      mappingJson: serializer.fromJson<String>(json['mappingJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceName': serializer.toJson<String>(sourceName),
      'mappingJson': serializer.toJson<String>(mappingJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ColumnMapping copyWith({
    String? id,
    String? sourceName,
    String? mappingJson,
    DateTime? createdAt,
  }) => ColumnMapping(
    id: id ?? this.id,
    sourceName: sourceName ?? this.sourceName,
    mappingJson: mappingJson ?? this.mappingJson,
    createdAt: createdAt ?? this.createdAt,
  );
  ColumnMapping copyWithCompanion(ColumnMappingsCompanion data) {
    return ColumnMapping(
      id: data.id.present ? data.id.value : this.id,
      sourceName: data.sourceName.present
          ? data.sourceName.value
          : this.sourceName,
      mappingJson: data.mappingJson.present
          ? data.mappingJson.value
          : this.mappingJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ColumnMapping(')
          ..write('id: $id, ')
          ..write('sourceName: $sourceName, ')
          ..write('mappingJson: $mappingJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sourceName, mappingJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ColumnMapping &&
          other.id == this.id &&
          other.sourceName == this.sourceName &&
          other.mappingJson == this.mappingJson &&
          other.createdAt == this.createdAt);
}

class ColumnMappingsCompanion extends UpdateCompanion<ColumnMapping> {
  final Value<String> id;
  final Value<String> sourceName;
  final Value<String> mappingJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ColumnMappingsCompanion({
    this.id = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.mappingJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ColumnMappingsCompanion.insert({
    required String id,
    required String sourceName,
    required String mappingJson,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceName = Value(sourceName),
       mappingJson = Value(mappingJson);
  static Insertable<ColumnMapping> custom({
    Expression<String>? id,
    Expression<String>? sourceName,
    Expression<String>? mappingJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceName != null) 'source_name': sourceName,
      if (mappingJson != null) 'mapping_json': mappingJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ColumnMappingsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceName,
    Value<String>? mappingJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ColumnMappingsCompanion(
      id: id ?? this.id,
      sourceName: sourceName ?? this.sourceName,
      mappingJson: mappingJson ?? this.mappingJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (mappingJson.present) {
      map['mapping_json'] = Variable<String>(mappingJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ColumnMappingsCompanion(')
          ..write('id: $id, ')
          ..write('sourceName: $sourceName, ')
          ..write('mappingJson: $mappingJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmailCredentialsTable extends EmailCredentials
    with TableInfo<$EmailCredentialsTable, EmailCredential> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmailCredentialsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailAddressMeta = const VerificationMeta(
    'emailAddress',
  );
  @override
  late final GeneratedColumn<String> emailAddress = GeneratedColumn<String>(
    'email_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authTypeMeta = const VerificationMeta(
    'authType',
  );
  @override
  late final GeneratedColumn<int> authType = GeneratedColumn<int>(
    'auth_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _credentialsEncryptedMeta =
      const VerificationMeta('credentialsEncrypted');
  @override
  late final GeneratedColumn<String> credentialsEncrypted =
      GeneratedColumn<String>(
        'credentials_encrypted',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    emailAddress,
    authType,
    credentialsEncrypted,
    createdAt,
    lastUsedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'email_credentials';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmailCredential> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email_address')) {
      context.handle(
        _emailAddressMeta,
        emailAddress.isAcceptableOrUnknown(
          data['email_address']!,
          _emailAddressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_emailAddressMeta);
    }
    if (data.containsKey('auth_type')) {
      context.handle(
        _authTypeMeta,
        authType.isAcceptableOrUnknown(data['auth_type']!, _authTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_authTypeMeta);
    }
    if (data.containsKey('credentials_encrypted')) {
      context.handle(
        _credentialsEncryptedMeta,
        credentialsEncrypted.isAcceptableOrUnknown(
          data['credentials_encrypted']!,
          _credentialsEncryptedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_credentialsEncryptedMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EmailCredential map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmailCredential(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      emailAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email_address'],
      )!,
      authType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auth_type'],
      )!,
      credentialsEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credentials_encrypted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      ),
    );
  }

  @override
  $EmailCredentialsTable createAlias(String alias) {
    return $EmailCredentialsTable(attachedDatabase, alias);
  }
}

class EmailCredential extends DataClass implements Insertable<EmailCredential> {
  /// UUID primary key.
  final String id;

  /// Email address for display/identification.
  final String emailAddress;

  /// Auth method: 0 = IMAP, 1 = Gmail OAuth.
  final int authType;

  /// AES-256-GCM encrypted credentials blob.
  /// Contains either IMAP password or OAuth refresh token.
  final String credentialsEncrypted;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// Last successful connection timestamp.
  final DateTime? lastUsedAt;
  const EmailCredential({
    required this.id,
    required this.emailAddress,
    required this.authType,
    required this.credentialsEncrypted,
    required this.createdAt,
    this.lastUsedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email_address'] = Variable<String>(emailAddress);
    map['auth_type'] = Variable<int>(authType);
    map['credentials_encrypted'] = Variable<String>(credentialsEncrypted);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    return map;
  }

  EmailCredentialsCompanion toCompanion(bool nullToAbsent) {
    return EmailCredentialsCompanion(
      id: Value(id),
      emailAddress: Value(emailAddress),
      authType: Value(authType),
      credentialsEncrypted: Value(credentialsEncrypted),
      createdAt: Value(createdAt),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
    );
  }

  factory EmailCredential.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmailCredential(
      id: serializer.fromJson<String>(json['id']),
      emailAddress: serializer.fromJson<String>(json['emailAddress']),
      authType: serializer.fromJson<int>(json['authType']),
      credentialsEncrypted: serializer.fromJson<String>(
        json['credentialsEncrypted'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'emailAddress': serializer.toJson<String>(emailAddress),
      'authType': serializer.toJson<int>(authType),
      'credentialsEncrypted': serializer.toJson<String>(credentialsEncrypted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
    };
  }

  EmailCredential copyWith({
    String? id,
    String? emailAddress,
    int? authType,
    String? credentialsEncrypted,
    DateTime? createdAt,
    Value<DateTime?> lastUsedAt = const Value.absent(),
  }) => EmailCredential(
    id: id ?? this.id,
    emailAddress: emailAddress ?? this.emailAddress,
    authType: authType ?? this.authType,
    credentialsEncrypted: credentialsEncrypted ?? this.credentialsEncrypted,
    createdAt: createdAt ?? this.createdAt,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
  );
  EmailCredential copyWithCompanion(EmailCredentialsCompanion data) {
    return EmailCredential(
      id: data.id.present ? data.id.value : this.id,
      emailAddress: data.emailAddress.present
          ? data.emailAddress.value
          : this.emailAddress,
      authType: data.authType.present ? data.authType.value : this.authType,
      credentialsEncrypted: data.credentialsEncrypted.present
          ? data.credentialsEncrypted.value
          : this.credentialsEncrypted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmailCredential(')
          ..write('id: $id, ')
          ..write('emailAddress: $emailAddress, ')
          ..write('authType: $authType, ')
          ..write('credentialsEncrypted: $credentialsEncrypted, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    emailAddress,
    authType,
    credentialsEncrypted,
    createdAt,
    lastUsedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmailCredential &&
          other.id == this.id &&
          other.emailAddress == this.emailAddress &&
          other.authType == this.authType &&
          other.credentialsEncrypted == this.credentialsEncrypted &&
          other.createdAt == this.createdAt &&
          other.lastUsedAt == this.lastUsedAt);
}

class EmailCredentialsCompanion extends UpdateCompanion<EmailCredential> {
  final Value<String> id;
  final Value<String> emailAddress;
  final Value<int> authType;
  final Value<String> credentialsEncrypted;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastUsedAt;
  final Value<int> rowid;
  const EmailCredentialsCompanion({
    this.id = const Value.absent(),
    this.emailAddress = const Value.absent(),
    this.authType = const Value.absent(),
    this.credentialsEncrypted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmailCredentialsCompanion.insert({
    required String id,
    required String emailAddress,
    required int authType,
    required String credentialsEncrypted,
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       emailAddress = Value(emailAddress),
       authType = Value(authType),
       credentialsEncrypted = Value(credentialsEncrypted);
  static Insertable<EmailCredential> custom({
    Expression<String>? id,
    Expression<String>? emailAddress,
    Expression<int>? authType,
    Expression<String>? credentialsEncrypted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (emailAddress != null) 'email_address': emailAddress,
      if (authType != null) 'auth_type': authType,
      if (credentialsEncrypted != null)
        'credentials_encrypted': credentialsEncrypted,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmailCredentialsCompanion copyWith({
    Value<String>? id,
    Value<String>? emailAddress,
    Value<int>? authType,
    Value<String>? credentialsEncrypted,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastUsedAt,
    Value<int>? rowid,
  }) {
    return EmailCredentialsCompanion(
      id: id ?? this.id,
      emailAddress: emailAddress ?? this.emailAddress,
      authType: authType ?? this.authType,
      credentialsEncrypted: credentialsEncrypted ?? this.credentialsEncrypted,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (emailAddress.present) {
      map['email_address'] = Variable<String>(emailAddress.value);
    }
    if (authType.present) {
      map['auth_type'] = Variable<int>(authType.value);
    }
    if (credentialsEncrypted.present) {
      map['credentials_encrypted'] = Variable<String>(
        credentialsEncrypted.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmailCredentialsCompanion(')
          ..write('id: $id, ')
          ..write('emailAddress: $emailAddress, ')
          ..write('authType: $authType, ')
          ..write('credentialsEncrypted: $credentialsEncrypted, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TradesTable trades = $TradesTable(this);
  late final $TradeReasonsTable tradeReasons = $TradeReasonsTable(this);
  late final $HoldingsTable holdings = $HoldingsTable(this);
  late final $PriceHistoryTable priceHistory = $PriceHistoryTable(this);
  late final $PortfolioSnapshotsTable portfolioSnapshots =
      $PortfolioSnapshotsTable(this);
  late final $AlertsTable alerts = $AlertsTable(this);
  late final $BehaviorMetricsTable behaviorMetrics = $BehaviorMetricsTable(
    this,
  );
  late final $ConfidenceMeterTable confidenceMeter = $ConfidenceMeterTable(
    this,
  );
  late final $ImportsTable imports = $ImportsTable(this);
  late final $IntegrityMetadataTable integrityMetadata =
      $IntegrityMetadataTable(this);
  late final $ColumnMappingsTable columnMappings = $ColumnMappingsTable(this);
  late final $EmailCredentialsTable emailCredentials = $EmailCredentialsTable(
    this,
  );
  late final TradesDao tradesDao = TradesDao(this as AppDatabase);
  late final HoldingsDao holdingsDao = HoldingsDao(this as AppDatabase);
  late final AlertsDao alertsDao = AlertsDao(this as AppDatabase);
  late final BehaviorDao behaviorDao = BehaviorDao(this as AppDatabase);
  late final ImportDao importDao = ImportDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    trades,
    tradeReasons,
    holdings,
    priceHistory,
    portfolioSnapshots,
    alerts,
    behaviorMetrics,
    confidenceMeter,
    imports,
    integrityMetadata,
    columnMappings,
    emailCredentials,
  ];
}

typedef $$TradesTableCreateCompanionBuilder =
    TradesCompanion Function({
      required String id,
      required String instrumentSymbol,
      required String instrumentName,
      Value<String?> exchange,
      required TradeType tradeType,
      required double quantity,
      required double pricePerUnit,
      required double totalValue,
      required DateTime tradeTimestamp,
      Value<String> broker,
      Value<double?> charges,
      Value<String> currency,
      required TradeSource source,
      Value<String?> sourceReference,
      Value<String?> importId,
      Value<int> parseConfidence,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> tamperHash,
      Value<int> rowid,
    });
typedef $$TradesTableUpdateCompanionBuilder =
    TradesCompanion Function({
      Value<String> id,
      Value<String> instrumentSymbol,
      Value<String> instrumentName,
      Value<String?> exchange,
      Value<TradeType> tradeType,
      Value<double> quantity,
      Value<double> pricePerUnit,
      Value<double> totalValue,
      Value<DateTime> tradeTimestamp,
      Value<String> broker,
      Value<double?> charges,
      Value<String> currency,
      Value<TradeSource> source,
      Value<String?> sourceReference,
      Value<String?> importId,
      Value<int> parseConfidence,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> tamperHash,
      Value<int> rowid,
    });

class $$TradesTableFilterComposer
    extends Composer<_$AppDatabase, $TradesTable> {
  $$TradesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instrumentSymbol => $composableBuilder(
    column: $table.instrumentSymbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instrumentName => $composableBuilder(
    column: $table.instrumentName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchange => $composableBuilder(
    column: $table.exchange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TradeType, TradeType, int> get tradeType =>
      $composableBuilder(
        column: $table.tradeType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pricePerUnit => $composableBuilder(
    column: $table.pricePerUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalValue => $composableBuilder(
    column: $table.totalValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tradeTimestamp => $composableBuilder(
    column: $table.tradeTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get broker => $composableBuilder(
    column: $table.broker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get charges => $composableBuilder(
    column: $table.charges,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TradeSource, TradeSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get sourceReference => $composableBuilder(
    column: $table.sourceReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importId => $composableBuilder(
    column: $table.importId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parseConfidence => $composableBuilder(
    column: $table.parseConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tamperHash => $composableBuilder(
    column: $table.tamperHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TradesTableOrderingComposer
    extends Composer<_$AppDatabase, $TradesTable> {
  $$TradesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentSymbol => $composableBuilder(
    column: $table.instrumentSymbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentName => $composableBuilder(
    column: $table.instrumentName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchange => $composableBuilder(
    column: $table.exchange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tradeType => $composableBuilder(
    column: $table.tradeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pricePerUnit => $composableBuilder(
    column: $table.pricePerUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalValue => $composableBuilder(
    column: $table.totalValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tradeTimestamp => $composableBuilder(
    column: $table.tradeTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get broker => $composableBuilder(
    column: $table.broker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get charges => $composableBuilder(
    column: $table.charges,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceReference => $composableBuilder(
    column: $table.sourceReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importId => $composableBuilder(
    column: $table.importId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parseConfidence => $composableBuilder(
    column: $table.parseConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tamperHash => $composableBuilder(
    column: $table.tamperHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TradesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TradesTable> {
  $$TradesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get instrumentSymbol => $composableBuilder(
    column: $table.instrumentSymbol,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instrumentName => $composableBuilder(
    column: $table.instrumentName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exchange =>
      $composableBuilder(column: $table.exchange, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TradeType, int> get tradeType =>
      $composableBuilder(column: $table.tradeType, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get pricePerUnit => $composableBuilder(
    column: $table.pricePerUnit,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalValue => $composableBuilder(
    column: $table.totalValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get tradeTimestamp => $composableBuilder(
    column: $table.tradeTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get broker =>
      $composableBuilder(column: $table.broker, builder: (column) => column);

  GeneratedColumn<double> get charges =>
      $composableBuilder(column: $table.charges, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TradeSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceReference => $composableBuilder(
    column: $table.sourceReference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importId =>
      $composableBuilder(column: $table.importId, builder: (column) => column);

  GeneratedColumn<int> get parseConfidence => $composableBuilder(
    column: $table.parseConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get tamperHash => $composableBuilder(
    column: $table.tamperHash,
    builder: (column) => column,
  );
}

class $$TradesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TradesTable,
          Trade,
          $$TradesTableFilterComposer,
          $$TradesTableOrderingComposer,
          $$TradesTableAnnotationComposer,
          $$TradesTableCreateCompanionBuilder,
          $$TradesTableUpdateCompanionBuilder,
          (Trade, BaseReferences<_$AppDatabase, $TradesTable, Trade>),
          Trade,
          PrefetchHooks Function()
        > {
  $$TradesTableTableManager(_$AppDatabase db, $TradesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TradesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TradesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TradesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> instrumentSymbol = const Value.absent(),
                Value<String> instrumentName = const Value.absent(),
                Value<String?> exchange = const Value.absent(),
                Value<TradeType> tradeType = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> pricePerUnit = const Value.absent(),
                Value<double> totalValue = const Value.absent(),
                Value<DateTime> tradeTimestamp = const Value.absent(),
                Value<String> broker = const Value.absent(),
                Value<double?> charges = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<TradeSource> source = const Value.absent(),
                Value<String?> sourceReference = const Value.absent(),
                Value<String?> importId = const Value.absent(),
                Value<int> parseConfidence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> tamperHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TradesCompanion(
                id: id,
                instrumentSymbol: instrumentSymbol,
                instrumentName: instrumentName,
                exchange: exchange,
                tradeType: tradeType,
                quantity: quantity,
                pricePerUnit: pricePerUnit,
                totalValue: totalValue,
                tradeTimestamp: tradeTimestamp,
                broker: broker,
                charges: charges,
                currency: currency,
                source: source,
                sourceReference: sourceReference,
                importId: importId,
                parseConfidence: parseConfidence,
                createdAt: createdAt,
                updatedAt: updatedAt,
                tamperHash: tamperHash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String instrumentSymbol,
                required String instrumentName,
                Value<String?> exchange = const Value.absent(),
                required TradeType tradeType,
                required double quantity,
                required double pricePerUnit,
                required double totalValue,
                required DateTime tradeTimestamp,
                Value<String> broker = const Value.absent(),
                Value<double?> charges = const Value.absent(),
                Value<String> currency = const Value.absent(),
                required TradeSource source,
                Value<String?> sourceReference = const Value.absent(),
                Value<String?> importId = const Value.absent(),
                Value<int> parseConfidence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> tamperHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TradesCompanion.insert(
                id: id,
                instrumentSymbol: instrumentSymbol,
                instrumentName: instrumentName,
                exchange: exchange,
                tradeType: tradeType,
                quantity: quantity,
                pricePerUnit: pricePerUnit,
                totalValue: totalValue,
                tradeTimestamp: tradeTimestamp,
                broker: broker,
                charges: charges,
                currency: currency,
                source: source,
                sourceReference: sourceReference,
                importId: importId,
                parseConfidence: parseConfidence,
                createdAt: createdAt,
                updatedAt: updatedAt,
                tamperHash: tamperHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TradesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TradesTable,
      Trade,
      $$TradesTableFilterComposer,
      $$TradesTableOrderingComposer,
      $$TradesTableAnnotationComposer,
      $$TradesTableCreateCompanionBuilder,
      $$TradesTableUpdateCompanionBuilder,
      (Trade, BaseReferences<_$AppDatabase, $TradesTable, Trade>),
      Trade,
      PrefetchHooks Function()
    >;
typedef $$TradeReasonsTableCreateCompanionBuilder =
    TradeReasonsCompanion Function({
      required String id,
      required String tradeId,
      Value<String?> reasonTextEncrypted,
      Value<String> tagsJson,
      Value<String?> emotionalStateEncrypted,
      Value<int?> confidenceLevel,
      Value<DateTime> createdAt,
      Value<String?> tamperHash,
      Value<int> rowid,
    });
typedef $$TradeReasonsTableUpdateCompanionBuilder =
    TradeReasonsCompanion Function({
      Value<String> id,
      Value<String> tradeId,
      Value<String?> reasonTextEncrypted,
      Value<String> tagsJson,
      Value<String?> emotionalStateEncrypted,
      Value<int?> confidenceLevel,
      Value<DateTime> createdAt,
      Value<String?> tamperHash,
      Value<int> rowid,
    });

class $$TradeReasonsTableFilterComposer
    extends Composer<_$AppDatabase, $TradeReasonsTable> {
  $$TradeReasonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tradeId => $composableBuilder(
    column: $table.tradeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasonTextEncrypted => $composableBuilder(
    column: $table.reasonTextEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emotionalStateEncrypted => $composableBuilder(
    column: $table.emotionalStateEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confidenceLevel => $composableBuilder(
    column: $table.confidenceLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tamperHash => $composableBuilder(
    column: $table.tamperHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TradeReasonsTableOrderingComposer
    extends Composer<_$AppDatabase, $TradeReasonsTable> {
  $$TradeReasonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tradeId => $composableBuilder(
    column: $table.tradeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasonTextEncrypted => $composableBuilder(
    column: $table.reasonTextEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emotionalStateEncrypted => $composableBuilder(
    column: $table.emotionalStateEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confidenceLevel => $composableBuilder(
    column: $table.confidenceLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tamperHash => $composableBuilder(
    column: $table.tamperHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TradeReasonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TradeReasonsTable> {
  $$TradeReasonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tradeId =>
      $composableBuilder(column: $table.tradeId, builder: (column) => column);

  GeneratedColumn<String> get reasonTextEncrypted => $composableBuilder(
    column: $table.reasonTextEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get emotionalStateEncrypted => $composableBuilder(
    column: $table.emotionalStateEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get confidenceLevel => $composableBuilder(
    column: $table.confidenceLevel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get tamperHash => $composableBuilder(
    column: $table.tamperHash,
    builder: (column) => column,
  );
}

class $$TradeReasonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TradeReasonsTable,
          TradeReason,
          $$TradeReasonsTableFilterComposer,
          $$TradeReasonsTableOrderingComposer,
          $$TradeReasonsTableAnnotationComposer,
          $$TradeReasonsTableCreateCompanionBuilder,
          $$TradeReasonsTableUpdateCompanionBuilder,
          (
            TradeReason,
            BaseReferences<_$AppDatabase, $TradeReasonsTable, TradeReason>,
          ),
          TradeReason,
          PrefetchHooks Function()
        > {
  $$TradeReasonsTableTableManager(_$AppDatabase db, $TradeReasonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TradeReasonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TradeReasonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TradeReasonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tradeId = const Value.absent(),
                Value<String?> reasonTextEncrypted = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String?> emotionalStateEncrypted = const Value.absent(),
                Value<int?> confidenceLevel = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> tamperHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TradeReasonsCompanion(
                id: id,
                tradeId: tradeId,
                reasonTextEncrypted: reasonTextEncrypted,
                tagsJson: tagsJson,
                emotionalStateEncrypted: emotionalStateEncrypted,
                confidenceLevel: confidenceLevel,
                createdAt: createdAt,
                tamperHash: tamperHash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tradeId,
                Value<String?> reasonTextEncrypted = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String?> emotionalStateEncrypted = const Value.absent(),
                Value<int?> confidenceLevel = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> tamperHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TradeReasonsCompanion.insert(
                id: id,
                tradeId: tradeId,
                reasonTextEncrypted: reasonTextEncrypted,
                tagsJson: tagsJson,
                emotionalStateEncrypted: emotionalStateEncrypted,
                confidenceLevel: confidenceLevel,
                createdAt: createdAt,
                tamperHash: tamperHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TradeReasonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TradeReasonsTable,
      TradeReason,
      $$TradeReasonsTableFilterComposer,
      $$TradeReasonsTableOrderingComposer,
      $$TradeReasonsTableAnnotationComposer,
      $$TradeReasonsTableCreateCompanionBuilder,
      $$TradeReasonsTableUpdateCompanionBuilder,
      (
        TradeReason,
        BaseReferences<_$AppDatabase, $TradeReasonsTable, TradeReason>,
      ),
      TradeReason,
      PrefetchHooks Function()
    >;
typedef $$HoldingsTableCreateCompanionBuilder =
    HoldingsCompanion Function({
      required String instrumentSymbol,
      required String instrumentName,
      required double totalQuantity,
      required double averagePrice,
      required double investedValue,
      Value<DateTime> lastUpdated,
      Value<int> rowid,
    });
typedef $$HoldingsTableUpdateCompanionBuilder =
    HoldingsCompanion Function({
      Value<String> instrumentSymbol,
      Value<String> instrumentName,
      Value<double> totalQuantity,
      Value<double> averagePrice,
      Value<double> investedValue,
      Value<DateTime> lastUpdated,
      Value<int> rowid,
    });

class $$HoldingsTableFilterComposer
    extends Composer<_$AppDatabase, $HoldingsTable> {
  $$HoldingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get instrumentSymbol => $composableBuilder(
    column: $table.instrumentSymbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instrumentName => $composableBuilder(
    column: $table.instrumentName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalQuantity => $composableBuilder(
    column: $table.totalQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get averagePrice => $composableBuilder(
    column: $table.averagePrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get investedValue => $composableBuilder(
    column: $table.investedValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HoldingsTableOrderingComposer
    extends Composer<_$AppDatabase, $HoldingsTable> {
  $$HoldingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get instrumentSymbol => $composableBuilder(
    column: $table.instrumentSymbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentName => $composableBuilder(
    column: $table.instrumentName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalQuantity => $composableBuilder(
    column: $table.totalQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get averagePrice => $composableBuilder(
    column: $table.averagePrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get investedValue => $composableBuilder(
    column: $table.investedValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HoldingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HoldingsTable> {
  $$HoldingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get instrumentSymbol => $composableBuilder(
    column: $table.instrumentSymbol,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instrumentName => $composableBuilder(
    column: $table.instrumentName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalQuantity => $composableBuilder(
    column: $table.totalQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<double> get averagePrice => $composableBuilder(
    column: $table.averagePrice,
    builder: (column) => column,
  );

  GeneratedColumn<double> get investedValue => $composableBuilder(
    column: $table.investedValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$HoldingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HoldingsTable,
          Holding,
          $$HoldingsTableFilterComposer,
          $$HoldingsTableOrderingComposer,
          $$HoldingsTableAnnotationComposer,
          $$HoldingsTableCreateCompanionBuilder,
          $$HoldingsTableUpdateCompanionBuilder,
          (Holding, BaseReferences<_$AppDatabase, $HoldingsTable, Holding>),
          Holding,
          PrefetchHooks Function()
        > {
  $$HoldingsTableTableManager(_$AppDatabase db, $HoldingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoldingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoldingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HoldingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> instrumentSymbol = const Value.absent(),
                Value<String> instrumentName = const Value.absent(),
                Value<double> totalQuantity = const Value.absent(),
                Value<double> averagePrice = const Value.absent(),
                Value<double> investedValue = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HoldingsCompanion(
                instrumentSymbol: instrumentSymbol,
                instrumentName: instrumentName,
                totalQuantity: totalQuantity,
                averagePrice: averagePrice,
                investedValue: investedValue,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String instrumentSymbol,
                required String instrumentName,
                required double totalQuantity,
                required double averagePrice,
                required double investedValue,
                Value<DateTime> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HoldingsCompanion.insert(
                instrumentSymbol: instrumentSymbol,
                instrumentName: instrumentName,
                totalQuantity: totalQuantity,
                averagePrice: averagePrice,
                investedValue: investedValue,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HoldingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HoldingsTable,
      Holding,
      $$HoldingsTableFilterComposer,
      $$HoldingsTableOrderingComposer,
      $$HoldingsTableAnnotationComposer,
      $$HoldingsTableCreateCompanionBuilder,
      $$HoldingsTableUpdateCompanionBuilder,
      (Holding, BaseReferences<_$AppDatabase, $HoldingsTable, Holding>),
      Holding,
      PrefetchHooks Function()
    >;
typedef $$PriceHistoryTableCreateCompanionBuilder =
    PriceHistoryCompanion Function({
      required String id,
      required String instrumentSymbol,
      required double price,
      required DateTime timestamp,
      required PriceSource source,
      Value<int> rowid,
    });
typedef $$PriceHistoryTableUpdateCompanionBuilder =
    PriceHistoryCompanion Function({
      Value<String> id,
      Value<String> instrumentSymbol,
      Value<double> price,
      Value<DateTime> timestamp,
      Value<PriceSource> source,
      Value<int> rowid,
    });

class $$PriceHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $PriceHistoryTable> {
  $$PriceHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instrumentSymbol => $composableBuilder(
    column: $table.instrumentSymbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PriceSource, PriceSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$PriceHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $PriceHistoryTable> {
  $$PriceHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentSymbol => $composableBuilder(
    column: $table.instrumentSymbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PriceHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $PriceHistoryTable> {
  $$PriceHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get instrumentSymbol => $composableBuilder(
    column: $table.instrumentSymbol,
    builder: (column) => column,
  );

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PriceSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$PriceHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PriceHistoryTable,
          PriceHistoryData,
          $$PriceHistoryTableFilterComposer,
          $$PriceHistoryTableOrderingComposer,
          $$PriceHistoryTableAnnotationComposer,
          $$PriceHistoryTableCreateCompanionBuilder,
          $$PriceHistoryTableUpdateCompanionBuilder,
          (
            PriceHistoryData,
            BaseReferences<_$AppDatabase, $PriceHistoryTable, PriceHistoryData>,
          ),
          PriceHistoryData,
          PrefetchHooks Function()
        > {
  $$PriceHistoryTableTableManager(_$AppDatabase db, $PriceHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PriceHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PriceHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PriceHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> instrumentSymbol = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<PriceSource> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PriceHistoryCompanion(
                id: id,
                instrumentSymbol: instrumentSymbol,
                price: price,
                timestamp: timestamp,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String instrumentSymbol,
                required double price,
                required DateTime timestamp,
                required PriceSource source,
                Value<int> rowid = const Value.absent(),
              }) => PriceHistoryCompanion.insert(
                id: id,
                instrumentSymbol: instrumentSymbol,
                price: price,
                timestamp: timestamp,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PriceHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PriceHistoryTable,
      PriceHistoryData,
      $$PriceHistoryTableFilterComposer,
      $$PriceHistoryTableOrderingComposer,
      $$PriceHistoryTableAnnotationComposer,
      $$PriceHistoryTableCreateCompanionBuilder,
      $$PriceHistoryTableUpdateCompanionBuilder,
      (
        PriceHistoryData,
        BaseReferences<_$AppDatabase, $PriceHistoryTable, PriceHistoryData>,
      ),
      PriceHistoryData,
      PrefetchHooks Function()
    >;
typedef $$PortfolioSnapshotsTableCreateCompanionBuilder =
    PortfolioSnapshotsCompanion Function({
      required String id,
      required String snapshotDate,
      required double totalInvested,
      required double currentValue,
      required double unrealizedPnl,
      required double realizedPnl,
      Value<double> confidenceScore,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$PortfolioSnapshotsTableUpdateCompanionBuilder =
    PortfolioSnapshotsCompanion Function({
      Value<String> id,
      Value<String> snapshotDate,
      Value<double> totalInvested,
      Value<double> currentValue,
      Value<double> unrealizedPnl,
      Value<double> realizedPnl,
      Value<double> confidenceScore,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PortfolioSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $PortfolioSnapshotsTable> {
  $$PortfolioSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalInvested => $composableBuilder(
    column: $table.totalInvested,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unrealizedPnl => $composableBuilder(
    column: $table.unrealizedPnl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get realizedPnl => $composableBuilder(
    column: $table.realizedPnl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PortfolioSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $PortfolioSnapshotsTable> {
  $$PortfolioSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalInvested => $composableBuilder(
    column: $table.totalInvested,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unrealizedPnl => $composableBuilder(
    column: $table.unrealizedPnl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get realizedPnl => $composableBuilder(
    column: $table.realizedPnl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PortfolioSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PortfolioSnapshotsTable> {
  $$PortfolioSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalInvested => $composableBuilder(
    column: $table.totalInvested,
    builder: (column) => column,
  );

  GeneratedColumn<double> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get unrealizedPnl => $composableBuilder(
    column: $table.unrealizedPnl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get realizedPnl => $composableBuilder(
    column: $table.realizedPnl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidenceScore => $composableBuilder(
    column: $table.confidenceScore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PortfolioSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PortfolioSnapshotsTable,
          PortfolioSnapshot,
          $$PortfolioSnapshotsTableFilterComposer,
          $$PortfolioSnapshotsTableOrderingComposer,
          $$PortfolioSnapshotsTableAnnotationComposer,
          $$PortfolioSnapshotsTableCreateCompanionBuilder,
          $$PortfolioSnapshotsTableUpdateCompanionBuilder,
          (
            PortfolioSnapshot,
            BaseReferences<
              _$AppDatabase,
              $PortfolioSnapshotsTable,
              PortfolioSnapshot
            >,
          ),
          PortfolioSnapshot,
          PrefetchHooks Function()
        > {
  $$PortfolioSnapshotsTableTableManager(
    _$AppDatabase db,
    $PortfolioSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortfolioSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortfolioSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PortfolioSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> snapshotDate = const Value.absent(),
                Value<double> totalInvested = const Value.absent(),
                Value<double> currentValue = const Value.absent(),
                Value<double> unrealizedPnl = const Value.absent(),
                Value<double> realizedPnl = const Value.absent(),
                Value<double> confidenceScore = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PortfolioSnapshotsCompanion(
                id: id,
                snapshotDate: snapshotDate,
                totalInvested: totalInvested,
                currentValue: currentValue,
                unrealizedPnl: unrealizedPnl,
                realizedPnl: realizedPnl,
                confidenceScore: confidenceScore,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String snapshotDate,
                required double totalInvested,
                required double currentValue,
                required double unrealizedPnl,
                required double realizedPnl,
                Value<double> confidenceScore = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PortfolioSnapshotsCompanion.insert(
                id: id,
                snapshotDate: snapshotDate,
                totalInvested: totalInvested,
                currentValue: currentValue,
                unrealizedPnl: unrealizedPnl,
                realizedPnl: realizedPnl,
                confidenceScore: confidenceScore,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PortfolioSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PortfolioSnapshotsTable,
      PortfolioSnapshot,
      $$PortfolioSnapshotsTableFilterComposer,
      $$PortfolioSnapshotsTableOrderingComposer,
      $$PortfolioSnapshotsTableAnnotationComposer,
      $$PortfolioSnapshotsTableCreateCompanionBuilder,
      $$PortfolioSnapshotsTableUpdateCompanionBuilder,
      (
        PortfolioSnapshot,
        BaseReferences<
          _$AppDatabase,
          $PortfolioSnapshotsTable,
          PortfolioSnapshot
        >,
      ),
      PortfolioSnapshot,
      PrefetchHooks Function()
    >;
typedef $$AlertsTableCreateCompanionBuilder =
    AlertsCompanion Function({
      required String id,
      required String alertType,
      required AlertSeverity severity,
      required String title,
      required String description,
      Value<int> confidence,
      Value<String?> relatedInstrument,
      Value<String> triggerData,
      Value<DateTime> createdAt,
      Value<DateTime?> dismissedAt,
      Value<DateTime?> snoozedUntil,
      Value<String?> importId,
      Value<String?> tamperHash,
      Value<int> rowid,
    });
typedef $$AlertsTableUpdateCompanionBuilder =
    AlertsCompanion Function({
      Value<String> id,
      Value<String> alertType,
      Value<AlertSeverity> severity,
      Value<String> title,
      Value<String> description,
      Value<int> confidence,
      Value<String?> relatedInstrument,
      Value<String> triggerData,
      Value<DateTime> createdAt,
      Value<DateTime?> dismissedAt,
      Value<DateTime?> snoozedUntil,
      Value<String?> importId,
      Value<String?> tamperHash,
      Value<int> rowid,
    });

class $$AlertsTableFilterComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alertType => $composableBuilder(
    column: $table.alertType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AlertSeverity, AlertSeverity, int>
  get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relatedInstrument => $composableBuilder(
    column: $table.relatedInstrument,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerData => $composableBuilder(
    column: $table.triggerData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importId => $composableBuilder(
    column: $table.importId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tamperHash => $composableBuilder(
    column: $table.tamperHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlertsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alertType => $composableBuilder(
    column: $table.alertType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedInstrument => $composableBuilder(
    column: $table.relatedInstrument,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerData => $composableBuilder(
    column: $table.triggerData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importId => $composableBuilder(
    column: $table.importId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tamperHash => $composableBuilder(
    column: $table.tamperHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlertsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get alertType =>
      $composableBuilder(column: $table.alertType, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AlertSeverity, int> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relatedInstrument => $composableBuilder(
    column: $table.relatedInstrument,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triggerData => $composableBuilder(
    column: $table.triggerData,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importId =>
      $composableBuilder(column: $table.importId, builder: (column) => column);

  GeneratedColumn<String> get tamperHash => $composableBuilder(
    column: $table.tamperHash,
    builder: (column) => column,
  );
}

class $$AlertsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlertsTable,
          Alert,
          $$AlertsTableFilterComposer,
          $$AlertsTableOrderingComposer,
          $$AlertsTableAnnotationComposer,
          $$AlertsTableCreateCompanionBuilder,
          $$AlertsTableUpdateCompanionBuilder,
          (Alert, BaseReferences<_$AppDatabase, $AlertsTable, Alert>),
          Alert,
          PrefetchHooks Function()
        > {
  $$AlertsTableTableManager(_$AppDatabase db, $AlertsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlertsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlertsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlertsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> alertType = const Value.absent(),
                Value<AlertSeverity> severity = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> confidence = const Value.absent(),
                Value<String?> relatedInstrument = const Value.absent(),
                Value<String> triggerData = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> dismissedAt = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<String?> importId = const Value.absent(),
                Value<String?> tamperHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlertsCompanion(
                id: id,
                alertType: alertType,
                severity: severity,
                title: title,
                description: description,
                confidence: confidence,
                relatedInstrument: relatedInstrument,
                triggerData: triggerData,
                createdAt: createdAt,
                dismissedAt: dismissedAt,
                snoozedUntil: snoozedUntil,
                importId: importId,
                tamperHash: tamperHash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String alertType,
                required AlertSeverity severity,
                required String title,
                required String description,
                Value<int> confidence = const Value.absent(),
                Value<String?> relatedInstrument = const Value.absent(),
                Value<String> triggerData = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> dismissedAt = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<String?> importId = const Value.absent(),
                Value<String?> tamperHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlertsCompanion.insert(
                id: id,
                alertType: alertType,
                severity: severity,
                title: title,
                description: description,
                confidence: confidence,
                relatedInstrument: relatedInstrument,
                triggerData: triggerData,
                createdAt: createdAt,
                dismissedAt: dismissedAt,
                snoozedUntil: snoozedUntil,
                importId: importId,
                tamperHash: tamperHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlertsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlertsTable,
      Alert,
      $$AlertsTableFilterComposer,
      $$AlertsTableOrderingComposer,
      $$AlertsTableAnnotationComposer,
      $$AlertsTableCreateCompanionBuilder,
      $$AlertsTableUpdateCompanionBuilder,
      (Alert, BaseReferences<_$AppDatabase, $AlertsTable, Alert>),
      Alert,
      PrefetchHooks Function()
    >;
typedef $$BehaviorMetricsTableCreateCompanionBuilder =
    BehaviorMetricsCompanion Function({
      required String id,
      required BehaviorMetricType metricType,
      required double value,
      required String timeWindowStart,
      required String timeWindowEnd,
      Value<int> confidence,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$BehaviorMetricsTableUpdateCompanionBuilder =
    BehaviorMetricsCompanion Function({
      Value<String> id,
      Value<BehaviorMetricType> metricType,
      Value<double> value,
      Value<String> timeWindowStart,
      Value<String> timeWindowEnd,
      Value<int> confidence,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$BehaviorMetricsTableFilterComposer
    extends Composer<_$AppDatabase, $BehaviorMetricsTable> {
  $$BehaviorMetricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BehaviorMetricType, BehaviorMetricType, int>
  get metricType => $composableBuilder(
    column: $table.metricType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeWindowStart => $composableBuilder(
    column: $table.timeWindowStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeWindowEnd => $composableBuilder(
    column: $table.timeWindowEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BehaviorMetricsTableOrderingComposer
    extends Composer<_$AppDatabase, $BehaviorMetricsTable> {
  $$BehaviorMetricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get metricType => $composableBuilder(
    column: $table.metricType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeWindowStart => $composableBuilder(
    column: $table.timeWindowStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeWindowEnd => $composableBuilder(
    column: $table.timeWindowEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BehaviorMetricsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BehaviorMetricsTable> {
  $$BehaviorMetricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BehaviorMetricType, int> get metricType =>
      $composableBuilder(
        column: $table.metricType,
        builder: (column) => column,
      );

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get timeWindowStart => $composableBuilder(
    column: $table.timeWindowStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeWindowEnd => $composableBuilder(
    column: $table.timeWindowEnd,
    builder: (column) => column,
  );

  GeneratedColumn<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BehaviorMetricsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BehaviorMetricsTable,
          BehaviorMetric,
          $$BehaviorMetricsTableFilterComposer,
          $$BehaviorMetricsTableOrderingComposer,
          $$BehaviorMetricsTableAnnotationComposer,
          $$BehaviorMetricsTableCreateCompanionBuilder,
          $$BehaviorMetricsTableUpdateCompanionBuilder,
          (
            BehaviorMetric,
            BaseReferences<
              _$AppDatabase,
              $BehaviorMetricsTable,
              BehaviorMetric
            >,
          ),
          BehaviorMetric,
          PrefetchHooks Function()
        > {
  $$BehaviorMetricsTableTableManager(
    _$AppDatabase db,
    $BehaviorMetricsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BehaviorMetricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BehaviorMetricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BehaviorMetricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<BehaviorMetricType> metricType = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<String> timeWindowStart = const Value.absent(),
                Value<String> timeWindowEnd = const Value.absent(),
                Value<int> confidence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BehaviorMetricsCompanion(
                id: id,
                metricType: metricType,
                value: value,
                timeWindowStart: timeWindowStart,
                timeWindowEnd: timeWindowEnd,
                confidence: confidence,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required BehaviorMetricType metricType,
                required double value,
                required String timeWindowStart,
                required String timeWindowEnd,
                Value<int> confidence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BehaviorMetricsCompanion.insert(
                id: id,
                metricType: metricType,
                value: value,
                timeWindowStart: timeWindowStart,
                timeWindowEnd: timeWindowEnd,
                confidence: confidence,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BehaviorMetricsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BehaviorMetricsTable,
      BehaviorMetric,
      $$BehaviorMetricsTableFilterComposer,
      $$BehaviorMetricsTableOrderingComposer,
      $$BehaviorMetricsTableAnnotationComposer,
      $$BehaviorMetricsTableCreateCompanionBuilder,
      $$BehaviorMetricsTableUpdateCompanionBuilder,
      (
        BehaviorMetric,
        BaseReferences<_$AppDatabase, $BehaviorMetricsTable, BehaviorMetric>,
      ),
      BehaviorMetric,
      PrefetchHooks Function()
    >;
typedef $$ConfidenceMeterTableCreateCompanionBuilder =
    ConfidenceMeterCompanion Function({
      required String id,
      required double score,
      required double strategyAdherence,
      required double consistency,
      required double emotionalStability,
      Value<DateTime> calculatedAt,
      Value<int> rowid,
    });
typedef $$ConfidenceMeterTableUpdateCompanionBuilder =
    ConfidenceMeterCompanion Function({
      Value<String> id,
      Value<double> score,
      Value<double> strategyAdherence,
      Value<double> consistency,
      Value<double> emotionalStability,
      Value<DateTime> calculatedAt,
      Value<int> rowid,
    });

class $$ConfidenceMeterTableFilterComposer
    extends Composer<_$AppDatabase, $ConfidenceMeterTable> {
  $$ConfidenceMeterTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get strategyAdherence => $composableBuilder(
    column: $table.strategyAdherence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get consistency => $composableBuilder(
    column: $table.consistency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get emotionalStability => $composableBuilder(
    column: $table.emotionalStability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConfidenceMeterTableOrderingComposer
    extends Composer<_$AppDatabase, $ConfidenceMeterTable> {
  $$ConfidenceMeterTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get strategyAdherence => $composableBuilder(
    column: $table.strategyAdherence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get consistency => $composableBuilder(
    column: $table.consistency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get emotionalStability => $composableBuilder(
    column: $table.emotionalStability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConfidenceMeterTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConfidenceMeterTable> {
  $$ConfidenceMeterTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<double> get strategyAdherence => $composableBuilder(
    column: $table.strategyAdherence,
    builder: (column) => column,
  );

  GeneratedColumn<double> get consistency => $composableBuilder(
    column: $table.consistency,
    builder: (column) => column,
  );

  GeneratedColumn<double> get emotionalStability => $composableBuilder(
    column: $table.emotionalStability,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => column,
  );
}

class $$ConfidenceMeterTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConfidenceMeterTable,
          ConfidenceMeterData,
          $$ConfidenceMeterTableFilterComposer,
          $$ConfidenceMeterTableOrderingComposer,
          $$ConfidenceMeterTableAnnotationComposer,
          $$ConfidenceMeterTableCreateCompanionBuilder,
          $$ConfidenceMeterTableUpdateCompanionBuilder,
          (
            ConfidenceMeterData,
            BaseReferences<
              _$AppDatabase,
              $ConfidenceMeterTable,
              ConfidenceMeterData
            >,
          ),
          ConfidenceMeterData,
          PrefetchHooks Function()
        > {
  $$ConfidenceMeterTableTableManager(
    _$AppDatabase db,
    $ConfidenceMeterTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConfidenceMeterTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConfidenceMeterTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConfidenceMeterTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<double> strategyAdherence = const Value.absent(),
                Value<double> consistency = const Value.absent(),
                Value<double> emotionalStability = const Value.absent(),
                Value<DateTime> calculatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConfidenceMeterCompanion(
                id: id,
                score: score,
                strategyAdherence: strategyAdherence,
                consistency: consistency,
                emotionalStability: emotionalStability,
                calculatedAt: calculatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required double score,
                required double strategyAdherence,
                required double consistency,
                required double emotionalStability,
                Value<DateTime> calculatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConfidenceMeterCompanion.insert(
                id: id,
                score: score,
                strategyAdherence: strategyAdherence,
                consistency: consistency,
                emotionalStability: emotionalStability,
                calculatedAt: calculatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConfidenceMeterTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConfidenceMeterTable,
      ConfidenceMeterData,
      $$ConfidenceMeterTableFilterComposer,
      $$ConfidenceMeterTableOrderingComposer,
      $$ConfidenceMeterTableAnnotationComposer,
      $$ConfidenceMeterTableCreateCompanionBuilder,
      $$ConfidenceMeterTableUpdateCompanionBuilder,
      (
        ConfidenceMeterData,
        BaseReferences<
          _$AppDatabase,
          $ConfidenceMeterTable,
          ConfidenceMeterData
        >,
      ),
      ConfidenceMeterData,
      PrefetchHooks Function()
    >;
typedef $$ImportsTableCreateCompanionBuilder =
    ImportsCompanion Function({
      required String id,
      required ImportType importType,
      required String sourceName,
      Value<int> rowsImported,
      Value<int> successRate,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ImportsTableUpdateCompanionBuilder =
    ImportsCompanion Function({
      Value<String> id,
      Value<ImportType> importType,
      Value<String> sourceName,
      Value<int> rowsImported,
      Value<int> successRate,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ImportsTableFilterComposer
    extends Composer<_$AppDatabase, $ImportsTable> {
  $$ImportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ImportType, ImportType, int> get importType =>
      $composableBuilder(
        column: $table.importType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowsImported => $composableBuilder(
    column: $table.rowsImported,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get successRate => $composableBuilder(
    column: $table.successRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportsTable> {
  $$ImportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importType => $composableBuilder(
    column: $table.importType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowsImported => $composableBuilder(
    column: $table.rowsImported,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get successRate => $composableBuilder(
    column: $table.successRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportsTable> {
  $$ImportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ImportType, int> get importType =>
      $composableBuilder(
        column: $table.importType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowsImported => $composableBuilder(
    column: $table.rowsImported,
    builder: (column) => column,
  );

  GeneratedColumn<int> get successRate => $composableBuilder(
    column: $table.successRate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ImportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportsTable,
          Import,
          $$ImportsTableFilterComposer,
          $$ImportsTableOrderingComposer,
          $$ImportsTableAnnotationComposer,
          $$ImportsTableCreateCompanionBuilder,
          $$ImportsTableUpdateCompanionBuilder,
          (Import, BaseReferences<_$AppDatabase, $ImportsTable, Import>),
          Import,
          PrefetchHooks Function()
        > {
  $$ImportsTableTableManager(_$AppDatabase db, $ImportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<ImportType> importType = const Value.absent(),
                Value<String> sourceName = const Value.absent(),
                Value<int> rowsImported = const Value.absent(),
                Value<int> successRate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportsCompanion(
                id: id,
                importType: importType,
                sourceName: sourceName,
                rowsImported: rowsImported,
                successRate: successRate,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required ImportType importType,
                required String sourceName,
                Value<int> rowsImported = const Value.absent(),
                Value<int> successRate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportsCompanion.insert(
                id: id,
                importType: importType,
                sourceName: sourceName,
                rowsImported: rowsImported,
                successRate: successRate,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportsTable,
      Import,
      $$ImportsTableFilterComposer,
      $$ImportsTableOrderingComposer,
      $$ImportsTableAnnotationComposer,
      $$ImportsTableCreateCompanionBuilder,
      $$ImportsTableUpdateCompanionBuilder,
      (Import, BaseReferences<_$AppDatabase, $ImportsTable, Import>),
      Import,
      PrefetchHooks Function()
    >;
typedef $$IntegrityMetadataTableCreateCompanionBuilder =
    IntegrityMetadataCompanion Function({
      required String chainId,
      required String tailHash,
      Value<int> rowCount,
      Value<DateTime> lastVerifiedAt,
      Value<int> rowid,
    });
typedef $$IntegrityMetadataTableUpdateCompanionBuilder =
    IntegrityMetadataCompanion Function({
      Value<String> chainId,
      Value<String> tailHash,
      Value<int> rowCount,
      Value<DateTime> lastVerifiedAt,
      Value<int> rowid,
    });

class $$IntegrityMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $IntegrityMetadataTable> {
  $$IntegrityMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chainId => $composableBuilder(
    column: $table.chainId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tailHash => $composableBuilder(
    column: $table.tailHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowCount => $composableBuilder(
    column: $table.rowCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IntegrityMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $IntegrityMetadataTable> {
  $$IntegrityMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chainId => $composableBuilder(
    column: $table.chainId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tailHash => $composableBuilder(
    column: $table.tailHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowCount => $composableBuilder(
    column: $table.rowCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IntegrityMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $IntegrityMetadataTable> {
  $$IntegrityMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chainId =>
      $composableBuilder(column: $table.chainId, builder: (column) => column);

  GeneratedColumn<String> get tailHash =>
      $composableBuilder(column: $table.tailHash, builder: (column) => column);

  GeneratedColumn<int> get rowCount =>
      $composableBuilder(column: $table.rowCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => column,
  );
}

class $$IntegrityMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IntegrityMetadataTable,
          IntegrityMetadataData,
          $$IntegrityMetadataTableFilterComposer,
          $$IntegrityMetadataTableOrderingComposer,
          $$IntegrityMetadataTableAnnotationComposer,
          $$IntegrityMetadataTableCreateCompanionBuilder,
          $$IntegrityMetadataTableUpdateCompanionBuilder,
          (
            IntegrityMetadataData,
            BaseReferences<
              _$AppDatabase,
              $IntegrityMetadataTable,
              IntegrityMetadataData
            >,
          ),
          IntegrityMetadataData,
          PrefetchHooks Function()
        > {
  $$IntegrityMetadataTableTableManager(
    _$AppDatabase db,
    $IntegrityMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IntegrityMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IntegrityMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IntegrityMetadataTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> chainId = const Value.absent(),
                Value<String> tailHash = const Value.absent(),
                Value<int> rowCount = const Value.absent(),
                Value<DateTime> lastVerifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IntegrityMetadataCompanion(
                chainId: chainId,
                tailHash: tailHash,
                rowCount: rowCount,
                lastVerifiedAt: lastVerifiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chainId,
                required String tailHash,
                Value<int> rowCount = const Value.absent(),
                Value<DateTime> lastVerifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IntegrityMetadataCompanion.insert(
                chainId: chainId,
                tailHash: tailHash,
                rowCount: rowCount,
                lastVerifiedAt: lastVerifiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IntegrityMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IntegrityMetadataTable,
      IntegrityMetadataData,
      $$IntegrityMetadataTableFilterComposer,
      $$IntegrityMetadataTableOrderingComposer,
      $$IntegrityMetadataTableAnnotationComposer,
      $$IntegrityMetadataTableCreateCompanionBuilder,
      $$IntegrityMetadataTableUpdateCompanionBuilder,
      (
        IntegrityMetadataData,
        BaseReferences<
          _$AppDatabase,
          $IntegrityMetadataTable,
          IntegrityMetadataData
        >,
      ),
      IntegrityMetadataData,
      PrefetchHooks Function()
    >;
typedef $$ColumnMappingsTableCreateCompanionBuilder =
    ColumnMappingsCompanion Function({
      required String id,
      required String sourceName,
      required String mappingJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ColumnMappingsTableUpdateCompanionBuilder =
    ColumnMappingsCompanion Function({
      Value<String> id,
      Value<String> sourceName,
      Value<String> mappingJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ColumnMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $ColumnMappingsTable> {
  $$ColumnMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mappingJson => $composableBuilder(
    column: $table.mappingJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ColumnMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ColumnMappingsTable> {
  $$ColumnMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mappingJson => $composableBuilder(
    column: $table.mappingJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ColumnMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ColumnMappingsTable> {
  $$ColumnMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mappingJson => $composableBuilder(
    column: $table.mappingJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ColumnMappingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ColumnMappingsTable,
          ColumnMapping,
          $$ColumnMappingsTableFilterComposer,
          $$ColumnMappingsTableOrderingComposer,
          $$ColumnMappingsTableAnnotationComposer,
          $$ColumnMappingsTableCreateCompanionBuilder,
          $$ColumnMappingsTableUpdateCompanionBuilder,
          (
            ColumnMapping,
            BaseReferences<_$AppDatabase, $ColumnMappingsTable, ColumnMapping>,
          ),
          ColumnMapping,
          PrefetchHooks Function()
        > {
  $$ColumnMappingsTableTableManager(
    _$AppDatabase db,
    $ColumnMappingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ColumnMappingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ColumnMappingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ColumnMappingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceName = const Value.absent(),
                Value<String> mappingJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ColumnMappingsCompanion(
                id: id,
                sourceName: sourceName,
                mappingJson: mappingJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceName,
                required String mappingJson,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ColumnMappingsCompanion.insert(
                id: id,
                sourceName: sourceName,
                mappingJson: mappingJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ColumnMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ColumnMappingsTable,
      ColumnMapping,
      $$ColumnMappingsTableFilterComposer,
      $$ColumnMappingsTableOrderingComposer,
      $$ColumnMappingsTableAnnotationComposer,
      $$ColumnMappingsTableCreateCompanionBuilder,
      $$ColumnMappingsTableUpdateCompanionBuilder,
      (
        ColumnMapping,
        BaseReferences<_$AppDatabase, $ColumnMappingsTable, ColumnMapping>,
      ),
      ColumnMapping,
      PrefetchHooks Function()
    >;
typedef $$EmailCredentialsTableCreateCompanionBuilder =
    EmailCredentialsCompanion Function({
      required String id,
      required String emailAddress,
      required int authType,
      required String credentialsEncrypted,
      Value<DateTime> createdAt,
      Value<DateTime?> lastUsedAt,
      Value<int> rowid,
    });
typedef $$EmailCredentialsTableUpdateCompanionBuilder =
    EmailCredentialsCompanion Function({
      Value<String> id,
      Value<String> emailAddress,
      Value<int> authType,
      Value<String> credentialsEncrypted,
      Value<DateTime> createdAt,
      Value<DateTime?> lastUsedAt,
      Value<int> rowid,
    });

class $$EmailCredentialsTableFilterComposer
    extends Composer<_$AppDatabase, $EmailCredentialsTable> {
  $$EmailCredentialsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emailAddress => $composableBuilder(
    column: $table.emailAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get authType => $composableBuilder(
    column: $table.authType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialsEncrypted => $composableBuilder(
    column: $table.credentialsEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmailCredentialsTableOrderingComposer
    extends Composer<_$AppDatabase, $EmailCredentialsTable> {
  $$EmailCredentialsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emailAddress => $composableBuilder(
    column: $table.emailAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get authType => $composableBuilder(
    column: $table.authType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialsEncrypted => $composableBuilder(
    column: $table.credentialsEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmailCredentialsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmailCredentialsTable> {
  $$EmailCredentialsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get emailAddress => $composableBuilder(
    column: $table.emailAddress,
    builder: (column) => column,
  );

  GeneratedColumn<int> get authType =>
      $composableBuilder(column: $table.authType, builder: (column) => column);

  GeneratedColumn<String> get credentialsEncrypted => $composableBuilder(
    column: $table.credentialsEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );
}

class $$EmailCredentialsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmailCredentialsTable,
          EmailCredential,
          $$EmailCredentialsTableFilterComposer,
          $$EmailCredentialsTableOrderingComposer,
          $$EmailCredentialsTableAnnotationComposer,
          $$EmailCredentialsTableCreateCompanionBuilder,
          $$EmailCredentialsTableUpdateCompanionBuilder,
          (
            EmailCredential,
            BaseReferences<
              _$AppDatabase,
              $EmailCredentialsTable,
              EmailCredential
            >,
          ),
          EmailCredential,
          PrefetchHooks Function()
        > {
  $$EmailCredentialsTableTableManager(
    _$AppDatabase db,
    $EmailCredentialsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmailCredentialsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmailCredentialsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmailCredentialsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> emailAddress = const Value.absent(),
                Value<int> authType = const Value.absent(),
                Value<String> credentialsEncrypted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmailCredentialsCompanion(
                id: id,
                emailAddress: emailAddress,
                authType: authType,
                credentialsEncrypted: credentialsEncrypted,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String emailAddress,
                required int authType,
                required String credentialsEncrypted,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmailCredentialsCompanion.insert(
                id: id,
                emailAddress: emailAddress,
                authType: authType,
                credentialsEncrypted: credentialsEncrypted,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmailCredentialsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmailCredentialsTable,
      EmailCredential,
      $$EmailCredentialsTableFilterComposer,
      $$EmailCredentialsTableOrderingComposer,
      $$EmailCredentialsTableAnnotationComposer,
      $$EmailCredentialsTableCreateCompanionBuilder,
      $$EmailCredentialsTableUpdateCompanionBuilder,
      (
        EmailCredential,
        BaseReferences<_$AppDatabase, $EmailCredentialsTable, EmailCredential>,
      ),
      EmailCredential,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TradesTableTableManager get trades =>
      $$TradesTableTableManager(_db, _db.trades);
  $$TradeReasonsTableTableManager get tradeReasons =>
      $$TradeReasonsTableTableManager(_db, _db.tradeReasons);
  $$HoldingsTableTableManager get holdings =>
      $$HoldingsTableTableManager(_db, _db.holdings);
  $$PriceHistoryTableTableManager get priceHistory =>
      $$PriceHistoryTableTableManager(_db, _db.priceHistory);
  $$PortfolioSnapshotsTableTableManager get portfolioSnapshots =>
      $$PortfolioSnapshotsTableTableManager(_db, _db.portfolioSnapshots);
  $$AlertsTableTableManager get alerts =>
      $$AlertsTableTableManager(_db, _db.alerts);
  $$BehaviorMetricsTableTableManager get behaviorMetrics =>
      $$BehaviorMetricsTableTableManager(_db, _db.behaviorMetrics);
  $$ConfidenceMeterTableTableManager get confidenceMeter =>
      $$ConfidenceMeterTableTableManager(_db, _db.confidenceMeter);
  $$ImportsTableTableManager get imports =>
      $$ImportsTableTableManager(_db, _db.imports);
  $$IntegrityMetadataTableTableManager get integrityMetadata =>
      $$IntegrityMetadataTableTableManager(_db, _db.integrityMetadata);
  $$ColumnMappingsTableTableManager get columnMappings =>
      $$ColumnMappingsTableTableManager(_db, _db.columnMappings);
  $$EmailCredentialsTableTableManager get emailCredentials =>
      $$EmailCredentialsTableTableManager(_db, _db.emailCredentials);
}
