// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_db.dart';

// ignore_for_file: type=lint
class $CatalogEntriesTable extends CatalogEntries
    with TableInfo<$CatalogEntriesTable, CatalogEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceAssetIdMeta = const VerificationMeta(
    'sourceAssetId',
  );
  @override
  late final GeneratedColumn<String> sourceAssetId = GeneratedColumn<String>(
    'source_asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _flagMeta = const VerificationMeta('flag');
  @override
  late final GeneratedColumn<bool> flag = GeneratedColumn<bool>(
    'flag',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("flag" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  @override
  late final GeneratedColumn<DateTime> created = GeneratedColumn<DateTime>(
    'created',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipeJsonMeta = const VerificationMeta(
    'recipeJson',
  );
  @override
  late final GeneratedColumn<String> recipeJson = GeneratedColumn<String>(
    'recipe_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    sourceAssetId,
    kind,
    label,
    rating,
    flag,
    created,
    recipeJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('source_asset_id')) {
      context.handle(
        _sourceAssetIdMeta,
        sourceAssetId.isAcceptableOrUnknown(
          data['source_asset_id']!,
          _sourceAssetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceAssetIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('flag')) {
      context.handle(
        _flagMeta,
        flag.isAcceptableOrUnknown(data['flag']!, _flagMeta),
      );
    }
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    } else if (isInserting) {
      context.missing(_createdMeta);
    }
    if (data.containsKey('recipe_json')) {
      context.handle(
        _recipeJsonMeta,
        recipeJson.isAcceptableOrUnknown(data['recipe_json']!, _recipeJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId};
  @override
  CatalogEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogEntryRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      sourceAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_asset_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      )!,
      flag: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}flag'],
      )!,
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created'],
      )!,
      recipeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_json'],
      )!,
    );
  }

  @override
  $CatalogEntriesTable createAlias(String alias) {
    return $CatalogEntriesTable(attachedDatabase, alias);
  }
}

class CatalogEntryRow extends DataClass implements Insertable<CatalogEntryRow> {
  final String entryId;
  final String sourceAssetId;
  final int kind;
  final String? label;
  final int rating;
  final bool flag;
  final DateTime created;
  final String recipeJson;
  const CatalogEntryRow({
    required this.entryId,
    required this.sourceAssetId,
    required this.kind,
    this.label,
    required this.rating,
    required this.flag,
    required this.created,
    required this.recipeJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['source_asset_id'] = Variable<String>(sourceAssetId);
    map['kind'] = Variable<int>(kind);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['rating'] = Variable<int>(rating);
    map['flag'] = Variable<bool>(flag);
    map['created'] = Variable<DateTime>(created);
    map['recipe_json'] = Variable<String>(recipeJson);
    return map;
  }

  CatalogEntriesCompanion toCompanion(bool nullToAbsent) {
    return CatalogEntriesCompanion(
      entryId: Value(entryId),
      sourceAssetId: Value(sourceAssetId),
      kind: Value(kind),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      rating: Value(rating),
      flag: Value(flag),
      created: Value(created),
      recipeJson: Value(recipeJson),
    );
  }

  factory CatalogEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogEntryRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      sourceAssetId: serializer.fromJson<String>(json['sourceAssetId']),
      kind: serializer.fromJson<int>(json['kind']),
      label: serializer.fromJson<String?>(json['label']),
      rating: serializer.fromJson<int>(json['rating']),
      flag: serializer.fromJson<bool>(json['flag']),
      created: serializer.fromJson<DateTime>(json['created']),
      recipeJson: serializer.fromJson<String>(json['recipeJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'sourceAssetId': serializer.toJson<String>(sourceAssetId),
      'kind': serializer.toJson<int>(kind),
      'label': serializer.toJson<String?>(label),
      'rating': serializer.toJson<int>(rating),
      'flag': serializer.toJson<bool>(flag),
      'created': serializer.toJson<DateTime>(created),
      'recipeJson': serializer.toJson<String>(recipeJson),
    };
  }

  CatalogEntryRow copyWith({
    String? entryId,
    String? sourceAssetId,
    int? kind,
    Value<String?> label = const Value.absent(),
    int? rating,
    bool? flag,
    DateTime? created,
    String? recipeJson,
  }) => CatalogEntryRow(
    entryId: entryId ?? this.entryId,
    sourceAssetId: sourceAssetId ?? this.sourceAssetId,
    kind: kind ?? this.kind,
    label: label.present ? label.value : this.label,
    rating: rating ?? this.rating,
    flag: flag ?? this.flag,
    created: created ?? this.created,
    recipeJson: recipeJson ?? this.recipeJson,
  );
  CatalogEntryRow copyWithCompanion(CatalogEntriesCompanion data) {
    return CatalogEntryRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      sourceAssetId: data.sourceAssetId.present
          ? data.sourceAssetId.value
          : this.sourceAssetId,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
      rating: data.rating.present ? data.rating.value : this.rating,
      flag: data.flag.present ? data.flag.value : this.flag,
      created: data.created.present ? data.created.value : this.created,
      recipeJson: data.recipeJson.present
          ? data.recipeJson.value
          : this.recipeJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogEntryRow(')
          ..write('entryId: $entryId, ')
          ..write('sourceAssetId: $sourceAssetId, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('rating: $rating, ')
          ..write('flag: $flag, ')
          ..write('created: $created, ')
          ..write('recipeJson: $recipeJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entryId,
    sourceAssetId,
    kind,
    label,
    rating,
    flag,
    created,
    recipeJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogEntryRow &&
          other.entryId == this.entryId &&
          other.sourceAssetId == this.sourceAssetId &&
          other.kind == this.kind &&
          other.label == this.label &&
          other.rating == this.rating &&
          other.flag == this.flag &&
          other.created == this.created &&
          other.recipeJson == this.recipeJson);
}

class CatalogEntriesCompanion extends UpdateCompanion<CatalogEntryRow> {
  final Value<String> entryId;
  final Value<String> sourceAssetId;
  final Value<int> kind;
  final Value<String?> label;
  final Value<int> rating;
  final Value<bool> flag;
  final Value<DateTime> created;
  final Value<String> recipeJson;
  final Value<int> rowid;
  const CatalogEntriesCompanion({
    this.entryId = const Value.absent(),
    this.sourceAssetId = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.rating = const Value.absent(),
    this.flag = const Value.absent(),
    this.created = const Value.absent(),
    this.recipeJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogEntriesCompanion.insert({
    required String entryId,
    required String sourceAssetId,
    required int kind,
    this.label = const Value.absent(),
    this.rating = const Value.absent(),
    this.flag = const Value.absent(),
    required DateTime created,
    required String recipeJson,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       sourceAssetId = Value(sourceAssetId),
       kind = Value(kind),
       created = Value(created),
       recipeJson = Value(recipeJson);
  static Insertable<CatalogEntryRow> custom({
    Expression<String>? entryId,
    Expression<String>? sourceAssetId,
    Expression<int>? kind,
    Expression<String>? label,
    Expression<int>? rating,
    Expression<bool>? flag,
    Expression<DateTime>? created,
    Expression<String>? recipeJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (sourceAssetId != null) 'source_asset_id': sourceAssetId,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
      if (rating != null) 'rating': rating,
      if (flag != null) 'flag': flag,
      if (created != null) 'created': created,
      if (recipeJson != null) 'recipe_json': recipeJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogEntriesCompanion copyWith({
    Value<String>? entryId,
    Value<String>? sourceAssetId,
    Value<int>? kind,
    Value<String?>? label,
    Value<int>? rating,
    Value<bool>? flag,
    Value<DateTime>? created,
    Value<String>? recipeJson,
    Value<int>? rowid,
  }) {
    return CatalogEntriesCompanion(
      entryId: entryId ?? this.entryId,
      sourceAssetId: sourceAssetId ?? this.sourceAssetId,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      rating: rating ?? this.rating,
      flag: flag ?? this.flag,
      created: created ?? this.created,
      recipeJson: recipeJson ?? this.recipeJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (sourceAssetId.present) {
      map['source_asset_id'] = Variable<String>(sourceAssetId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (flag.present) {
      map['flag'] = Variable<bool>(flag.value);
    }
    if (created.present) {
      map['created'] = Variable<DateTime>(created.value);
    }
    if (recipeJson.present) {
      map['recipe_json'] = Variable<String>(recipeJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogEntriesCompanion(')
          ..write('entryId: $entryId, ')
          ..write('sourceAssetId: $sourceAssetId, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('rating: $rating, ')
          ..write('flag: $flag, ')
          ..write('created: $created, ')
          ..write('recipeJson: $recipeJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EditPreviewsTable extends EditPreviews
    with TableInfo<$EditPreviewsTable, EditPreviewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EditPreviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipeHashMeta = const VerificationMeta(
    'recipeHash',
  );
  @override
  late final GeneratedColumn<String> recipeHash = GeneratedColumn<String>(
    'recipe_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  @override
  late final GeneratedColumn<DateTime> created = GeneratedColumn<DateTime>(
    'created',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    path,
    width,
    height,
    recipeHash,
    created,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'edit_previews';
  @override
  VerificationContext validateIntegrity(
    Insertable<EditPreviewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('recipe_hash')) {
      context.handle(
        _recipeHashMeta,
        recipeHash.isAcceptableOrUnknown(data['recipe_hash']!, _recipeHashMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeHashMeta);
    }
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    } else if (isInserting) {
      context.missing(_createdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId};
  @override
  EditPreviewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EditPreviewRow(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      recipeHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_hash'],
      )!,
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created'],
      )!,
    );
  }

  @override
  $EditPreviewsTable createAlias(String alias) {
    return $EditPreviewsTable(attachedDatabase, alias);
  }
}

class EditPreviewRow extends DataClass implements Insertable<EditPreviewRow> {
  final String entryId;
  final String path;
  final int width;
  final int height;
  final String recipeHash;
  final DateTime created;
  const EditPreviewRow({
    required this.entryId,
    required this.path,
    required this.width,
    required this.height,
    required this.recipeHash,
    required this.created,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['path'] = Variable<String>(path);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['recipe_hash'] = Variable<String>(recipeHash);
    map['created'] = Variable<DateTime>(created);
    return map;
  }

  EditPreviewsCompanion toCompanion(bool nullToAbsent) {
    return EditPreviewsCompanion(
      entryId: Value(entryId),
      path: Value(path),
      width: Value(width),
      height: Value(height),
      recipeHash: Value(recipeHash),
      created: Value(created),
    );
  }

  factory EditPreviewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EditPreviewRow(
      entryId: serializer.fromJson<String>(json['entryId']),
      path: serializer.fromJson<String>(json['path']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      recipeHash: serializer.fromJson<String>(json['recipeHash']),
      created: serializer.fromJson<DateTime>(json['created']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'path': serializer.toJson<String>(path),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'recipeHash': serializer.toJson<String>(recipeHash),
      'created': serializer.toJson<DateTime>(created),
    };
  }

  EditPreviewRow copyWith({
    String? entryId,
    String? path,
    int? width,
    int? height,
    String? recipeHash,
    DateTime? created,
  }) => EditPreviewRow(
    entryId: entryId ?? this.entryId,
    path: path ?? this.path,
    width: width ?? this.width,
    height: height ?? this.height,
    recipeHash: recipeHash ?? this.recipeHash,
    created: created ?? this.created,
  );
  EditPreviewRow copyWithCompanion(EditPreviewsCompanion data) {
    return EditPreviewRow(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      path: data.path.present ? data.path.value : this.path,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      recipeHash: data.recipeHash.present
          ? data.recipeHash.value
          : this.recipeHash,
      created: data.created.present ? data.created.value : this.created,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EditPreviewRow(')
          ..write('entryId: $entryId, ')
          ..write('path: $path, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('recipeHash: $recipeHash, ')
          ..write('created: $created')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(entryId, path, width, height, recipeHash, created);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EditPreviewRow &&
          other.entryId == this.entryId &&
          other.path == this.path &&
          other.width == this.width &&
          other.height == this.height &&
          other.recipeHash == this.recipeHash &&
          other.created == this.created);
}

class EditPreviewsCompanion extends UpdateCompanion<EditPreviewRow> {
  final Value<String> entryId;
  final Value<String> path;
  final Value<int> width;
  final Value<int> height;
  final Value<String> recipeHash;
  final Value<DateTime> created;
  final Value<int> rowid;
  const EditPreviewsCompanion({
    this.entryId = const Value.absent(),
    this.path = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.recipeHash = const Value.absent(),
    this.created = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EditPreviewsCompanion.insert({
    required String entryId,
    required String path,
    required int width,
    required int height,
    required String recipeHash,
    required DateTime created,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       path = Value(path),
       width = Value(width),
       height = Value(height),
       recipeHash = Value(recipeHash),
       created = Value(created);
  static Insertable<EditPreviewRow> custom({
    Expression<String>? entryId,
    Expression<String>? path,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? recipeHash,
    Expression<DateTime>? created,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (path != null) 'path': path,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (recipeHash != null) 'recipe_hash': recipeHash,
      if (created != null) 'created': created,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EditPreviewsCompanion copyWith({
    Value<String>? entryId,
    Value<String>? path,
    Value<int>? width,
    Value<int>? height,
    Value<String>? recipeHash,
    Value<DateTime>? created,
    Value<int>? rowid,
  }) {
    return EditPreviewsCompanion(
      entryId: entryId ?? this.entryId,
      path: path ?? this.path,
      width: width ?? this.width,
      height: height ?? this.height,
      recipeHash: recipeHash ?? this.recipeHash,
      created: created ?? this.created,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (recipeHash.present) {
      map['recipe_hash'] = Variable<String>(recipeHash.value);
    }
    if (created.present) {
      map['created'] = Variable<DateTime>(created.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EditPreviewsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('path: $path, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('recipeHash: $recipeHash, ')
          ..write('created: $created, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CatalogDb extends GeneratedDatabase {
  _$CatalogDb(QueryExecutor e) : super(e);
  $CatalogDbManager get managers => $CatalogDbManager(this);
  late final $CatalogEntriesTable catalogEntries = $CatalogEntriesTable(this);
  late final $EditPreviewsTable editPreviews = $EditPreviewsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    catalogEntries,
    editPreviews,
  ];
}

typedef $$CatalogEntriesTableCreateCompanionBuilder =
    CatalogEntriesCompanion Function({
      required String entryId,
      required String sourceAssetId,
      required int kind,
      Value<String?> label,
      Value<int> rating,
      Value<bool> flag,
      required DateTime created,
      required String recipeJson,
      Value<int> rowid,
    });
typedef $$CatalogEntriesTableUpdateCompanionBuilder =
    CatalogEntriesCompanion Function({
      Value<String> entryId,
      Value<String> sourceAssetId,
      Value<int> kind,
      Value<String?> label,
      Value<int> rating,
      Value<bool> flag,
      Value<DateTime> created,
      Value<String> recipeJson,
      Value<int> rowid,
    });

class $$CatalogEntriesTableFilterComposer
    extends Composer<_$CatalogDb, $CatalogEntriesTable> {
  $$CatalogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceAssetId => $composableBuilder(
    column: $table.sourceAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get flag => $composableBuilder(
    column: $table.flag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipeJson => $composableBuilder(
    column: $table.recipeJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogEntriesTableOrderingComposer
    extends Composer<_$CatalogDb, $CatalogEntriesTable> {
  $$CatalogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceAssetId => $composableBuilder(
    column: $table.sourceAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get flag => $composableBuilder(
    column: $table.flag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipeJson => $composableBuilder(
    column: $table.recipeJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogEntriesTableAnnotationComposer
    extends Composer<_$CatalogDb, $CatalogEntriesTable> {
  $$CatalogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get sourceAssetId => $composableBuilder(
    column: $table.sourceAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<bool> get flag =>
      $composableBuilder(column: $table.flag, builder: (column) => column);

  GeneratedColumn<DateTime> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<String> get recipeJson => $composableBuilder(
    column: $table.recipeJson,
    builder: (column) => column,
  );
}

class $$CatalogEntriesTableTableManager
    extends
        RootTableManager<
          _$CatalogDb,
          $CatalogEntriesTable,
          CatalogEntryRow,
          $$CatalogEntriesTableFilterComposer,
          $$CatalogEntriesTableOrderingComposer,
          $$CatalogEntriesTableAnnotationComposer,
          $$CatalogEntriesTableCreateCompanionBuilder,
          $$CatalogEntriesTableUpdateCompanionBuilder,
          (
            CatalogEntryRow,
            BaseReferences<_$CatalogDb, $CatalogEntriesTable, CatalogEntryRow>,
          ),
          CatalogEntryRow,
          PrefetchHooks Function()
        > {
  $$CatalogEntriesTableTableManager(_$CatalogDb db, $CatalogEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> sourceAssetId = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<int> rating = const Value.absent(),
                Value<bool> flag = const Value.absent(),
                Value<DateTime> created = const Value.absent(),
                Value<String> recipeJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogEntriesCompanion(
                entryId: entryId,
                sourceAssetId: sourceAssetId,
                kind: kind,
                label: label,
                rating: rating,
                flag: flag,
                created: created,
                recipeJson: recipeJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String sourceAssetId,
                required int kind,
                Value<String?> label = const Value.absent(),
                Value<int> rating = const Value.absent(),
                Value<bool> flag = const Value.absent(),
                required DateTime created,
                required String recipeJson,
                Value<int> rowid = const Value.absent(),
              }) => CatalogEntriesCompanion.insert(
                entryId: entryId,
                sourceAssetId: sourceAssetId,
                kind: kind,
                label: label,
                rating: rating,
                flag: flag,
                created: created,
                recipeJson: recipeJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogEntriesTable, CatalogEntryRow>(table),
                  BaseReferences<
                    _$CatalogDb,
                    $CatalogEntriesTable,
                    CatalogEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDb,
      $CatalogEntriesTable,
      CatalogEntryRow,
      $$CatalogEntriesTableFilterComposer,
      $$CatalogEntriesTableOrderingComposer,
      $$CatalogEntriesTableAnnotationComposer,
      $$CatalogEntriesTableCreateCompanionBuilder,
      $$CatalogEntriesTableUpdateCompanionBuilder,
      (
        CatalogEntryRow,
        BaseReferences<_$CatalogDb, $CatalogEntriesTable, CatalogEntryRow>,
      ),
      CatalogEntryRow,
      PrefetchHooks Function()
    >;
typedef $$EditPreviewsTableCreateCompanionBuilder =
    EditPreviewsCompanion Function({
      required String entryId,
      required String path,
      required int width,
      required int height,
      required String recipeHash,
      required DateTime created,
      Value<int> rowid,
    });
typedef $$EditPreviewsTableUpdateCompanionBuilder =
    EditPreviewsCompanion Function({
      Value<String> entryId,
      Value<String> path,
      Value<int> width,
      Value<int> height,
      Value<String> recipeHash,
      Value<DateTime> created,
      Value<int> rowid,
    });

class $$EditPreviewsTableFilterComposer
    extends Composer<_$CatalogDb, $EditPreviewsTable> {
  $$EditPreviewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipeHash => $composableBuilder(
    column: $table.recipeHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EditPreviewsTableOrderingComposer
    extends Composer<_$CatalogDb, $EditPreviewsTable> {
  $$EditPreviewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipeHash => $composableBuilder(
    column: $table.recipeHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EditPreviewsTableAnnotationComposer
    extends Composer<_$CatalogDb, $EditPreviewsTable> {
  $$EditPreviewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get recipeHash => $composableBuilder(
    column: $table.recipeHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);
}

class $$EditPreviewsTableTableManager
    extends
        RootTableManager<
          _$CatalogDb,
          $EditPreviewsTable,
          EditPreviewRow,
          $$EditPreviewsTableFilterComposer,
          $$EditPreviewsTableOrderingComposer,
          $$EditPreviewsTableAnnotationComposer,
          $$EditPreviewsTableCreateCompanionBuilder,
          $$EditPreviewsTableUpdateCompanionBuilder,
          (
            EditPreviewRow,
            BaseReferences<_$CatalogDb, $EditPreviewsTable, EditPreviewRow>,
          ),
          EditPreviewRow,
          PrefetchHooks Function()
        > {
  $$EditPreviewsTableTableManager(_$CatalogDb db, $EditPreviewsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EditPreviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EditPreviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EditPreviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<String> recipeHash = const Value.absent(),
                Value<DateTime> created = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EditPreviewsCompanion(
                entryId: entryId,
                path: path,
                width: width,
                height: height,
                recipeHash: recipeHash,
                created: created,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String path,
                required int width,
                required int height,
                required String recipeHash,
                required DateTime created,
                Value<int> rowid = const Value.absent(),
              }) => EditPreviewsCompanion.insert(
                entryId: entryId,
                path: path,
                width: width,
                height: height,
                recipeHash: recipeHash,
                created: created,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EditPreviewsTable, EditPreviewRow>(table),
                  BaseReferences<
                    _$CatalogDb,
                    $EditPreviewsTable,
                    EditPreviewRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EditPreviewsTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDb,
      $EditPreviewsTable,
      EditPreviewRow,
      $$EditPreviewsTableFilterComposer,
      $$EditPreviewsTableOrderingComposer,
      $$EditPreviewsTableAnnotationComposer,
      $$EditPreviewsTableCreateCompanionBuilder,
      $$EditPreviewsTableUpdateCompanionBuilder,
      (
        EditPreviewRow,
        BaseReferences<_$CatalogDb, $EditPreviewsTable, EditPreviewRow>,
      ),
      EditPreviewRow,
      PrefetchHooks Function()
    >;

class $CatalogDbManager {
  final _$CatalogDb _db;
  $CatalogDbManager(this._db);
  $$CatalogEntriesTableTableManager get catalogEntries =>
      $$CatalogEntriesTableTableManager(_db, _db.catalogEntries);
  $$EditPreviewsTableTableManager get editPreviews =>
      $$EditPreviewsTableTableManager(_db, _db.editPreviews);
}
