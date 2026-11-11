// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UserPreferencesTable extends UserPreferences
    with TableInfo<$UserPreferencesTable, UserPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
    'theme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeZoneIdMeta = const VerificationMeta(
    'timeZoneId',
  );
  @override
  late final GeneratedColumn<String> timeZoneId = GeneratedColumn<String>(
    'time_zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('America/Sao_Paulo'),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _onboardingMeta = const VerificationMeta(
    'onboarding',
  );
  @override
  late final GeneratedColumn<String> onboarding = GeneratedColumn<String>(
    'onboarding',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    theme,
    timeZoneId,
    version,
    updatedAt,
    onboarding,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('theme')) {
      context.handle(
        _themeMeta,
        theme.isAcceptableOrUnknown(data['theme']!, _themeMeta),
      );
    }
    if (data.containsKey('time_zone_id')) {
      context.handle(
        _timeZoneIdMeta,
        timeZoneId.isAcceptableOrUnknown(
          data['time_zone_id']!,
          _timeZoneIdMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('onboarding')) {
      context.handle(
        _onboardingMeta,
        onboarding.isAcceptableOrUnknown(data['onboarding']!, _onboardingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId};
  @override
  UserPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreference(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      theme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme'],
      ),
      timeZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      onboarding: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}onboarding'],
      )!,
    );
  }

  @override
  $UserPreferencesTable createAlias(String alias) {
    return $UserPreferencesTable(attachedDatabase, alias);
  }
}

class UserPreference extends DataClass implements Insertable<UserPreference> {
  final String ownerId;
  final String? theme;
  final String timeZoneId;
  final int version;
  final String updatedAt;

  /// Progresso do assistente inicial (RF024, D7): JSON `{etapa: done|skipped}`.
  final String onboarding;
  const UserPreference({
    required this.ownerId,
    this.theme,
    required this.timeZoneId,
    required this.version,
    required this.updatedAt,
    required this.onboarding,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    if (!nullToAbsent || theme != null) {
      map['theme'] = Variable<String>(theme);
    }
    map['time_zone_id'] = Variable<String>(timeZoneId);
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<String>(updatedAt);
    map['onboarding'] = Variable<String>(onboarding);
    return map;
  }

  UserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesCompanion(
      ownerId: Value(ownerId),
      theme: theme == null && nullToAbsent
          ? const Value.absent()
          : Value(theme),
      timeZoneId: Value(timeZoneId),
      version: Value(version),
      updatedAt: Value(updatedAt),
      onboarding: Value(onboarding),
    );
  }

  factory UserPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreference(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      theme: serializer.fromJson<String?>(json['theme']),
      timeZoneId: serializer.fromJson<String>(json['timeZoneId']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      onboarding: serializer.fromJson<String>(json['onboarding']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'theme': serializer.toJson<String?>(theme),
      'timeZoneId': serializer.toJson<String>(timeZoneId),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'onboarding': serializer.toJson<String>(onboarding),
    };
  }

  UserPreference copyWith({
    String? ownerId,
    Value<String?> theme = const Value.absent(),
    String? timeZoneId,
    int? version,
    String? updatedAt,
    String? onboarding,
  }) => UserPreference(
    ownerId: ownerId ?? this.ownerId,
    theme: theme.present ? theme.value : this.theme,
    timeZoneId: timeZoneId ?? this.timeZoneId,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
    onboarding: onboarding ?? this.onboarding,
  );
  UserPreference copyWithCompanion(UserPreferencesCompanion data) {
    return UserPreference(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      theme: data.theme.present ? data.theme.value : this.theme,
      timeZoneId: data.timeZoneId.present
          ? data.timeZoneId.value
          : this.timeZoneId,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      onboarding: data.onboarding.present
          ? data.onboarding.value
          : this.onboarding,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreference(')
          ..write('ownerId: $ownerId, ')
          ..write('theme: $theme, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('onboarding: $onboarding')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(ownerId, theme, timeZoneId, version, updatedAt, onboarding);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreference &&
          other.ownerId == this.ownerId &&
          other.theme == this.theme &&
          other.timeZoneId == this.timeZoneId &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt &&
          other.onboarding == this.onboarding);
}

class UserPreferencesCompanion extends UpdateCompanion<UserPreference> {
  final Value<String> ownerId;
  final Value<String?> theme;
  final Value<String> timeZoneId;
  final Value<int> version;
  final Value<String> updatedAt;
  final Value<String> onboarding;
  final Value<int> rowid;
  const UserPreferencesCompanion({
    this.ownerId = const Value.absent(),
    this.theme = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.onboarding = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserPreferencesCompanion.insert({
    required String ownerId,
    this.theme = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.version = const Value.absent(),
    required String updatedAt,
    this.onboarding = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       updatedAt = Value(updatedAt);
  static Insertable<UserPreference> custom({
    Expression<String>? ownerId,
    Expression<String>? theme,
    Expression<String>? timeZoneId,
    Expression<int>? version,
    Expression<String>? updatedAt,
    Expression<String>? onboarding,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (theme != null) 'theme': theme,
      if (timeZoneId != null) 'time_zone_id': timeZoneId,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (onboarding != null) 'onboarding': onboarding,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserPreferencesCompanion copyWith({
    Value<String>? ownerId,
    Value<String?>? theme,
    Value<String>? timeZoneId,
    Value<int>? version,
    Value<String>? updatedAt,
    Value<String>? onboarding,
    Value<int>? rowid,
  }) {
    return UserPreferencesCompanion(
      ownerId: ownerId ?? this.ownerId,
      theme: theme ?? this.theme,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      onboarding: onboarding ?? this.onboarding,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    if (timeZoneId.present) {
      map['time_zone_id'] = Variable<String>(timeZoneId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (onboarding.present) {
      map['onboarding'] = Variable<String>(onboarding.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('theme: $theme, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('onboarding: $onboarding, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeriodConfigurationsTable extends PeriodConfigurations
    with TableInfo<$PeriodConfigurationsTable, PeriodConfiguration> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeriodConfigurationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customStartDayMeta = const VerificationMeta(
    'customStartDay',
  );
  @override
  late final GeneratedColumn<int> customStartDay = GeneratedColumn<int>(
    'custom_start_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _effectiveFromMeta = const VerificationMeta(
    'effectiveFrom',
  );
  @override
  late final GeneratedColumn<String> effectiveFrom = GeneratedColumn<String>(
    'effective_from',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    mode,
    customStartDay,
    effectiveFrom,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'period_configurations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeriodConfiguration> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('custom_start_day')) {
      context.handle(
        _customStartDayMeta,
        customStartDay.isAcceptableOrUnknown(
          data['custom_start_day']!,
          _customStartDayMeta,
        ),
      );
    }
    if (data.containsKey('effective_from')) {
      context.handle(
        _effectiveFromMeta,
        effectiveFrom.isAcceptableOrUnknown(
          data['effective_from']!,
          _effectiveFromMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveFromMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  PeriodConfiguration map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeriodConfiguration(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      customStartDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_start_day'],
      ),
      effectiveFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_from'],
      )!,
    );
  }

  @override
  $PeriodConfigurationsTable createAlias(String alias) {
    return $PeriodConfigurationsTable(attachedDatabase, alias);
  }
}

class PeriodConfiguration extends DataClass
    implements Insertable<PeriodConfiguration> {
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String mode;
  final int? customStartDay;
  final String effectiveFrom;
  const PeriodConfiguration({
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.mode,
    this.customStartDay,
    required this.effectiveFrom,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || customStartDay != null) {
      map['custom_start_day'] = Variable<int>(customStartDay);
    }
    map['effective_from'] = Variable<String>(effectiveFrom);
    return map;
  }

  PeriodConfigurationsCompanion toCompanion(bool nullToAbsent) {
    return PeriodConfigurationsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      mode: Value(mode),
      customStartDay: customStartDay == null && nullToAbsent
          ? const Value.absent()
          : Value(customStartDay),
      effectiveFrom: Value(effectiveFrom),
    );
  }

  factory PeriodConfiguration.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeriodConfiguration(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      mode: serializer.fromJson<String>(json['mode']),
      customStartDay: serializer.fromJson<int?>(json['customStartDay']),
      effectiveFrom: serializer.fromJson<String>(json['effectiveFrom']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'mode': serializer.toJson<String>(mode),
      'customStartDay': serializer.toJson<int?>(customStartDay),
      'effectiveFrom': serializer.toJson<String>(effectiveFrom),
    };
  }

  PeriodConfiguration copyWith({
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
    String? mode,
    Value<int?> customStartDay = const Value.absent(),
    String? effectiveFrom,
  }) => PeriodConfiguration(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    mode: mode ?? this.mode,
    customStartDay: customStartDay.present
        ? customStartDay.value
        : this.customStartDay,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
  );
  PeriodConfiguration copyWithCompanion(PeriodConfigurationsCompanion data) {
    return PeriodConfiguration(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      mode: data.mode.present ? data.mode.value : this.mode,
      customStartDay: data.customStartDay.present
          ? data.customStartDay.value
          : this.customStartDay,
      effectiveFrom: data.effectiveFrom.present
          ? data.effectiveFrom.value
          : this.effectiveFrom,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeriodConfiguration(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('mode: $mode, ')
          ..write('customStartDay: $customStartDay, ')
          ..write('effectiveFrom: $effectiveFrom')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    mode,
    customStartDay,
    effectiveFrom,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeriodConfiguration &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.mode == this.mode &&
          other.customStartDay == this.customStartDay &&
          other.effectiveFrom == this.effectiveFrom);
}

class PeriodConfigurationsCompanion
    extends UpdateCompanion<PeriodConfiguration> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String> mode;
  final Value<int?> customStartDay;
  final Value<String> effectiveFrom;
  final Value<int> rowid;
  const PeriodConfigurationsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.mode = const Value.absent(),
    this.customStartDay = const Value.absent(),
    this.effectiveFrom = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeriodConfigurationsCompanion.insert({
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    required String mode,
    this.customStartDay = const Value.absent(),
    required String effectiveFrom,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       mode = Value(mode),
       effectiveFrom = Value(effectiveFrom);
  static Insertable<PeriodConfiguration> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? mode,
    Expression<int>? customStartDay,
    Expression<String>? effectiveFrom,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (mode != null) 'mode': mode,
      if (customStartDay != null) 'custom_start_day': customStartDay,
      if (effectiveFrom != null) 'effective_from': effectiveFrom,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeriodConfigurationsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String>? mode,
    Value<int?>? customStartDay,
    Value<String>? effectiveFrom,
    Value<int>? rowid,
  }) {
    return PeriodConfigurationsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mode: mode ?? this.mode,
      customStartDay: customStartDay ?? this.customStartDay,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (customStartDay.present) {
      map['custom_start_day'] = Variable<int>(customStartDay.value);
    }
    if (effectiveFrom.present) {
      map['effective_from'] = Variable<String>(effectiveFrom.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeriodConfigurationsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('mode: $mode, ')
          ..write('customStartDay: $customStartDay, ')
          ..write('effectiveFrom: $effectiveFrom, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountingPeriodsTable extends AccountingPeriods
    with TableInfo<$AccountingPeriodsTable, AccountingPeriod> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountingPeriodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configurationIdMeta = const VerificationMeta(
    'configurationId',
  );
  @override
  late final GeneratedColumn<String> configurationId = GeneratedColumn<String>(
    'configuration_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    configurationId,
    startDate,
    endDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounting_periods';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountingPeriod> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('configuration_id')) {
      context.handle(
        _configurationIdMeta,
        configurationId.isAcceptableOrUnknown(
          data['configuration_id']!,
          _configurationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_configurationIdMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  AccountingPeriod map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountingPeriod(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      configurationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}configuration_id'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      )!,
    );
  }

  @override
  $AccountingPeriodsTable createAlias(String alias) {
    return $AccountingPeriodsTable(attachedDatabase, alias);
  }
}

class AccountingPeriod extends DataClass
    implements Insertable<AccountingPeriod> {
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String configurationId;
  final String startDate;
  final String endDate;
  const AccountingPeriod({
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.configurationId,
    required this.startDate,
    required this.endDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['configuration_id'] = Variable<String>(configurationId);
    map['start_date'] = Variable<String>(startDate);
    map['end_date'] = Variable<String>(endDate);
    return map;
  }

  AccountingPeriodsCompanion toCompanion(bool nullToAbsent) {
    return AccountingPeriodsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      configurationId: Value(configurationId),
      startDate: Value(startDate),
      endDate: Value(endDate),
    );
  }

  factory AccountingPeriod.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountingPeriod(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      configurationId: serializer.fromJson<String>(json['configurationId']),
      startDate: serializer.fromJson<String>(json['startDate']),
      endDate: serializer.fromJson<String>(json['endDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'configurationId': serializer.toJson<String>(configurationId),
      'startDate': serializer.toJson<String>(startDate),
      'endDate': serializer.toJson<String>(endDate),
    };
  }

  AccountingPeriod copyWith({
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
    String? configurationId,
    String? startDate,
    String? endDate,
  }) => AccountingPeriod(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    configurationId: configurationId ?? this.configurationId,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
  );
  AccountingPeriod copyWithCompanion(AccountingPeriodsCompanion data) {
    return AccountingPeriod(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      configurationId: data.configurationId.present
          ? data.configurationId.value
          : this.configurationId,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountingPeriod(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('configurationId: $configurationId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    configurationId,
    startDate,
    endDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountingPeriod &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.configurationId == this.configurationId &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate);
}

class AccountingPeriodsCompanion extends UpdateCompanion<AccountingPeriod> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String> configurationId;
  final Value<String> startDate;
  final Value<String> endDate;
  final Value<int> rowid;
  const AccountingPeriodsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.configurationId = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountingPeriodsCompanion.insert({
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    required String configurationId,
    required String startDate,
    required String endDate,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       configurationId = Value(configurationId),
       startDate = Value(startDate),
       endDate = Value(endDate);
  static Insertable<AccountingPeriod> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? configurationId,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (configurationId != null) 'configuration_id': configurationId,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountingPeriodsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String>? configurationId,
    Value<String>? startDate,
    Value<String>? endDate,
    Value<int>? rowid,
  }) {
    return AccountingPeriodsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      configurationId: configurationId ?? this.configurationId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (configurationId.present) {
      map['configuration_id'] = Variable<String>(configurationId.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountingPeriodsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('configurationId: $configurationId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    kind,
    name,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String kind;
  final String name;
  final bool isActive;
  const Category({
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.kind,
    required this.name,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      kind: Value(kind),
      name: Value(name),
      isActive: Value(isActive),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Category copyWith({
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
    String? kind,
    String? name,
    bool? isActive,
  }) => Category(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    isActive: isActive ?? this.isActive,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    kind,
    name,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.isActive == this.isActive);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String> kind;
  final Value<String> name;
  final Value<bool> isActive;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    required String kind,
    required String name,
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       kind = Value(kind),
       name = Value(name);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String>? kind,
    Value<String>? name,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubcategoriesTable extends Subcategories
    with TableInfo<$SubcategoriesTable, Subcategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubcategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    categoryId,
    name,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subcategories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subcategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  Subcategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subcategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $SubcategoriesTable createAlias(String alias) {
    return $SubcategoriesTable(attachedDatabase, alias);
  }
}

class Subcategory extends DataClass implements Insertable<Subcategory> {
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String categoryId;
  final String name;
  final bool isActive;
  const Subcategory({
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.categoryId,
    required this.name,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['category_id'] = Variable<String>(categoryId);
    map['name'] = Variable<String>(name);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  SubcategoriesCompanion toCompanion(bool nullToAbsent) {
    return SubcategoriesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      categoryId: Value(categoryId),
      name: Value(name),
      isActive: Value(isActive),
    );
  }

  factory Subcategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subcategory(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'categoryId': serializer.toJson<String>(categoryId),
      'name': serializer.toJson<String>(name),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Subcategory copyWith({
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
    String? categoryId,
    String? name,
    bool? isActive,
  }) => Subcategory(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    isActive: isActive ?? this.isActive,
  );
  Subcategory copyWithCompanion(SubcategoriesCompanion data) {
    return Subcategory(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subcategory(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    categoryId,
    name,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subcategory &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.isActive == this.isActive);
}

class SubcategoriesCompanion extends UpdateCompanion<Subcategory> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String> categoryId;
  final Value<String> name;
  final Value<bool> isActive;
  final Value<int> rowid;
  const SubcategoriesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubcategoriesCompanion.insert({
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    required String categoryId,
    required String name,
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       categoryId = Value(categoryId),
       name = Value(name);
  static Insertable<Subcategory> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubcategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String>? categoryId,
    Value<String>? name,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return SubcategoriesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubcategoriesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IncomeRecurrenceTemplatesTable extends IncomeRecurrenceTemplates
    with TableInfo<$IncomeRecurrenceTemplatesTable, IncomeRecurrenceTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IncomeRecurrenceTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startsOnMeta = const VerificationMeta(
    'startsOn',
  );
  @override
  late final GeneratedColumn<String> startsOn = GeneratedColumn<String>(
    'starts_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthlyReferenceDayMeta =
      const VerificationMeta('monthlyReferenceDay');
  @override
  late final GeneratedColumn<int> monthlyReferenceDay = GeneratedColumn<int>(
    'monthly_reference_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueModeMeta = const VerificationMeta(
    'valueMode',
  );
  @override
  late final GeneratedColumn<String> valueMode = GeneratedColumn<String>(
    'value_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BigInt?, String>
  defaultAmountCentavos =
      GeneratedColumn<String>(
        'default_amount_centavos',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<BigInt?>(
        $IncomeRecurrenceTemplatesTable.$converterdefaultAmountCentavosn,
      );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subcategoryIdMeta = const VerificationMeta(
    'subcategoryId',
  );
  @override
  late final GeneratedColumn<String> subcategoryId = GeneratedColumn<String>(
    'subcategory_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    description,
    frequency,
    startsOn,
    monthlyReferenceDay,
    valueMode,
    defaultAmountCentavos,
    categoryId,
    subcategoryId,
    isActive,
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'income_recurrence_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<IncomeRecurrenceTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('starts_on')) {
      context.handle(
        _startsOnMeta,
        startsOn.isAcceptableOrUnknown(data['starts_on']!, _startsOnMeta),
      );
    } else if (isInserting) {
      context.missing(_startsOnMeta);
    }
    if (data.containsKey('monthly_reference_day')) {
      context.handle(
        _monthlyReferenceDayMeta,
        monthlyReferenceDay.isAcceptableOrUnknown(
          data['monthly_reference_day']!,
          _monthlyReferenceDayMeta,
        ),
      );
    }
    if (data.containsKey('value_mode')) {
      context.handle(
        _valueModeMeta,
        valueMode.isAcceptableOrUnknown(data['value_mode']!, _valueModeMeta),
      );
    } else if (isInserting) {
      context.missing(_valueModeMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('subcategory_id')) {
      context.handle(
        _subcategoryIdMeta,
        subcategoryId.isAcceptableOrUnknown(
          data['subcategory_id']!,
          _subcategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  IncomeRecurrenceTemplate map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IncomeRecurrenceTemplate(
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      startsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starts_on'],
      )!,
      monthlyReferenceDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monthly_reference_day'],
      ),
      valueMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_mode'],
      )!,
      defaultAmountCentavos: $IncomeRecurrenceTemplatesTable
          .$converterdefaultAmountCentavosn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}default_amount_centavos'],
            ),
          ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      subcategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_id'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $IncomeRecurrenceTemplatesTable createAlias(String alias) {
    return $IncomeRecurrenceTemplatesTable(attachedDatabase, alias);
  }

  static TypeConverter<BigInt, String> $converterdefaultAmountCentavos =
      const BigIntTextConverter();
  static TypeConverter<BigInt?, String?> $converterdefaultAmountCentavosn =
      NullAwareTypeConverter.wrap($converterdefaultAmountCentavos);
}

class IncomeRecurrenceTemplate extends DataClass
    implements Insertable<IncomeRecurrenceTemplate> {
  final String? description;
  final String frequency;
  final String startsOn;
  final int? monthlyReferenceDay;
  final String valueMode;
  final BigInt? defaultAmountCentavos;
  final String? categoryId;
  final String? subcategoryId;
  final bool isActive;
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  const IncomeRecurrenceTemplate({
    this.description,
    required this.frequency,
    required this.startsOn,
    this.monthlyReferenceDay,
    required this.valueMode,
    this.defaultAmountCentavos,
    this.categoryId,
    this.subcategoryId,
    required this.isActive,
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['frequency'] = Variable<String>(frequency);
    map['starts_on'] = Variable<String>(startsOn);
    if (!nullToAbsent || monthlyReferenceDay != null) {
      map['monthly_reference_day'] = Variable<int>(monthlyReferenceDay);
    }
    map['value_mode'] = Variable<String>(valueMode);
    if (!nullToAbsent || defaultAmountCentavos != null) {
      map['default_amount_centavos'] = Variable<String>(
        $IncomeRecurrenceTemplatesTable.$converterdefaultAmountCentavosn.toSql(
          defaultAmountCentavos,
        ),
      );
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || subcategoryId != null) {
      map['subcategory_id'] = Variable<String>(subcategoryId);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  IncomeRecurrenceTemplatesCompanion toCompanion(bool nullToAbsent) {
    return IncomeRecurrenceTemplatesCompanion(
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      frequency: Value(frequency),
      startsOn: Value(startsOn),
      monthlyReferenceDay: monthlyReferenceDay == null && nullToAbsent
          ? const Value.absent()
          : Value(monthlyReferenceDay),
      valueMode: Value(valueMode),
      defaultAmountCentavos: defaultAmountCentavos == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAmountCentavos),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      subcategoryId: subcategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryId),
      isActive: Value(isActive),
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory IncomeRecurrenceTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IncomeRecurrenceTemplate(
      description: serializer.fromJson<String?>(json['description']),
      frequency: serializer.fromJson<String>(json['frequency']),
      startsOn: serializer.fromJson<String>(json['startsOn']),
      monthlyReferenceDay: serializer.fromJson<int?>(
        json['monthlyReferenceDay'],
      ),
      valueMode: serializer.fromJson<String>(json['valueMode']),
      defaultAmountCentavos: serializer.fromJson<BigInt?>(
        json['defaultAmountCentavos'],
      ),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      subcategoryId: serializer.fromJson<String?>(json['subcategoryId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'description': serializer.toJson<String?>(description),
      'frequency': serializer.toJson<String>(frequency),
      'startsOn': serializer.toJson<String>(startsOn),
      'monthlyReferenceDay': serializer.toJson<int?>(monthlyReferenceDay),
      'valueMode': serializer.toJson<String>(valueMode),
      'defaultAmountCentavos': serializer.toJson<BigInt?>(
        defaultAmountCentavos,
      ),
      'categoryId': serializer.toJson<String?>(categoryId),
      'subcategoryId': serializer.toJson<String?>(subcategoryId),
      'isActive': serializer.toJson<bool>(isActive),
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  IncomeRecurrenceTemplate copyWith({
    Value<String?> description = const Value.absent(),
    String? frequency,
    String? startsOn,
    Value<int?> monthlyReferenceDay = const Value.absent(),
    String? valueMode,
    Value<BigInt?> defaultAmountCentavos = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> subcategoryId = const Value.absent(),
    bool? isActive,
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
  }) => IncomeRecurrenceTemplate(
    description: description.present ? description.value : this.description,
    frequency: frequency ?? this.frequency,
    startsOn: startsOn ?? this.startsOn,
    monthlyReferenceDay: monthlyReferenceDay.present
        ? monthlyReferenceDay.value
        : this.monthlyReferenceDay,
    valueMode: valueMode ?? this.valueMode,
    defaultAmountCentavos: defaultAmountCentavos.present
        ? defaultAmountCentavos.value
        : this.defaultAmountCentavos,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    subcategoryId: subcategoryId.present
        ? subcategoryId.value
        : this.subcategoryId,
    isActive: isActive ?? this.isActive,
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  IncomeRecurrenceTemplate copyWithCompanion(
    IncomeRecurrenceTemplatesCompanion data,
  ) {
    return IncomeRecurrenceTemplate(
      description: data.description.present
          ? data.description.value
          : this.description,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      startsOn: data.startsOn.present ? data.startsOn.value : this.startsOn,
      monthlyReferenceDay: data.monthlyReferenceDay.present
          ? data.monthlyReferenceDay.value
          : this.monthlyReferenceDay,
      valueMode: data.valueMode.present ? data.valueMode.value : this.valueMode,
      defaultAmountCentavos: data.defaultAmountCentavos.present
          ? data.defaultAmountCentavos.value
          : this.defaultAmountCentavos,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      subcategoryId: data.subcategoryId.present
          ? data.subcategoryId.value
          : this.subcategoryId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IncomeRecurrenceTemplate(')
          ..write('description: $description, ')
          ..write('frequency: $frequency, ')
          ..write('startsOn: $startsOn, ')
          ..write('monthlyReferenceDay: $monthlyReferenceDay, ')
          ..write('valueMode: $valueMode, ')
          ..write('defaultAmountCentavos: $defaultAmountCentavos, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('isActive: $isActive, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    description,
    frequency,
    startsOn,
    monthlyReferenceDay,
    valueMode,
    defaultAmountCentavos,
    categoryId,
    subcategoryId,
    isActive,
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IncomeRecurrenceTemplate &&
          other.description == this.description &&
          other.frequency == this.frequency &&
          other.startsOn == this.startsOn &&
          other.monthlyReferenceDay == this.monthlyReferenceDay &&
          other.valueMode == this.valueMode &&
          other.defaultAmountCentavos == this.defaultAmountCentavos &&
          other.categoryId == this.categoryId &&
          other.subcategoryId == this.subcategoryId &&
          other.isActive == this.isActive &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class IncomeRecurrenceTemplatesCompanion
    extends UpdateCompanion<IncomeRecurrenceTemplate> {
  final Value<String?> description;
  final Value<String> frequency;
  final Value<String> startsOn;
  final Value<int?> monthlyReferenceDay;
  final Value<String> valueMode;
  final Value<BigInt?> defaultAmountCentavos;
  final Value<String?> categoryId;
  final Value<String?> subcategoryId;
  final Value<bool> isActive;
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const IncomeRecurrenceTemplatesCompanion({
    this.description = const Value.absent(),
    this.frequency = const Value.absent(),
    this.startsOn = const Value.absent(),
    this.monthlyReferenceDay = const Value.absent(),
    this.valueMode = const Value.absent(),
    this.defaultAmountCentavos = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IncomeRecurrenceTemplatesCompanion.insert({
    this.description = const Value.absent(),
    required String frequency,
    required String startsOn,
    this.monthlyReferenceDay = const Value.absent(),
    required String valueMode,
    this.defaultAmountCentavos = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.isActive = const Value.absent(),
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : frequency = Value(frequency),
       startsOn = Value(startsOn),
       valueMode = Value(valueMode),
       id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<IncomeRecurrenceTemplate> custom({
    Expression<String>? description,
    Expression<String>? frequency,
    Expression<String>? startsOn,
    Expression<int>? monthlyReferenceDay,
    Expression<String>? valueMode,
    Expression<String>? defaultAmountCentavos,
    Expression<String>? categoryId,
    Expression<String>? subcategoryId,
    Expression<bool>? isActive,
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (description != null) 'description': description,
      if (frequency != null) 'frequency': frequency,
      if (startsOn != null) 'starts_on': startsOn,
      if (monthlyReferenceDay != null)
        'monthly_reference_day': monthlyReferenceDay,
      if (valueMode != null) 'value_mode': valueMode,
      if (defaultAmountCentavos != null)
        'default_amount_centavos': defaultAmountCentavos,
      if (categoryId != null) 'category_id': categoryId,
      if (subcategoryId != null) 'subcategory_id': subcategoryId,
      if (isActive != null) 'is_active': isActive,
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IncomeRecurrenceTemplatesCompanion copyWith({
    Value<String?>? description,
    Value<String>? frequency,
    Value<String>? startsOn,
    Value<int?>? monthlyReferenceDay,
    Value<String>? valueMode,
    Value<BigInt?>? defaultAmountCentavos,
    Value<String?>? categoryId,
    Value<String?>? subcategoryId,
    Value<bool>? isActive,
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return IncomeRecurrenceTemplatesCompanion(
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      startsOn: startsOn ?? this.startsOn,
      monthlyReferenceDay: monthlyReferenceDay ?? this.monthlyReferenceDay,
      valueMode: valueMode ?? this.valueMode,
      defaultAmountCentavos:
          defaultAmountCentavos ?? this.defaultAmountCentavos,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      isActive: isActive ?? this.isActive,
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (startsOn.present) {
      map['starts_on'] = Variable<String>(startsOn.value);
    }
    if (monthlyReferenceDay.present) {
      map['monthly_reference_day'] = Variable<int>(monthlyReferenceDay.value);
    }
    if (valueMode.present) {
      map['value_mode'] = Variable<String>(valueMode.value);
    }
    if (defaultAmountCentavos.present) {
      map['default_amount_centavos'] = Variable<String>(
        $IncomeRecurrenceTemplatesTable.$converterdefaultAmountCentavosn.toSql(
          defaultAmountCentavos.value,
        ),
      );
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (subcategoryId.present) {
      map['subcategory_id'] = Variable<String>(subcategoryId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IncomeRecurrenceTemplatesCompanion(')
          ..write('description: $description, ')
          ..write('frequency: $frequency, ')
          ..write('startsOn: $startsOn, ')
          ..write('monthlyReferenceDay: $monthlyReferenceDay, ')
          ..write('valueMode: $valueMode, ')
          ..write('defaultAmountCentavos: $defaultAmountCentavos, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('isActive: $isActive, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpenseRecurrenceTemplatesTable extends ExpenseRecurrenceTemplates
    with
        TableInfo<$ExpenseRecurrenceTemplatesTable, ExpenseRecurrenceTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpenseRecurrenceTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startsOnMeta = const VerificationMeta(
    'startsOn',
  );
  @override
  late final GeneratedColumn<String> startsOn = GeneratedColumn<String>(
    'starts_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthlyReferenceDayMeta =
      const VerificationMeta('monthlyReferenceDay');
  @override
  late final GeneratedColumn<int> monthlyReferenceDay = GeneratedColumn<int>(
    'monthly_reference_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueModeMeta = const VerificationMeta(
    'valueMode',
  );
  @override
  late final GeneratedColumn<String> valueMode = GeneratedColumn<String>(
    'value_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BigInt?, String>
  defaultAmountCentavos =
      GeneratedColumn<String>(
        'default_amount_centavos',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<BigInt?>(
        $ExpenseRecurrenceTemplatesTable.$converterdefaultAmountCentavosn,
      );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subcategoryIdMeta = const VerificationMeta(
    'subcategoryId',
  );
  @override
  late final GeneratedColumn<String> subcategoryId = GeneratedColumn<String>(
    'subcategory_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    description,
    frequency,
    startsOn,
    monthlyReferenceDay,
    valueMode,
    defaultAmountCentavos,
    categoryId,
    subcategoryId,
    isActive,
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_recurrence_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseRecurrenceTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('starts_on')) {
      context.handle(
        _startsOnMeta,
        startsOn.isAcceptableOrUnknown(data['starts_on']!, _startsOnMeta),
      );
    } else if (isInserting) {
      context.missing(_startsOnMeta);
    }
    if (data.containsKey('monthly_reference_day')) {
      context.handle(
        _monthlyReferenceDayMeta,
        monthlyReferenceDay.isAcceptableOrUnknown(
          data['monthly_reference_day']!,
          _monthlyReferenceDayMeta,
        ),
      );
    }
    if (data.containsKey('value_mode')) {
      context.handle(
        _valueModeMeta,
        valueMode.isAcceptableOrUnknown(data['value_mode']!, _valueModeMeta),
      );
    } else if (isInserting) {
      context.missing(_valueModeMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('subcategory_id')) {
      context.handle(
        _subcategoryIdMeta,
        subcategoryId.isAcceptableOrUnknown(
          data['subcategory_id']!,
          _subcategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  ExpenseRecurrenceTemplate map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseRecurrenceTemplate(
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      startsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starts_on'],
      )!,
      monthlyReferenceDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monthly_reference_day'],
      ),
      valueMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_mode'],
      )!,
      defaultAmountCentavos: $ExpenseRecurrenceTemplatesTable
          .$converterdefaultAmountCentavosn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}default_amount_centavos'],
            ),
          ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      subcategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_id'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ExpenseRecurrenceTemplatesTable createAlias(String alias) {
    return $ExpenseRecurrenceTemplatesTable(attachedDatabase, alias);
  }

  static TypeConverter<BigInt, String> $converterdefaultAmountCentavos =
      const BigIntTextConverter();
  static TypeConverter<BigInt?, String?> $converterdefaultAmountCentavosn =
      NullAwareTypeConverter.wrap($converterdefaultAmountCentavos);
}

class ExpenseRecurrenceTemplate extends DataClass
    implements Insertable<ExpenseRecurrenceTemplate> {
  final String? description;
  final String frequency;
  final String startsOn;
  final int? monthlyReferenceDay;
  final String valueMode;
  final BigInt? defaultAmountCentavos;
  final String? categoryId;
  final String? subcategoryId;
  final bool isActive;
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  const ExpenseRecurrenceTemplate({
    this.description,
    required this.frequency,
    required this.startsOn,
    this.monthlyReferenceDay,
    required this.valueMode,
    this.defaultAmountCentavos,
    this.categoryId,
    this.subcategoryId,
    required this.isActive,
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['frequency'] = Variable<String>(frequency);
    map['starts_on'] = Variable<String>(startsOn);
    if (!nullToAbsent || monthlyReferenceDay != null) {
      map['monthly_reference_day'] = Variable<int>(monthlyReferenceDay);
    }
    map['value_mode'] = Variable<String>(valueMode);
    if (!nullToAbsent || defaultAmountCentavos != null) {
      map['default_amount_centavos'] = Variable<String>(
        $ExpenseRecurrenceTemplatesTable.$converterdefaultAmountCentavosn.toSql(
          defaultAmountCentavos,
        ),
      );
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || subcategoryId != null) {
      map['subcategory_id'] = Variable<String>(subcategoryId);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ExpenseRecurrenceTemplatesCompanion toCompanion(bool nullToAbsent) {
    return ExpenseRecurrenceTemplatesCompanion(
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      frequency: Value(frequency),
      startsOn: Value(startsOn),
      monthlyReferenceDay: monthlyReferenceDay == null && nullToAbsent
          ? const Value.absent()
          : Value(monthlyReferenceDay),
      valueMode: Value(valueMode),
      defaultAmountCentavos: defaultAmountCentavos == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAmountCentavos),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      subcategoryId: subcategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryId),
      isActive: Value(isActive),
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ExpenseRecurrenceTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseRecurrenceTemplate(
      description: serializer.fromJson<String?>(json['description']),
      frequency: serializer.fromJson<String>(json['frequency']),
      startsOn: serializer.fromJson<String>(json['startsOn']),
      monthlyReferenceDay: serializer.fromJson<int?>(
        json['monthlyReferenceDay'],
      ),
      valueMode: serializer.fromJson<String>(json['valueMode']),
      defaultAmountCentavos: serializer.fromJson<BigInt?>(
        json['defaultAmountCentavos'],
      ),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      subcategoryId: serializer.fromJson<String?>(json['subcategoryId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'description': serializer.toJson<String?>(description),
      'frequency': serializer.toJson<String>(frequency),
      'startsOn': serializer.toJson<String>(startsOn),
      'monthlyReferenceDay': serializer.toJson<int?>(monthlyReferenceDay),
      'valueMode': serializer.toJson<String>(valueMode),
      'defaultAmountCentavos': serializer.toJson<BigInt?>(
        defaultAmountCentavos,
      ),
      'categoryId': serializer.toJson<String?>(categoryId),
      'subcategoryId': serializer.toJson<String?>(subcategoryId),
      'isActive': serializer.toJson<bool>(isActive),
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  ExpenseRecurrenceTemplate copyWith({
    Value<String?> description = const Value.absent(),
    String? frequency,
    String? startsOn,
    Value<int?> monthlyReferenceDay = const Value.absent(),
    String? valueMode,
    Value<BigInt?> defaultAmountCentavos = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> subcategoryId = const Value.absent(),
    bool? isActive,
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
  }) => ExpenseRecurrenceTemplate(
    description: description.present ? description.value : this.description,
    frequency: frequency ?? this.frequency,
    startsOn: startsOn ?? this.startsOn,
    monthlyReferenceDay: monthlyReferenceDay.present
        ? monthlyReferenceDay.value
        : this.monthlyReferenceDay,
    valueMode: valueMode ?? this.valueMode,
    defaultAmountCentavos: defaultAmountCentavos.present
        ? defaultAmountCentavos.value
        : this.defaultAmountCentavos,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    subcategoryId: subcategoryId.present
        ? subcategoryId.value
        : this.subcategoryId,
    isActive: isActive ?? this.isActive,
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ExpenseRecurrenceTemplate copyWithCompanion(
    ExpenseRecurrenceTemplatesCompanion data,
  ) {
    return ExpenseRecurrenceTemplate(
      description: data.description.present
          ? data.description.value
          : this.description,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      startsOn: data.startsOn.present ? data.startsOn.value : this.startsOn,
      monthlyReferenceDay: data.monthlyReferenceDay.present
          ? data.monthlyReferenceDay.value
          : this.monthlyReferenceDay,
      valueMode: data.valueMode.present ? data.valueMode.value : this.valueMode,
      defaultAmountCentavos: data.defaultAmountCentavos.present
          ? data.defaultAmountCentavos.value
          : this.defaultAmountCentavos,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      subcategoryId: data.subcategoryId.present
          ? data.subcategoryId.value
          : this.subcategoryId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseRecurrenceTemplate(')
          ..write('description: $description, ')
          ..write('frequency: $frequency, ')
          ..write('startsOn: $startsOn, ')
          ..write('monthlyReferenceDay: $monthlyReferenceDay, ')
          ..write('valueMode: $valueMode, ')
          ..write('defaultAmountCentavos: $defaultAmountCentavos, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('isActive: $isActive, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    description,
    frequency,
    startsOn,
    monthlyReferenceDay,
    valueMode,
    defaultAmountCentavos,
    categoryId,
    subcategoryId,
    isActive,
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseRecurrenceTemplate &&
          other.description == this.description &&
          other.frequency == this.frequency &&
          other.startsOn == this.startsOn &&
          other.monthlyReferenceDay == this.monthlyReferenceDay &&
          other.valueMode == this.valueMode &&
          other.defaultAmountCentavos == this.defaultAmountCentavos &&
          other.categoryId == this.categoryId &&
          other.subcategoryId == this.subcategoryId &&
          other.isActive == this.isActive &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ExpenseRecurrenceTemplatesCompanion
    extends UpdateCompanion<ExpenseRecurrenceTemplate> {
  final Value<String?> description;
  final Value<String> frequency;
  final Value<String> startsOn;
  final Value<int?> monthlyReferenceDay;
  final Value<String> valueMode;
  final Value<BigInt?> defaultAmountCentavos;
  final Value<String?> categoryId;
  final Value<String?> subcategoryId;
  final Value<bool> isActive;
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const ExpenseRecurrenceTemplatesCompanion({
    this.description = const Value.absent(),
    this.frequency = const Value.absent(),
    this.startsOn = const Value.absent(),
    this.monthlyReferenceDay = const Value.absent(),
    this.valueMode = const Value.absent(),
    this.defaultAmountCentavos = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpenseRecurrenceTemplatesCompanion.insert({
    this.description = const Value.absent(),
    required String frequency,
    required String startsOn,
    this.monthlyReferenceDay = const Value.absent(),
    required String valueMode,
    this.defaultAmountCentavos = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.isActive = const Value.absent(),
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : frequency = Value(frequency),
       startsOn = Value(startsOn),
       valueMode = Value(valueMode),
       id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ExpenseRecurrenceTemplate> custom({
    Expression<String>? description,
    Expression<String>? frequency,
    Expression<String>? startsOn,
    Expression<int>? monthlyReferenceDay,
    Expression<String>? valueMode,
    Expression<String>? defaultAmountCentavos,
    Expression<String>? categoryId,
    Expression<String>? subcategoryId,
    Expression<bool>? isActive,
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (description != null) 'description': description,
      if (frequency != null) 'frequency': frequency,
      if (startsOn != null) 'starts_on': startsOn,
      if (monthlyReferenceDay != null)
        'monthly_reference_day': monthlyReferenceDay,
      if (valueMode != null) 'value_mode': valueMode,
      if (defaultAmountCentavos != null)
        'default_amount_centavos': defaultAmountCentavos,
      if (categoryId != null) 'category_id': categoryId,
      if (subcategoryId != null) 'subcategory_id': subcategoryId,
      if (isActive != null) 'is_active': isActive,
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpenseRecurrenceTemplatesCompanion copyWith({
    Value<String?>? description,
    Value<String>? frequency,
    Value<String>? startsOn,
    Value<int?>? monthlyReferenceDay,
    Value<String>? valueMode,
    Value<BigInt?>? defaultAmountCentavos,
    Value<String?>? categoryId,
    Value<String?>? subcategoryId,
    Value<bool>? isActive,
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return ExpenseRecurrenceTemplatesCompanion(
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      startsOn: startsOn ?? this.startsOn,
      monthlyReferenceDay: monthlyReferenceDay ?? this.monthlyReferenceDay,
      valueMode: valueMode ?? this.valueMode,
      defaultAmountCentavos:
          defaultAmountCentavos ?? this.defaultAmountCentavos,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      isActive: isActive ?? this.isActive,
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (startsOn.present) {
      map['starts_on'] = Variable<String>(startsOn.value);
    }
    if (monthlyReferenceDay.present) {
      map['monthly_reference_day'] = Variable<int>(monthlyReferenceDay.value);
    }
    if (valueMode.present) {
      map['value_mode'] = Variable<String>(valueMode.value);
    }
    if (defaultAmountCentavos.present) {
      map['default_amount_centavos'] = Variable<String>(
        $ExpenseRecurrenceTemplatesTable.$converterdefaultAmountCentavosn.toSql(
          defaultAmountCentavos.value,
        ),
      );
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (subcategoryId.present) {
      map['subcategory_id'] = Variable<String>(subcategoryId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseRecurrenceTemplatesCompanion(')
          ..write('description: $description, ')
          ..write('frequency: $frequency, ')
          ..write('startsOn: $startsOn, ')
          ..write('monthlyReferenceDay: $monthlyReferenceDay, ')
          ..write('valueMode: $valueMode, ')
          ..write('defaultAmountCentavos: $defaultAmountCentavos, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('isActive: $isActive, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvestmentRecurrenceTemplatesTable extends InvestmentRecurrenceTemplates
    with
        TableInfo<
          $InvestmentRecurrenceTemplatesTable,
          InvestmentRecurrenceTemplate
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvestmentRecurrenceTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startsOnMeta = const VerificationMeta(
    'startsOn',
  );
  @override
  late final GeneratedColumn<String> startsOn = GeneratedColumn<String>(
    'starts_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthlyReferenceDayMeta =
      const VerificationMeta('monthlyReferenceDay');
  @override
  late final GeneratedColumn<int> monthlyReferenceDay = GeneratedColumn<int>(
    'monthly_reference_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BigInt, String>
  defaultAmountCentavos =
      GeneratedColumn<String>(
        'default_amount_centavos',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BigInt>(
        $InvestmentRecurrenceTemplatesTable.$converterdefaultAmountCentavos,
      );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    frequency,
    startsOn,
    monthlyReferenceDay,
    defaultAmountCentavos,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'investment_recurrence_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<InvestmentRecurrenceTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('starts_on')) {
      context.handle(
        _startsOnMeta,
        startsOn.isAcceptableOrUnknown(data['starts_on']!, _startsOnMeta),
      );
    } else if (isInserting) {
      context.missing(_startsOnMeta);
    }
    if (data.containsKey('monthly_reference_day')) {
      context.handle(
        _monthlyReferenceDayMeta,
        monthlyReferenceDay.isAcceptableOrUnknown(
          data['monthly_reference_day']!,
          _monthlyReferenceDayMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  InvestmentRecurrenceTemplate map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvestmentRecurrenceTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      startsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starts_on'],
      )!,
      monthlyReferenceDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monthly_reference_day'],
      ),
      defaultAmountCentavos: $InvestmentRecurrenceTemplatesTable
          .$converterdefaultAmountCentavos
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}default_amount_centavos'],
            )!,
          ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $InvestmentRecurrenceTemplatesTable createAlias(String alias) {
    return $InvestmentRecurrenceTemplatesTable(attachedDatabase, alias);
  }

  static TypeConverter<BigInt, String> $converterdefaultAmountCentavos =
      const BigIntTextConverter();
}

class InvestmentRecurrenceTemplate extends DataClass
    implements Insertable<InvestmentRecurrenceTemplate> {
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String frequency;
  final String startsOn;
  final int? monthlyReferenceDay;
  final BigInt defaultAmountCentavos;
  final bool isActive;
  const InvestmentRecurrenceTemplate({
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.frequency,
    required this.startsOn,
    this.monthlyReferenceDay,
    required this.defaultAmountCentavos,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['frequency'] = Variable<String>(frequency);
    map['starts_on'] = Variable<String>(startsOn);
    if (!nullToAbsent || monthlyReferenceDay != null) {
      map['monthly_reference_day'] = Variable<int>(monthlyReferenceDay);
    }
    {
      map['default_amount_centavos'] = Variable<String>(
        $InvestmentRecurrenceTemplatesTable.$converterdefaultAmountCentavos
            .toSql(defaultAmountCentavos),
      );
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  InvestmentRecurrenceTemplatesCompanion toCompanion(bool nullToAbsent) {
    return InvestmentRecurrenceTemplatesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      frequency: Value(frequency),
      startsOn: Value(startsOn),
      monthlyReferenceDay: monthlyReferenceDay == null && nullToAbsent
          ? const Value.absent()
          : Value(monthlyReferenceDay),
      defaultAmountCentavos: Value(defaultAmountCentavos),
      isActive: Value(isActive),
    );
  }

  factory InvestmentRecurrenceTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvestmentRecurrenceTemplate(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      frequency: serializer.fromJson<String>(json['frequency']),
      startsOn: serializer.fromJson<String>(json['startsOn']),
      monthlyReferenceDay: serializer.fromJson<int?>(
        json['monthlyReferenceDay'],
      ),
      defaultAmountCentavos: serializer.fromJson<BigInt>(
        json['defaultAmountCentavos'],
      ),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'frequency': serializer.toJson<String>(frequency),
      'startsOn': serializer.toJson<String>(startsOn),
      'monthlyReferenceDay': serializer.toJson<int?>(monthlyReferenceDay),
      'defaultAmountCentavos': serializer.toJson<BigInt>(defaultAmountCentavos),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  InvestmentRecurrenceTemplate copyWith({
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
    String? frequency,
    String? startsOn,
    Value<int?> monthlyReferenceDay = const Value.absent(),
    BigInt? defaultAmountCentavos,
    bool? isActive,
  }) => InvestmentRecurrenceTemplate(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    frequency: frequency ?? this.frequency,
    startsOn: startsOn ?? this.startsOn,
    monthlyReferenceDay: monthlyReferenceDay.present
        ? monthlyReferenceDay.value
        : this.monthlyReferenceDay,
    defaultAmountCentavos: defaultAmountCentavos ?? this.defaultAmountCentavos,
    isActive: isActive ?? this.isActive,
  );
  InvestmentRecurrenceTemplate copyWithCompanion(
    InvestmentRecurrenceTemplatesCompanion data,
  ) {
    return InvestmentRecurrenceTemplate(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      startsOn: data.startsOn.present ? data.startsOn.value : this.startsOn,
      monthlyReferenceDay: data.monthlyReferenceDay.present
          ? data.monthlyReferenceDay.value
          : this.monthlyReferenceDay,
      defaultAmountCentavos: data.defaultAmountCentavos.present
          ? data.defaultAmountCentavos.value
          : this.defaultAmountCentavos,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvestmentRecurrenceTemplate(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('frequency: $frequency, ')
          ..write('startsOn: $startsOn, ')
          ..write('monthlyReferenceDay: $monthlyReferenceDay, ')
          ..write('defaultAmountCentavos: $defaultAmountCentavos, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    frequency,
    startsOn,
    monthlyReferenceDay,
    defaultAmountCentavos,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvestmentRecurrenceTemplate &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.frequency == this.frequency &&
          other.startsOn == this.startsOn &&
          other.monthlyReferenceDay == this.monthlyReferenceDay &&
          other.defaultAmountCentavos == this.defaultAmountCentavos &&
          other.isActive == this.isActive);
}

class InvestmentRecurrenceTemplatesCompanion
    extends UpdateCompanion<InvestmentRecurrenceTemplate> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String> frequency;
  final Value<String> startsOn;
  final Value<int?> monthlyReferenceDay;
  final Value<BigInt> defaultAmountCentavos;
  final Value<bool> isActive;
  final Value<int> rowid;
  const InvestmentRecurrenceTemplatesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.frequency = const Value.absent(),
    this.startsOn = const Value.absent(),
    this.monthlyReferenceDay = const Value.absent(),
    this.defaultAmountCentavos = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvestmentRecurrenceTemplatesCompanion.insert({
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    required String frequency,
    required String startsOn,
    this.monthlyReferenceDay = const Value.absent(),
    required BigInt defaultAmountCentavos,
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       frequency = Value(frequency),
       startsOn = Value(startsOn),
       defaultAmountCentavos = Value(defaultAmountCentavos);
  static Insertable<InvestmentRecurrenceTemplate> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? frequency,
    Expression<String>? startsOn,
    Expression<int>? monthlyReferenceDay,
    Expression<String>? defaultAmountCentavos,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (frequency != null) 'frequency': frequency,
      if (startsOn != null) 'starts_on': startsOn,
      if (monthlyReferenceDay != null)
        'monthly_reference_day': monthlyReferenceDay,
      if (defaultAmountCentavos != null)
        'default_amount_centavos': defaultAmountCentavos,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvestmentRecurrenceTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String>? frequency,
    Value<String>? startsOn,
    Value<int?>? monthlyReferenceDay,
    Value<BigInt>? defaultAmountCentavos,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return InvestmentRecurrenceTemplatesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      frequency: frequency ?? this.frequency,
      startsOn: startsOn ?? this.startsOn,
      monthlyReferenceDay: monthlyReferenceDay ?? this.monthlyReferenceDay,
      defaultAmountCentavos:
          defaultAmountCentavos ?? this.defaultAmountCentavos,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (startsOn.present) {
      map['starts_on'] = Variable<String>(startsOn.value);
    }
    if (monthlyReferenceDay.present) {
      map['monthly_reference_day'] = Variable<int>(monthlyReferenceDay.value);
    }
    if (defaultAmountCentavos.present) {
      map['default_amount_centavos'] = Variable<String>(
        $InvestmentRecurrenceTemplatesTable.$converterdefaultAmountCentavos
            .toSql(defaultAmountCentavos.value),
      );
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvestmentRecurrenceTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('frequency: $frequency, ')
          ..write('startsOn: $startsOn, ')
          ..write('monthlyReferenceDay: $monthlyReferenceDay, ')
          ..write('defaultAmountCentavos: $defaultAmountCentavos, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IncomeEntriesTable extends IncomeEntries
    with TableInfo<$IncomeEntriesTable, IncomeEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IncomeEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BigInt?, String> amountCentavos =
      GeneratedColumn<String>(
        'amount_centavos',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<BigInt?>($IncomeEntriesTable.$converteramountCentavosn);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subcategoryIdMeta = const VerificationMeta(
    'subcategoryId',
  );
  @override
  late final GeneratedColumn<String> subcategoryId = GeneratedColumn<String>(
    'subcategory_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceTemplateIdMeta =
      const VerificationMeta('recurrenceTemplateId');
  @override
  late final GeneratedColumn<String> recurrenceTemplateId =
      GeneratedColumn<String>(
        'recurrence_template_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _scheduledForDateMeta = const VerificationMeta(
    'scheduledForDate',
  );
  @override
  late final GeneratedColumn<String> scheduledForDate = GeneratedColumn<String>(
    'scheduled_for_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledPeriodIdMeta = const VerificationMeta(
    'scheduledPeriodId',
  );
  @override
  late final GeneratedColumn<String> scheduledPeriodId =
      GeneratedColumn<String>(
        'scheduled_period_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedOnMeta = const VerificationMeta(
    'receivedOn',
  );
  @override
  late final GeneratedColumn<String> receivedOn = GeneratedColumn<String>(
    'received_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountingPeriodIdMeta =
      const VerificationMeta('accountingPeriodId');
  @override
  late final GeneratedColumn<String> accountingPeriodId =
      GeneratedColumn<String>(
        'accounting_period_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    description,
    amountCentavos,
    status,
    categoryId,
    subcategoryId,
    recurrenceTemplateId,
    scheduledForDate,
    scheduledPeriodId,
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    receivedOn,
    accountingPeriodId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'income_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<IncomeEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('subcategory_id')) {
      context.handle(
        _subcategoryIdMeta,
        subcategoryId.isAcceptableOrUnknown(
          data['subcategory_id']!,
          _subcategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_template_id')) {
      context.handle(
        _recurrenceTemplateIdMeta,
        recurrenceTemplateId.isAcceptableOrUnknown(
          data['recurrence_template_id']!,
          _recurrenceTemplateIdMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_for_date')) {
      context.handle(
        _scheduledForDateMeta,
        scheduledForDate.isAcceptableOrUnknown(
          data['scheduled_for_date']!,
          _scheduledForDateMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_period_id')) {
      context.handle(
        _scheduledPeriodIdMeta,
        scheduledPeriodId.isAcceptableOrUnknown(
          data['scheduled_period_id']!,
          _scheduledPeriodIdMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('received_on')) {
      context.handle(
        _receivedOnMeta,
        receivedOn.isAcceptableOrUnknown(data['received_on']!, _receivedOnMeta),
      );
    }
    if (data.containsKey('accounting_period_id')) {
      context.handle(
        _accountingPeriodIdMeta,
        accountingPeriodId.isAcceptableOrUnknown(
          data['accounting_period_id']!,
          _accountingPeriodIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  IncomeEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IncomeEntry(
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      amountCentavos: $IncomeEntriesTable.$converteramountCentavosn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}amount_centavos'],
        ),
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      subcategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_id'],
      ),
      recurrenceTemplateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_template_id'],
      ),
      scheduledForDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_for_date'],
      ),
      scheduledPeriodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_period_id'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      receivedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}received_on'],
      ),
      accountingPeriodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accounting_period_id'],
      ),
    );
  }

  @override
  $IncomeEntriesTable createAlias(String alias) {
    return $IncomeEntriesTable(attachedDatabase, alias);
  }

  static TypeConverter<BigInt, String> $converteramountCentavos =
      const BigIntTextConverter();
  static TypeConverter<BigInt?, String?> $converteramountCentavosn =
      NullAwareTypeConverter.wrap($converteramountCentavos);
}

class IncomeEntry extends DataClass implements Insertable<IncomeEntry> {
  final String? description;
  final BigInt? amountCentavos;
  final String status;
  final String? categoryId;
  final String? subcategoryId;
  final String? recurrenceTemplateId;
  final String? scheduledForDate;
  final String? scheduledPeriodId;
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String? receivedOn;
  final String? accountingPeriodId;
  const IncomeEntry({
    this.description,
    this.amountCentavos,
    required this.status,
    this.categoryId,
    this.subcategoryId,
    this.recurrenceTemplateId,
    this.scheduledForDate,
    this.scheduledPeriodId,
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.receivedOn,
    this.accountingPeriodId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || amountCentavos != null) {
      map['amount_centavos'] = Variable<String>(
        $IncomeEntriesTable.$converteramountCentavosn.toSql(amountCentavos),
      );
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || subcategoryId != null) {
      map['subcategory_id'] = Variable<String>(subcategoryId);
    }
    if (!nullToAbsent || recurrenceTemplateId != null) {
      map['recurrence_template_id'] = Variable<String>(recurrenceTemplateId);
    }
    if (!nullToAbsent || scheduledForDate != null) {
      map['scheduled_for_date'] = Variable<String>(scheduledForDate);
    }
    if (!nullToAbsent || scheduledPeriodId != null) {
      map['scheduled_period_id'] = Variable<String>(scheduledPeriodId);
    }
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || receivedOn != null) {
      map['received_on'] = Variable<String>(receivedOn);
    }
    if (!nullToAbsent || accountingPeriodId != null) {
      map['accounting_period_id'] = Variable<String>(accountingPeriodId);
    }
    return map;
  }

  IncomeEntriesCompanion toCompanion(bool nullToAbsent) {
    return IncomeEntriesCompanion(
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      amountCentavos: amountCentavos == null && nullToAbsent
          ? const Value.absent()
          : Value(amountCentavos),
      status: Value(status),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      subcategoryId: subcategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryId),
      recurrenceTemplateId: recurrenceTemplateId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceTemplateId),
      scheduledForDate: scheduledForDate == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledForDate),
      scheduledPeriodId: scheduledPeriodId == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledPeriodId),
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      receivedOn: receivedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedOn),
      accountingPeriodId: accountingPeriodId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountingPeriodId),
    );
  }

  factory IncomeEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IncomeEntry(
      description: serializer.fromJson<String?>(json['description']),
      amountCentavos: serializer.fromJson<BigInt?>(json['amountCentavos']),
      status: serializer.fromJson<String>(json['status']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      subcategoryId: serializer.fromJson<String?>(json['subcategoryId']),
      recurrenceTemplateId: serializer.fromJson<String?>(
        json['recurrenceTemplateId'],
      ),
      scheduledForDate: serializer.fromJson<String?>(json['scheduledForDate']),
      scheduledPeriodId: serializer.fromJson<String?>(
        json['scheduledPeriodId'],
      ),
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      receivedOn: serializer.fromJson<String?>(json['receivedOn']),
      accountingPeriodId: serializer.fromJson<String?>(
        json['accountingPeriodId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'description': serializer.toJson<String?>(description),
      'amountCentavos': serializer.toJson<BigInt?>(amountCentavos),
      'status': serializer.toJson<String>(status),
      'categoryId': serializer.toJson<String?>(categoryId),
      'subcategoryId': serializer.toJson<String?>(subcategoryId),
      'recurrenceTemplateId': serializer.toJson<String?>(recurrenceTemplateId),
      'scheduledForDate': serializer.toJson<String?>(scheduledForDate),
      'scheduledPeriodId': serializer.toJson<String?>(scheduledPeriodId),
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'receivedOn': serializer.toJson<String?>(receivedOn),
      'accountingPeriodId': serializer.toJson<String?>(accountingPeriodId),
    };
  }

  IncomeEntry copyWith({
    Value<String?> description = const Value.absent(),
    Value<BigInt?> amountCentavos = const Value.absent(),
    String? status,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> subcategoryId = const Value.absent(),
    Value<String?> recurrenceTemplateId = const Value.absent(),
    Value<String?> scheduledForDate = const Value.absent(),
    Value<String?> scheduledPeriodId = const Value.absent(),
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
    Value<String?> receivedOn = const Value.absent(),
    Value<String?> accountingPeriodId = const Value.absent(),
  }) => IncomeEntry(
    description: description.present ? description.value : this.description,
    amountCentavos: amountCentavos.present
        ? amountCentavos.value
        : this.amountCentavos,
    status: status ?? this.status,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    subcategoryId: subcategoryId.present
        ? subcategoryId.value
        : this.subcategoryId,
    recurrenceTemplateId: recurrenceTemplateId.present
        ? recurrenceTemplateId.value
        : this.recurrenceTemplateId,
    scheduledForDate: scheduledForDate.present
        ? scheduledForDate.value
        : this.scheduledForDate,
    scheduledPeriodId: scheduledPeriodId.present
        ? scheduledPeriodId.value
        : this.scheduledPeriodId,
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    receivedOn: receivedOn.present ? receivedOn.value : this.receivedOn,
    accountingPeriodId: accountingPeriodId.present
        ? accountingPeriodId.value
        : this.accountingPeriodId,
  );
  IncomeEntry copyWithCompanion(IncomeEntriesCompanion data) {
    return IncomeEntry(
      description: data.description.present
          ? data.description.value
          : this.description,
      amountCentavos: data.amountCentavos.present
          ? data.amountCentavos.value
          : this.amountCentavos,
      status: data.status.present ? data.status.value : this.status,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      subcategoryId: data.subcategoryId.present
          ? data.subcategoryId.value
          : this.subcategoryId,
      recurrenceTemplateId: data.recurrenceTemplateId.present
          ? data.recurrenceTemplateId.value
          : this.recurrenceTemplateId,
      scheduledForDate: data.scheduledForDate.present
          ? data.scheduledForDate.value
          : this.scheduledForDate,
      scheduledPeriodId: data.scheduledPeriodId.present
          ? data.scheduledPeriodId.value
          : this.scheduledPeriodId,
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      receivedOn: data.receivedOn.present
          ? data.receivedOn.value
          : this.receivedOn,
      accountingPeriodId: data.accountingPeriodId.present
          ? data.accountingPeriodId.value
          : this.accountingPeriodId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IncomeEntry(')
          ..write('description: $description, ')
          ..write('amountCentavos: $amountCentavos, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('recurrenceTemplateId: $recurrenceTemplateId, ')
          ..write('scheduledForDate: $scheduledForDate, ')
          ..write('scheduledPeriodId: $scheduledPeriodId, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('receivedOn: $receivedOn, ')
          ..write('accountingPeriodId: $accountingPeriodId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    description,
    amountCentavos,
    status,
    categoryId,
    subcategoryId,
    recurrenceTemplateId,
    scheduledForDate,
    scheduledPeriodId,
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    receivedOn,
    accountingPeriodId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IncomeEntry &&
          other.description == this.description &&
          other.amountCentavos == this.amountCentavos &&
          other.status == this.status &&
          other.categoryId == this.categoryId &&
          other.subcategoryId == this.subcategoryId &&
          other.recurrenceTemplateId == this.recurrenceTemplateId &&
          other.scheduledForDate == this.scheduledForDate &&
          other.scheduledPeriodId == this.scheduledPeriodId &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.receivedOn == this.receivedOn &&
          other.accountingPeriodId == this.accountingPeriodId);
}

class IncomeEntriesCompanion extends UpdateCompanion<IncomeEntry> {
  final Value<String?> description;
  final Value<BigInt?> amountCentavos;
  final Value<String> status;
  final Value<String?> categoryId;
  final Value<String?> subcategoryId;
  final Value<String?> recurrenceTemplateId;
  final Value<String?> scheduledForDate;
  final Value<String?> scheduledPeriodId;
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> receivedOn;
  final Value<String?> accountingPeriodId;
  final Value<int> rowid;
  const IncomeEntriesCompanion({
    this.description = const Value.absent(),
    this.amountCentavos = const Value.absent(),
    this.status = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.recurrenceTemplateId = const Value.absent(),
    this.scheduledForDate = const Value.absent(),
    this.scheduledPeriodId = const Value.absent(),
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.receivedOn = const Value.absent(),
    this.accountingPeriodId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IncomeEntriesCompanion.insert({
    this.description = const Value.absent(),
    this.amountCentavos = const Value.absent(),
    required String status,
    this.categoryId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.recurrenceTemplateId = const Value.absent(),
    this.scheduledForDate = const Value.absent(),
    this.scheduledPeriodId = const Value.absent(),
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.receivedOn = const Value.absent(),
    this.accountingPeriodId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : status = Value(status),
       id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<IncomeEntry> custom({
    Expression<String>? description,
    Expression<String>? amountCentavos,
    Expression<String>? status,
    Expression<String>? categoryId,
    Expression<String>? subcategoryId,
    Expression<String>? recurrenceTemplateId,
    Expression<String>? scheduledForDate,
    Expression<String>? scheduledPeriodId,
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? receivedOn,
    Expression<String>? accountingPeriodId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (description != null) 'description': description,
      if (amountCentavos != null) 'amount_centavos': amountCentavos,
      if (status != null) 'status': status,
      if (categoryId != null) 'category_id': categoryId,
      if (subcategoryId != null) 'subcategory_id': subcategoryId,
      if (recurrenceTemplateId != null)
        'recurrence_template_id': recurrenceTemplateId,
      if (scheduledForDate != null) 'scheduled_for_date': scheduledForDate,
      if (scheduledPeriodId != null) 'scheduled_period_id': scheduledPeriodId,
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (receivedOn != null) 'received_on': receivedOn,
      if (accountingPeriodId != null)
        'accounting_period_id': accountingPeriodId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IncomeEntriesCompanion copyWith({
    Value<String?>? description,
    Value<BigInt?>? amountCentavos,
    Value<String>? status,
    Value<String?>? categoryId,
    Value<String?>? subcategoryId,
    Value<String?>? recurrenceTemplateId,
    Value<String?>? scheduledForDate,
    Value<String?>? scheduledPeriodId,
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? receivedOn,
    Value<String?>? accountingPeriodId,
    Value<int>? rowid,
  }) {
    return IncomeEntriesCompanion(
      description: description ?? this.description,
      amountCentavos: amountCentavos ?? this.amountCentavos,
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      recurrenceTemplateId: recurrenceTemplateId ?? this.recurrenceTemplateId,
      scheduledForDate: scheduledForDate ?? this.scheduledForDate,
      scheduledPeriodId: scheduledPeriodId ?? this.scheduledPeriodId,
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      receivedOn: receivedOn ?? this.receivedOn,
      accountingPeriodId: accountingPeriodId ?? this.accountingPeriodId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (amountCentavos.present) {
      map['amount_centavos'] = Variable<String>(
        $IncomeEntriesTable.$converteramountCentavosn.toSql(
          amountCentavos.value,
        ),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (subcategoryId.present) {
      map['subcategory_id'] = Variable<String>(subcategoryId.value);
    }
    if (recurrenceTemplateId.present) {
      map['recurrence_template_id'] = Variable<String>(
        recurrenceTemplateId.value,
      );
    }
    if (scheduledForDate.present) {
      map['scheduled_for_date'] = Variable<String>(scheduledForDate.value);
    }
    if (scheduledPeriodId.present) {
      map['scheduled_period_id'] = Variable<String>(scheduledPeriodId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (receivedOn.present) {
      map['received_on'] = Variable<String>(receivedOn.value);
    }
    if (accountingPeriodId.present) {
      map['accounting_period_id'] = Variable<String>(accountingPeriodId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IncomeEntriesCompanion(')
          ..write('description: $description, ')
          ..write('amountCentavos: $amountCentavos, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('recurrenceTemplateId: $recurrenceTemplateId, ')
          ..write('scheduledForDate: $scheduledForDate, ')
          ..write('scheduledPeriodId: $scheduledPeriodId, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('receivedOn: $receivedOn, ')
          ..write('accountingPeriodId: $accountingPeriodId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpenseEntriesTable extends ExpenseEntries
    with TableInfo<$ExpenseEntriesTable, ExpenseEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpenseEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BigInt?, String> amountCentavos =
      GeneratedColumn<String>(
        'amount_centavos',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<BigInt?>($ExpenseEntriesTable.$converteramountCentavosn);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subcategoryIdMeta = const VerificationMeta(
    'subcategoryId',
  );
  @override
  late final GeneratedColumn<String> subcategoryId = GeneratedColumn<String>(
    'subcategory_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceTemplateIdMeta =
      const VerificationMeta('recurrenceTemplateId');
  @override
  late final GeneratedColumn<String> recurrenceTemplateId =
      GeneratedColumn<String>(
        'recurrence_template_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _scheduledForDateMeta = const VerificationMeta(
    'scheduledForDate',
  );
  @override
  late final GeneratedColumn<String> scheduledForDate = GeneratedColumn<String>(
    'scheduled_for_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledPeriodIdMeta = const VerificationMeta(
    'scheduledPeriodId',
  );
  @override
  late final GeneratedColumn<String> scheduledPeriodId =
      GeneratedColumn<String>(
        'scheduled_period_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountingPeriodIdMeta =
      const VerificationMeta('accountingPeriodId');
  @override
  late final GeneratedColumn<String> accountingPeriodId =
      GeneratedColumn<String>(
        'accounting_period_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _competenceOnMeta = const VerificationMeta(
    'competenceOn',
  );
  @override
  late final GeneratedColumn<String> competenceOn = GeneratedColumn<String>(
    'competence_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueOnMeta = const VerificationMeta('dueOn');
  @override
  late final GeneratedColumn<String> dueOn = GeneratedColumn<String>(
    'due_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidOnMeta = const VerificationMeta('paidOn');
  @override
  late final GeneratedColumn<String> paidOn = GeneratedColumn<String>(
    'paid_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    description,
    amountCentavos,
    status,
    categoryId,
    subcategoryId,
    recurrenceTemplateId,
    scheduledForDate,
    scheduledPeriodId,
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    accountingPeriodId,
    competenceOn,
    dueOn,
    paidOn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('subcategory_id')) {
      context.handle(
        _subcategoryIdMeta,
        subcategoryId.isAcceptableOrUnknown(
          data['subcategory_id']!,
          _subcategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_template_id')) {
      context.handle(
        _recurrenceTemplateIdMeta,
        recurrenceTemplateId.isAcceptableOrUnknown(
          data['recurrence_template_id']!,
          _recurrenceTemplateIdMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_for_date')) {
      context.handle(
        _scheduledForDateMeta,
        scheduledForDate.isAcceptableOrUnknown(
          data['scheduled_for_date']!,
          _scheduledForDateMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_period_id')) {
      context.handle(
        _scheduledPeriodIdMeta,
        scheduledPeriodId.isAcceptableOrUnknown(
          data['scheduled_period_id']!,
          _scheduledPeriodIdMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('accounting_period_id')) {
      context.handle(
        _accountingPeriodIdMeta,
        accountingPeriodId.isAcceptableOrUnknown(
          data['accounting_period_id']!,
          _accountingPeriodIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accountingPeriodIdMeta);
    }
    if (data.containsKey('competence_on')) {
      context.handle(
        _competenceOnMeta,
        competenceOn.isAcceptableOrUnknown(
          data['competence_on']!,
          _competenceOnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_competenceOnMeta);
    }
    if (data.containsKey('due_on')) {
      context.handle(
        _dueOnMeta,
        dueOn.isAcceptableOrUnknown(data['due_on']!, _dueOnMeta),
      );
    }
    if (data.containsKey('paid_on')) {
      context.handle(
        _paidOnMeta,
        paidOn.isAcceptableOrUnknown(data['paid_on']!, _paidOnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  ExpenseEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseEntry(
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      amountCentavos: $ExpenseEntriesTable.$converteramountCentavosn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}amount_centavos'],
        ),
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      subcategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_id'],
      ),
      recurrenceTemplateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_template_id'],
      ),
      scheduledForDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_for_date'],
      ),
      scheduledPeriodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_period_id'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      accountingPeriodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accounting_period_id'],
      )!,
      competenceOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}competence_on'],
      )!,
      dueOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_on'],
      ),
      paidOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paid_on'],
      ),
    );
  }

  @override
  $ExpenseEntriesTable createAlias(String alias) {
    return $ExpenseEntriesTable(attachedDatabase, alias);
  }

  static TypeConverter<BigInt, String> $converteramountCentavos =
      const BigIntTextConverter();
  static TypeConverter<BigInt?, String?> $converteramountCentavosn =
      NullAwareTypeConverter.wrap($converteramountCentavos);
}

class ExpenseEntry extends DataClass implements Insertable<ExpenseEntry> {
  final String? description;
  final BigInt? amountCentavos;
  final String status;
  final String? categoryId;
  final String? subcategoryId;
  final String? recurrenceTemplateId;
  final String? scheduledForDate;
  final String? scheduledPeriodId;
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String accountingPeriodId;
  final String competenceOn;
  final String? dueOn;
  final String? paidOn;
  const ExpenseEntry({
    this.description,
    this.amountCentavos,
    required this.status,
    this.categoryId,
    this.subcategoryId,
    this.recurrenceTemplateId,
    this.scheduledForDate,
    this.scheduledPeriodId,
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.accountingPeriodId,
    required this.competenceOn,
    this.dueOn,
    this.paidOn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || amountCentavos != null) {
      map['amount_centavos'] = Variable<String>(
        $ExpenseEntriesTable.$converteramountCentavosn.toSql(amountCentavos),
      );
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || subcategoryId != null) {
      map['subcategory_id'] = Variable<String>(subcategoryId);
    }
    if (!nullToAbsent || recurrenceTemplateId != null) {
      map['recurrence_template_id'] = Variable<String>(recurrenceTemplateId);
    }
    if (!nullToAbsent || scheduledForDate != null) {
      map['scheduled_for_date'] = Variable<String>(scheduledForDate);
    }
    if (!nullToAbsent || scheduledPeriodId != null) {
      map['scheduled_period_id'] = Variable<String>(scheduledPeriodId);
    }
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['accounting_period_id'] = Variable<String>(accountingPeriodId);
    map['competence_on'] = Variable<String>(competenceOn);
    if (!nullToAbsent || dueOn != null) {
      map['due_on'] = Variable<String>(dueOn);
    }
    if (!nullToAbsent || paidOn != null) {
      map['paid_on'] = Variable<String>(paidOn);
    }
    return map;
  }

  ExpenseEntriesCompanion toCompanion(bool nullToAbsent) {
    return ExpenseEntriesCompanion(
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      amountCentavos: amountCentavos == null && nullToAbsent
          ? const Value.absent()
          : Value(amountCentavos),
      status: Value(status),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      subcategoryId: subcategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryId),
      recurrenceTemplateId: recurrenceTemplateId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceTemplateId),
      scheduledForDate: scheduledForDate == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledForDate),
      scheduledPeriodId: scheduledPeriodId == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledPeriodId),
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      accountingPeriodId: Value(accountingPeriodId),
      competenceOn: Value(competenceOn),
      dueOn: dueOn == null && nullToAbsent
          ? const Value.absent()
          : Value(dueOn),
      paidOn: paidOn == null && nullToAbsent
          ? const Value.absent()
          : Value(paidOn),
    );
  }

  factory ExpenseEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseEntry(
      description: serializer.fromJson<String?>(json['description']),
      amountCentavos: serializer.fromJson<BigInt?>(json['amountCentavos']),
      status: serializer.fromJson<String>(json['status']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      subcategoryId: serializer.fromJson<String?>(json['subcategoryId']),
      recurrenceTemplateId: serializer.fromJson<String?>(
        json['recurrenceTemplateId'],
      ),
      scheduledForDate: serializer.fromJson<String?>(json['scheduledForDate']),
      scheduledPeriodId: serializer.fromJson<String?>(
        json['scheduledPeriodId'],
      ),
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      accountingPeriodId: serializer.fromJson<String>(
        json['accountingPeriodId'],
      ),
      competenceOn: serializer.fromJson<String>(json['competenceOn']),
      dueOn: serializer.fromJson<String?>(json['dueOn']),
      paidOn: serializer.fromJson<String?>(json['paidOn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'description': serializer.toJson<String?>(description),
      'amountCentavos': serializer.toJson<BigInt?>(amountCentavos),
      'status': serializer.toJson<String>(status),
      'categoryId': serializer.toJson<String?>(categoryId),
      'subcategoryId': serializer.toJson<String?>(subcategoryId),
      'recurrenceTemplateId': serializer.toJson<String?>(recurrenceTemplateId),
      'scheduledForDate': serializer.toJson<String?>(scheduledForDate),
      'scheduledPeriodId': serializer.toJson<String?>(scheduledPeriodId),
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'accountingPeriodId': serializer.toJson<String>(accountingPeriodId),
      'competenceOn': serializer.toJson<String>(competenceOn),
      'dueOn': serializer.toJson<String?>(dueOn),
      'paidOn': serializer.toJson<String?>(paidOn),
    };
  }

  ExpenseEntry copyWith({
    Value<String?> description = const Value.absent(),
    Value<BigInt?> amountCentavos = const Value.absent(),
    String? status,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> subcategoryId = const Value.absent(),
    Value<String?> recurrenceTemplateId = const Value.absent(),
    Value<String?> scheduledForDate = const Value.absent(),
    Value<String?> scheduledPeriodId = const Value.absent(),
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
    String? accountingPeriodId,
    String? competenceOn,
    Value<String?> dueOn = const Value.absent(),
    Value<String?> paidOn = const Value.absent(),
  }) => ExpenseEntry(
    description: description.present ? description.value : this.description,
    amountCentavos: amountCentavos.present
        ? amountCentavos.value
        : this.amountCentavos,
    status: status ?? this.status,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    subcategoryId: subcategoryId.present
        ? subcategoryId.value
        : this.subcategoryId,
    recurrenceTemplateId: recurrenceTemplateId.present
        ? recurrenceTemplateId.value
        : this.recurrenceTemplateId,
    scheduledForDate: scheduledForDate.present
        ? scheduledForDate.value
        : this.scheduledForDate,
    scheduledPeriodId: scheduledPeriodId.present
        ? scheduledPeriodId.value
        : this.scheduledPeriodId,
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    accountingPeriodId: accountingPeriodId ?? this.accountingPeriodId,
    competenceOn: competenceOn ?? this.competenceOn,
    dueOn: dueOn.present ? dueOn.value : this.dueOn,
    paidOn: paidOn.present ? paidOn.value : this.paidOn,
  );
  ExpenseEntry copyWithCompanion(ExpenseEntriesCompanion data) {
    return ExpenseEntry(
      description: data.description.present
          ? data.description.value
          : this.description,
      amountCentavos: data.amountCentavos.present
          ? data.amountCentavos.value
          : this.amountCentavos,
      status: data.status.present ? data.status.value : this.status,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      subcategoryId: data.subcategoryId.present
          ? data.subcategoryId.value
          : this.subcategoryId,
      recurrenceTemplateId: data.recurrenceTemplateId.present
          ? data.recurrenceTemplateId.value
          : this.recurrenceTemplateId,
      scheduledForDate: data.scheduledForDate.present
          ? data.scheduledForDate.value
          : this.scheduledForDate,
      scheduledPeriodId: data.scheduledPeriodId.present
          ? data.scheduledPeriodId.value
          : this.scheduledPeriodId,
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      accountingPeriodId: data.accountingPeriodId.present
          ? data.accountingPeriodId.value
          : this.accountingPeriodId,
      competenceOn: data.competenceOn.present
          ? data.competenceOn.value
          : this.competenceOn,
      dueOn: data.dueOn.present ? data.dueOn.value : this.dueOn,
      paidOn: data.paidOn.present ? data.paidOn.value : this.paidOn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseEntry(')
          ..write('description: $description, ')
          ..write('amountCentavos: $amountCentavos, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('recurrenceTemplateId: $recurrenceTemplateId, ')
          ..write('scheduledForDate: $scheduledForDate, ')
          ..write('scheduledPeriodId: $scheduledPeriodId, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('accountingPeriodId: $accountingPeriodId, ')
          ..write('competenceOn: $competenceOn, ')
          ..write('dueOn: $dueOn, ')
          ..write('paidOn: $paidOn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    description,
    amountCentavos,
    status,
    categoryId,
    subcategoryId,
    recurrenceTemplateId,
    scheduledForDate,
    scheduledPeriodId,
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    accountingPeriodId,
    competenceOn,
    dueOn,
    paidOn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseEntry &&
          other.description == this.description &&
          other.amountCentavos == this.amountCentavos &&
          other.status == this.status &&
          other.categoryId == this.categoryId &&
          other.subcategoryId == this.subcategoryId &&
          other.recurrenceTemplateId == this.recurrenceTemplateId &&
          other.scheduledForDate == this.scheduledForDate &&
          other.scheduledPeriodId == this.scheduledPeriodId &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.accountingPeriodId == this.accountingPeriodId &&
          other.competenceOn == this.competenceOn &&
          other.dueOn == this.dueOn &&
          other.paidOn == this.paidOn);
}

class ExpenseEntriesCompanion extends UpdateCompanion<ExpenseEntry> {
  final Value<String?> description;
  final Value<BigInt?> amountCentavos;
  final Value<String> status;
  final Value<String?> categoryId;
  final Value<String?> subcategoryId;
  final Value<String?> recurrenceTemplateId;
  final Value<String?> scheduledForDate;
  final Value<String?> scheduledPeriodId;
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String> accountingPeriodId;
  final Value<String> competenceOn;
  final Value<String?> dueOn;
  final Value<String?> paidOn;
  final Value<int> rowid;
  const ExpenseEntriesCompanion({
    this.description = const Value.absent(),
    this.amountCentavos = const Value.absent(),
    this.status = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.recurrenceTemplateId = const Value.absent(),
    this.scheduledForDate = const Value.absent(),
    this.scheduledPeriodId = const Value.absent(),
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.accountingPeriodId = const Value.absent(),
    this.competenceOn = const Value.absent(),
    this.dueOn = const Value.absent(),
    this.paidOn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpenseEntriesCompanion.insert({
    this.description = const Value.absent(),
    this.amountCentavos = const Value.absent(),
    required String status,
    this.categoryId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.recurrenceTemplateId = const Value.absent(),
    this.scheduledForDate = const Value.absent(),
    this.scheduledPeriodId = const Value.absent(),
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    required String accountingPeriodId,
    required String competenceOn,
    this.dueOn = const Value.absent(),
    this.paidOn = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : status = Value(status),
       id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       accountingPeriodId = Value(accountingPeriodId),
       competenceOn = Value(competenceOn);
  static Insertable<ExpenseEntry> custom({
    Expression<String>? description,
    Expression<String>? amountCentavos,
    Expression<String>? status,
    Expression<String>? categoryId,
    Expression<String>? subcategoryId,
    Expression<String>? recurrenceTemplateId,
    Expression<String>? scheduledForDate,
    Expression<String>? scheduledPeriodId,
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? accountingPeriodId,
    Expression<String>? competenceOn,
    Expression<String>? dueOn,
    Expression<String>? paidOn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (description != null) 'description': description,
      if (amountCentavos != null) 'amount_centavos': amountCentavos,
      if (status != null) 'status': status,
      if (categoryId != null) 'category_id': categoryId,
      if (subcategoryId != null) 'subcategory_id': subcategoryId,
      if (recurrenceTemplateId != null)
        'recurrence_template_id': recurrenceTemplateId,
      if (scheduledForDate != null) 'scheduled_for_date': scheduledForDate,
      if (scheduledPeriodId != null) 'scheduled_period_id': scheduledPeriodId,
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (accountingPeriodId != null)
        'accounting_period_id': accountingPeriodId,
      if (competenceOn != null) 'competence_on': competenceOn,
      if (dueOn != null) 'due_on': dueOn,
      if (paidOn != null) 'paid_on': paidOn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpenseEntriesCompanion copyWith({
    Value<String?>? description,
    Value<BigInt?>? amountCentavos,
    Value<String>? status,
    Value<String?>? categoryId,
    Value<String?>? subcategoryId,
    Value<String?>? recurrenceTemplateId,
    Value<String?>? scheduledForDate,
    Value<String?>? scheduledPeriodId,
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String>? accountingPeriodId,
    Value<String>? competenceOn,
    Value<String?>? dueOn,
    Value<String?>? paidOn,
    Value<int>? rowid,
  }) {
    return ExpenseEntriesCompanion(
      description: description ?? this.description,
      amountCentavos: amountCentavos ?? this.amountCentavos,
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      recurrenceTemplateId: recurrenceTemplateId ?? this.recurrenceTemplateId,
      scheduledForDate: scheduledForDate ?? this.scheduledForDate,
      scheduledPeriodId: scheduledPeriodId ?? this.scheduledPeriodId,
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      accountingPeriodId: accountingPeriodId ?? this.accountingPeriodId,
      competenceOn: competenceOn ?? this.competenceOn,
      dueOn: dueOn ?? this.dueOn,
      paidOn: paidOn ?? this.paidOn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (amountCentavos.present) {
      map['amount_centavos'] = Variable<String>(
        $ExpenseEntriesTable.$converteramountCentavosn.toSql(
          amountCentavos.value,
        ),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (subcategoryId.present) {
      map['subcategory_id'] = Variable<String>(subcategoryId.value);
    }
    if (recurrenceTemplateId.present) {
      map['recurrence_template_id'] = Variable<String>(
        recurrenceTemplateId.value,
      );
    }
    if (scheduledForDate.present) {
      map['scheduled_for_date'] = Variable<String>(scheduledForDate.value);
    }
    if (scheduledPeriodId.present) {
      map['scheduled_period_id'] = Variable<String>(scheduledPeriodId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (accountingPeriodId.present) {
      map['accounting_period_id'] = Variable<String>(accountingPeriodId.value);
    }
    if (competenceOn.present) {
      map['competence_on'] = Variable<String>(competenceOn.value);
    }
    if (dueOn.present) {
      map['due_on'] = Variable<String>(dueOn.value);
    }
    if (paidOn.present) {
      map['paid_on'] = Variable<String>(paidOn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseEntriesCompanion(')
          ..write('description: $description, ')
          ..write('amountCentavos: $amountCentavos, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('recurrenceTemplateId: $recurrenceTemplateId, ')
          ..write('scheduledForDate: $scheduledForDate, ')
          ..write('scheduledPeriodId: $scheduledPeriodId, ')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('accountingPeriodId: $accountingPeriodId, ')
          ..write('competenceOn: $competenceOn, ')
          ..write('dueOn: $dueOn, ')
          ..write('paidOn: $paidOn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvestmentAllocationsTable extends InvestmentAllocations
    with TableInfo<$InvestmentAllocationsTable, InvestmentAllocation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvestmentAllocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BigInt, String> amountCentavos =
      GeneratedColumn<String>(
        'amount_centavos',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BigInt>(
        $InvestmentAllocationsTable.$converteramountCentavos,
      );
  static const VerificationMeta _allocatedOnMeta = const VerificationMeta(
    'allocatedOn',
  );
  @override
  late final GeneratedColumn<String> allocatedOn = GeneratedColumn<String>(
    'allocated_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountingPeriodIdMeta =
      const VerificationMeta('accountingPeriodId');
  @override
  late final GeneratedColumn<String> accountingPeriodId =
      GeneratedColumn<String>(
        'accounting_period_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _cancelledAtMeta = const VerificationMeta(
    'cancelledAt',
  );
  @override
  late final GeneratedColumn<String> cancelledAt = GeneratedColumn<String>(
    'cancelled_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceTemplateIdMeta =
      const VerificationMeta('recurrenceTemplateId');
  @override
  late final GeneratedColumn<String> recurrenceTemplateId =
      GeneratedColumn<String>(
        'recurrence_template_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _scheduledForDateMeta = const VerificationMeta(
    'scheduledForDate',
  );
  @override
  late final GeneratedColumn<String> scheduledForDate = GeneratedColumn<String>(
    'scheduled_for_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledPeriodIdMeta = const VerificationMeta(
    'scheduledPeriodId',
  );
  @override
  late final GeneratedColumn<String> scheduledPeriodId =
      GeneratedColumn<String>(
        'scheduled_period_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    amountCentavos,
    allocatedOn,
    accountingPeriodId,
    cancelledAt,
    recurrenceTemplateId,
    scheduledForDate,
    scheduledPeriodId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'investment_allocations';
  @override
  VerificationContext validateIntegrity(
    Insertable<InvestmentAllocation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('allocated_on')) {
      context.handle(
        _allocatedOnMeta,
        allocatedOn.isAcceptableOrUnknown(
          data['allocated_on']!,
          _allocatedOnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allocatedOnMeta);
    }
    if (data.containsKey('accounting_period_id')) {
      context.handle(
        _accountingPeriodIdMeta,
        accountingPeriodId.isAcceptableOrUnknown(
          data['accounting_period_id']!,
          _accountingPeriodIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accountingPeriodIdMeta);
    }
    if (data.containsKey('cancelled_at')) {
      context.handle(
        _cancelledAtMeta,
        cancelledAt.isAcceptableOrUnknown(
          data['cancelled_at']!,
          _cancelledAtMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_template_id')) {
      context.handle(
        _recurrenceTemplateIdMeta,
        recurrenceTemplateId.isAcceptableOrUnknown(
          data['recurrence_template_id']!,
          _recurrenceTemplateIdMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_for_date')) {
      context.handle(
        _scheduledForDateMeta,
        scheduledForDate.isAcceptableOrUnknown(
          data['scheduled_for_date']!,
          _scheduledForDateMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_period_id')) {
      context.handle(
        _scheduledPeriodIdMeta,
        scheduledPeriodId.isAcceptableOrUnknown(
          data['scheduled_period_id']!,
          _scheduledPeriodIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  InvestmentAllocation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvestmentAllocation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      amountCentavos: $InvestmentAllocationsTable.$converteramountCentavos
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}amount_centavos'],
            )!,
          ),
      allocatedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allocated_on'],
      )!,
      accountingPeriodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accounting_period_id'],
      )!,
      cancelledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cancelled_at'],
      ),
      recurrenceTemplateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_template_id'],
      ),
      scheduledForDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_for_date'],
      ),
      scheduledPeriodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_period_id'],
      ),
    );
  }

  @override
  $InvestmentAllocationsTable createAlias(String alias) {
    return $InvestmentAllocationsTable(attachedDatabase, alias);
  }

  static TypeConverter<BigInt, String> $converteramountCentavos =
      const BigIntTextConverter();
}

class InvestmentAllocation extends DataClass
    implements Insertable<InvestmentAllocation> {
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  final BigInt amountCentavos;
  final String allocatedOn;
  final String accountingPeriodId;
  final String? cancelledAt;
  final String? recurrenceTemplateId;
  final String? scheduledForDate;
  final String? scheduledPeriodId;
  const InvestmentAllocation({
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.amountCentavos,
    required this.allocatedOn,
    required this.accountingPeriodId,
    this.cancelledAt,
    this.recurrenceTemplateId,
    this.scheduledForDate,
    this.scheduledPeriodId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    {
      map['amount_centavos'] = Variable<String>(
        $InvestmentAllocationsTable.$converteramountCentavos.toSql(
          amountCentavos,
        ),
      );
    }
    map['allocated_on'] = Variable<String>(allocatedOn);
    map['accounting_period_id'] = Variable<String>(accountingPeriodId);
    if (!nullToAbsent || cancelledAt != null) {
      map['cancelled_at'] = Variable<String>(cancelledAt);
    }
    if (!nullToAbsent || recurrenceTemplateId != null) {
      map['recurrence_template_id'] = Variable<String>(recurrenceTemplateId);
    }
    if (!nullToAbsent || scheduledForDate != null) {
      map['scheduled_for_date'] = Variable<String>(scheduledForDate);
    }
    if (!nullToAbsent || scheduledPeriodId != null) {
      map['scheduled_period_id'] = Variable<String>(scheduledPeriodId);
    }
    return map;
  }

  InvestmentAllocationsCompanion toCompanion(bool nullToAbsent) {
    return InvestmentAllocationsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      amountCentavos: Value(amountCentavos),
      allocatedOn: Value(allocatedOn),
      accountingPeriodId: Value(accountingPeriodId),
      cancelledAt: cancelledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledAt),
      recurrenceTemplateId: recurrenceTemplateId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceTemplateId),
      scheduledForDate: scheduledForDate == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledForDate),
      scheduledPeriodId: scheduledPeriodId == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledPeriodId),
    );
  }

  factory InvestmentAllocation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvestmentAllocation(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      amountCentavos: serializer.fromJson<BigInt>(json['amountCentavos']),
      allocatedOn: serializer.fromJson<String>(json['allocatedOn']),
      accountingPeriodId: serializer.fromJson<String>(
        json['accountingPeriodId'],
      ),
      cancelledAt: serializer.fromJson<String?>(json['cancelledAt']),
      recurrenceTemplateId: serializer.fromJson<String?>(
        json['recurrenceTemplateId'],
      ),
      scheduledForDate: serializer.fromJson<String?>(json['scheduledForDate']),
      scheduledPeriodId: serializer.fromJson<String?>(
        json['scheduledPeriodId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'amountCentavos': serializer.toJson<BigInt>(amountCentavos),
      'allocatedOn': serializer.toJson<String>(allocatedOn),
      'accountingPeriodId': serializer.toJson<String>(accountingPeriodId),
      'cancelledAt': serializer.toJson<String?>(cancelledAt),
      'recurrenceTemplateId': serializer.toJson<String?>(recurrenceTemplateId),
      'scheduledForDate': serializer.toJson<String?>(scheduledForDate),
      'scheduledPeriodId': serializer.toJson<String?>(scheduledPeriodId),
    };
  }

  InvestmentAllocation copyWith({
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
    BigInt? amountCentavos,
    String? allocatedOn,
    String? accountingPeriodId,
    Value<String?> cancelledAt = const Value.absent(),
    Value<String?> recurrenceTemplateId = const Value.absent(),
    Value<String?> scheduledForDate = const Value.absent(),
    Value<String?> scheduledPeriodId = const Value.absent(),
  }) => InvestmentAllocation(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    amountCentavos: amountCentavos ?? this.amountCentavos,
    allocatedOn: allocatedOn ?? this.allocatedOn,
    accountingPeriodId: accountingPeriodId ?? this.accountingPeriodId,
    cancelledAt: cancelledAt.present ? cancelledAt.value : this.cancelledAt,
    recurrenceTemplateId: recurrenceTemplateId.present
        ? recurrenceTemplateId.value
        : this.recurrenceTemplateId,
    scheduledForDate: scheduledForDate.present
        ? scheduledForDate.value
        : this.scheduledForDate,
    scheduledPeriodId: scheduledPeriodId.present
        ? scheduledPeriodId.value
        : this.scheduledPeriodId,
  );
  InvestmentAllocation copyWithCompanion(InvestmentAllocationsCompanion data) {
    return InvestmentAllocation(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      amountCentavos: data.amountCentavos.present
          ? data.amountCentavos.value
          : this.amountCentavos,
      allocatedOn: data.allocatedOn.present
          ? data.allocatedOn.value
          : this.allocatedOn,
      accountingPeriodId: data.accountingPeriodId.present
          ? data.accountingPeriodId.value
          : this.accountingPeriodId,
      cancelledAt: data.cancelledAt.present
          ? data.cancelledAt.value
          : this.cancelledAt,
      recurrenceTemplateId: data.recurrenceTemplateId.present
          ? data.recurrenceTemplateId.value
          : this.recurrenceTemplateId,
      scheduledForDate: data.scheduledForDate.present
          ? data.scheduledForDate.value
          : this.scheduledForDate,
      scheduledPeriodId: data.scheduledPeriodId.present
          ? data.scheduledPeriodId.value
          : this.scheduledPeriodId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvestmentAllocation(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('amountCentavos: $amountCentavos, ')
          ..write('allocatedOn: $allocatedOn, ')
          ..write('accountingPeriodId: $accountingPeriodId, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('recurrenceTemplateId: $recurrenceTemplateId, ')
          ..write('scheduledForDate: $scheduledForDate, ')
          ..write('scheduledPeriodId: $scheduledPeriodId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    amountCentavos,
    allocatedOn,
    accountingPeriodId,
    cancelledAt,
    recurrenceTemplateId,
    scheduledForDate,
    scheduledPeriodId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvestmentAllocation &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.amountCentavos == this.amountCentavos &&
          other.allocatedOn == this.allocatedOn &&
          other.accountingPeriodId == this.accountingPeriodId &&
          other.cancelledAt == this.cancelledAt &&
          other.recurrenceTemplateId == this.recurrenceTemplateId &&
          other.scheduledForDate == this.scheduledForDate &&
          other.scheduledPeriodId == this.scheduledPeriodId);
}

class InvestmentAllocationsCompanion
    extends UpdateCompanion<InvestmentAllocation> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<BigInt> amountCentavos;
  final Value<String> allocatedOn;
  final Value<String> accountingPeriodId;
  final Value<String?> cancelledAt;
  final Value<String?> recurrenceTemplateId;
  final Value<String?> scheduledForDate;
  final Value<String?> scheduledPeriodId;
  final Value<int> rowid;
  const InvestmentAllocationsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.amountCentavos = const Value.absent(),
    this.allocatedOn = const Value.absent(),
    this.accountingPeriodId = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.recurrenceTemplateId = const Value.absent(),
    this.scheduledForDate = const Value.absent(),
    this.scheduledPeriodId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvestmentAllocationsCompanion.insert({
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    required BigInt amountCentavos,
    required String allocatedOn,
    required String accountingPeriodId,
    this.cancelledAt = const Value.absent(),
    this.recurrenceTemplateId = const Value.absent(),
    this.scheduledForDate = const Value.absent(),
    this.scheduledPeriodId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       amountCentavos = Value(amountCentavos),
       allocatedOn = Value(allocatedOn),
       accountingPeriodId = Value(accountingPeriodId);
  static Insertable<InvestmentAllocation> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? amountCentavos,
    Expression<String>? allocatedOn,
    Expression<String>? accountingPeriodId,
    Expression<String>? cancelledAt,
    Expression<String>? recurrenceTemplateId,
    Expression<String>? scheduledForDate,
    Expression<String>? scheduledPeriodId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (amountCentavos != null) 'amount_centavos': amountCentavos,
      if (allocatedOn != null) 'allocated_on': allocatedOn,
      if (accountingPeriodId != null)
        'accounting_period_id': accountingPeriodId,
      if (cancelledAt != null) 'cancelled_at': cancelledAt,
      if (recurrenceTemplateId != null)
        'recurrence_template_id': recurrenceTemplateId,
      if (scheduledForDate != null) 'scheduled_for_date': scheduledForDate,
      if (scheduledPeriodId != null) 'scheduled_period_id': scheduledPeriodId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvestmentAllocationsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<BigInt>? amountCentavos,
    Value<String>? allocatedOn,
    Value<String>? accountingPeriodId,
    Value<String?>? cancelledAt,
    Value<String?>? recurrenceTemplateId,
    Value<String?>? scheduledForDate,
    Value<String?>? scheduledPeriodId,
    Value<int>? rowid,
  }) {
    return InvestmentAllocationsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      amountCentavos: amountCentavos ?? this.amountCentavos,
      allocatedOn: allocatedOn ?? this.allocatedOn,
      accountingPeriodId: accountingPeriodId ?? this.accountingPeriodId,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      recurrenceTemplateId: recurrenceTemplateId ?? this.recurrenceTemplateId,
      scheduledForDate: scheduledForDate ?? this.scheduledForDate,
      scheduledPeriodId: scheduledPeriodId ?? this.scheduledPeriodId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (amountCentavos.present) {
      map['amount_centavos'] = Variable<String>(
        $InvestmentAllocationsTable.$converteramountCentavos.toSql(
          amountCentavos.value,
        ),
      );
    }
    if (allocatedOn.present) {
      map['allocated_on'] = Variable<String>(allocatedOn.value);
    }
    if (accountingPeriodId.present) {
      map['accounting_period_id'] = Variable<String>(accountingPeriodId.value);
    }
    if (cancelledAt.present) {
      map['cancelled_at'] = Variable<String>(cancelledAt.value);
    }
    if (recurrenceTemplateId.present) {
      map['recurrence_template_id'] = Variable<String>(
        recurrenceTemplateId.value,
      );
    }
    if (scheduledForDate.present) {
      map['scheduled_for_date'] = Variable<String>(scheduledForDate.value);
    }
    if (scheduledPeriodId.present) {
      map['scheduled_period_id'] = Variable<String>(scheduledPeriodId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvestmentAllocationsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('amountCentavos: $amountCentavos, ')
          ..write('allocatedOn: $allocatedOn, ')
          ..write('accountingPeriodId: $accountingPeriodId, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('recurrenceTemplateId: $recurrenceTemplateId, ')
          ..write('scheduledForDate: $scheduledForDate, ')
          ..write('scheduledPeriodId: $scheduledPeriodId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditEventsTable extends AuditEvents
    with TableInfo<$AuditEventsTable, AuditEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oldSnapshotJsonMeta = const VerificationMeta(
    'oldSnapshotJson',
  );
  @override
  late final GeneratedColumn<String> oldSnapshotJson = GeneratedColumn<String>(
    'old_snapshot_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _newSnapshotJsonMeta = const VerificationMeta(
    'newSnapshotJson',
  );
  @override
  late final GeneratedColumn<String> newSnapshotJson = GeneratedColumn<String>(
    'new_snapshot_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    entityType,
    entityId,
    operation,
    actorId,
    occurredAt,
    oldSnapshotJson,
    newSnapshotJson,
    operationId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('old_snapshot_json')) {
      context.handle(
        _oldSnapshotJsonMeta,
        oldSnapshotJson.isAcceptableOrUnknown(
          data['old_snapshot_json']!,
          _oldSnapshotJsonMeta,
        ),
      );
    }
    if (data.containsKey('new_snapshot_json')) {
      context.handle(
        _newSnapshotJsonMeta,
        newSnapshotJson.isAcceptableOrUnknown(
          data['new_snapshot_json']!,
          _newSnapshotJsonMeta,
        ),
      );
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  AuditEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_at'],
      )!,
      oldSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_snapshot_json'],
      ),
      newSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_snapshot_json'],
      ),
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
    );
  }

  @override
  $AuditEventsTable createAlias(String alias) {
    return $AuditEventsTable(attachedDatabase, alias);
  }
}

class AuditEvent extends DataClass implements Insertable<AuditEvent> {
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String entityType;
  final String entityId;
  final String operation;
  final String? actorId;
  final String occurredAt;
  final String? oldSnapshotJson;
  final String? newSnapshotJson;
  final String operationId;
  const AuditEvent({
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.actorId,
    required this.occurredAt,
    this.oldSnapshotJson,
    this.newSnapshotJson,
    required this.operationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<String>(actorId);
    }
    map['occurred_at'] = Variable<String>(occurredAt);
    if (!nullToAbsent || oldSnapshotJson != null) {
      map['old_snapshot_json'] = Variable<String>(oldSnapshotJson);
    }
    if (!nullToAbsent || newSnapshotJson != null) {
      map['new_snapshot_json'] = Variable<String>(newSnapshotJson);
    }
    map['operation_id'] = Variable<String>(operationId);
    return map;
  }

  AuditEventsCompanion toCompanion(bool nullToAbsent) {
    return AuditEventsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      occurredAt: Value(occurredAt),
      oldSnapshotJson: oldSnapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(oldSnapshotJson),
      newSnapshotJson: newSnapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(newSnapshotJson),
      operationId: Value(operationId),
    );
  }

  factory AuditEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditEvent(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      actorId: serializer.fromJson<String?>(json['actorId']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      oldSnapshotJson: serializer.fromJson<String?>(json['oldSnapshotJson']),
      newSnapshotJson: serializer.fromJson<String?>(json['newSnapshotJson']),
      operationId: serializer.fromJson<String>(json['operationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'actorId': serializer.toJson<String?>(actorId),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'oldSnapshotJson': serializer.toJson<String?>(oldSnapshotJson),
      'newSnapshotJson': serializer.toJson<String?>(newSnapshotJson),
      'operationId': serializer.toJson<String>(operationId),
    };
  }

  AuditEvent copyWith({
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
    String? entityType,
    String? entityId,
    String? operation,
    Value<String?> actorId = const Value.absent(),
    String? occurredAt,
    Value<String?> oldSnapshotJson = const Value.absent(),
    Value<String?> newSnapshotJson = const Value.absent(),
    String? operationId,
  }) => AuditEvent(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    actorId: actorId.present ? actorId.value : this.actorId,
    occurredAt: occurredAt ?? this.occurredAt,
    oldSnapshotJson: oldSnapshotJson.present
        ? oldSnapshotJson.value
        : this.oldSnapshotJson,
    newSnapshotJson: newSnapshotJson.present
        ? newSnapshotJson.value
        : this.newSnapshotJson,
    operationId: operationId ?? this.operationId,
  );
  AuditEvent copyWithCompanion(AuditEventsCompanion data) {
    return AuditEvent(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      oldSnapshotJson: data.oldSnapshotJson.present
          ? data.oldSnapshotJson.value
          : this.oldSnapshotJson,
      newSnapshotJson: data.newSnapshotJson.present
          ? data.newSnapshotJson.value
          : this.newSnapshotJson,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditEvent(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('actorId: $actorId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('oldSnapshotJson: $oldSnapshotJson, ')
          ..write('newSnapshotJson: $newSnapshotJson, ')
          ..write('operationId: $operationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    entityType,
    entityId,
    operation,
    actorId,
    occurredAt,
    oldSnapshotJson,
    newSnapshotJson,
    operationId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditEvent &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.actorId == this.actorId &&
          other.occurredAt == this.occurredAt &&
          other.oldSnapshotJson == this.oldSnapshotJson &&
          other.newSnapshotJson == this.newSnapshotJson &&
          other.operationId == this.operationId);
}

class AuditEventsCompanion extends UpdateCompanion<AuditEvent> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String?> actorId;
  final Value<String> occurredAt;
  final Value<String?> oldSnapshotJson;
  final Value<String?> newSnapshotJson;
  final Value<String> operationId;
  final Value<int> rowid;
  const AuditEventsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.actorId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.oldSnapshotJson = const Value.absent(),
    this.newSnapshotJson = const Value.absent(),
    this.operationId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditEventsCompanion.insert({
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    required String entityType,
    required String entityId,
    required String operation,
    this.actorId = const Value.absent(),
    required String occurredAt,
    this.oldSnapshotJson = const Value.absent(),
    this.newSnapshotJson = const Value.absent(),
    required String operationId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       occurredAt = Value(occurredAt),
       operationId = Value(operationId);
  static Insertable<AuditEvent> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? actorId,
    Expression<String>? occurredAt,
    Expression<String>? oldSnapshotJson,
    Expression<String>? newSnapshotJson,
    Expression<String>? operationId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (actorId != null) 'actor_id': actorId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (oldSnapshotJson != null) 'old_snapshot_json': oldSnapshotJson,
      if (newSnapshotJson != null) 'new_snapshot_json': newSnapshotJson,
      if (operationId != null) 'operation_id': operationId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String?>? actorId,
    Value<String>? occurredAt,
    Value<String?>? oldSnapshotJson,
    Value<String?>? newSnapshotJson,
    Value<String>? operationId,
    Value<int>? rowid,
  }) {
    return AuditEventsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      actorId: actorId ?? this.actorId,
      occurredAt: occurredAt ?? this.occurredAt,
      oldSnapshotJson: oldSnapshotJson ?? this.oldSnapshotJson,
      newSnapshotJson: newSnapshotJson ?? this.newSnapshotJson,
      operationId: operationId ?? this.operationId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (oldSnapshotJson.present) {
      map['old_snapshot_json'] = Variable<String>(oldSnapshotJson.value);
    }
    if (newSnapshotJson.present) {
      map['new_snapshot_json'] = Variable<String>(newSnapshotJson.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditEventsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('actorId: $actorId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('oldSnapshotJson: $oldSnapshotJson, ')
          ..write('newSnapshotJson: $newSnapshotJson, ')
          ..write('operationId: $operationId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppliedSyncOperationsTable extends AppliedSyncOperations
    with TableInfo<$AppliedSyncOperationsTable, AppliedSyncOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppliedSyncOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultJsonMeta = const VerificationMeta(
    'resultJson',
  );
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
    'result_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appliedAtMeta = const VerificationMeta(
    'appliedAt',
  );
  @override
  late final GeneratedColumn<String> appliedAt = GeneratedColumn<String>(
    'applied_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    idempotencyKey,
    contentHash,
    resultJson,
    appliedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'applied_sync_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppliedSyncOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('result_json')) {
      context.handle(
        _resultJsonMeta,
        resultJson.isAcceptableOrUnknown(data['result_json']!, _resultJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_resultJsonMeta);
    }
    if (data.containsKey('applied_at')) {
      context.handle(
        _appliedAtMeta,
        appliedAt.isAcceptableOrUnknown(data['applied_at']!, _appliedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_appliedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, idempotencyKey};
  @override
  AppliedSyncOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppliedSyncOperation(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      resultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_json'],
      )!,
      appliedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}applied_at'],
      )!,
    );
  }

  @override
  $AppliedSyncOperationsTable createAlias(String alias) {
    return $AppliedSyncOperationsTable(attachedDatabase, alias);
  }
}

class AppliedSyncOperation extends DataClass
    implements Insertable<AppliedSyncOperation> {
  final String ownerId;
  final String idempotencyKey;
  final String contentHash;
  final String resultJson;
  final String appliedAt;
  const AppliedSyncOperation({
    required this.ownerId,
    required this.idempotencyKey,
    required this.contentHash,
    required this.resultJson,
    required this.appliedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['content_hash'] = Variable<String>(contentHash);
    map['result_json'] = Variable<String>(resultJson);
    map['applied_at'] = Variable<String>(appliedAt);
    return map;
  }

  AppliedSyncOperationsCompanion toCompanion(bool nullToAbsent) {
    return AppliedSyncOperationsCompanion(
      ownerId: Value(ownerId),
      idempotencyKey: Value(idempotencyKey),
      contentHash: Value(contentHash),
      resultJson: Value(resultJson),
      appliedAt: Value(appliedAt),
    );
  }

  factory AppliedSyncOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppliedSyncOperation(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      resultJson: serializer.fromJson<String>(json['resultJson']),
      appliedAt: serializer.fromJson<String>(json['appliedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'contentHash': serializer.toJson<String>(contentHash),
      'resultJson': serializer.toJson<String>(resultJson),
      'appliedAt': serializer.toJson<String>(appliedAt),
    };
  }

  AppliedSyncOperation copyWith({
    String? ownerId,
    String? idempotencyKey,
    String? contentHash,
    String? resultJson,
    String? appliedAt,
  }) => AppliedSyncOperation(
    ownerId: ownerId ?? this.ownerId,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    contentHash: contentHash ?? this.contentHash,
    resultJson: resultJson ?? this.resultJson,
    appliedAt: appliedAt ?? this.appliedAt,
  );
  AppliedSyncOperation copyWithCompanion(AppliedSyncOperationsCompanion data) {
    return AppliedSyncOperation(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      resultJson: data.resultJson.present
          ? data.resultJson.value
          : this.resultJson,
      appliedAt: data.appliedAt.present ? data.appliedAt.value : this.appliedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppliedSyncOperation(')
          ..write('ownerId: $ownerId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('contentHash: $contentHash, ')
          ..write('resultJson: $resultJson, ')
          ..write('appliedAt: $appliedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(ownerId, idempotencyKey, contentHash, resultJson, appliedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppliedSyncOperation &&
          other.ownerId == this.ownerId &&
          other.idempotencyKey == this.idempotencyKey &&
          other.contentHash == this.contentHash &&
          other.resultJson == this.resultJson &&
          other.appliedAt == this.appliedAt);
}

class AppliedSyncOperationsCompanion
    extends UpdateCompanion<AppliedSyncOperation> {
  final Value<String> ownerId;
  final Value<String> idempotencyKey;
  final Value<String> contentHash;
  final Value<String> resultJson;
  final Value<String> appliedAt;
  final Value<int> rowid;
  const AppliedSyncOperationsCompanion({
    this.ownerId = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.appliedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppliedSyncOperationsCompanion.insert({
    required String ownerId,
    required String idempotencyKey,
    required String contentHash,
    required String resultJson,
    required String appliedAt,
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       idempotencyKey = Value(idempotencyKey),
       contentHash = Value(contentHash),
       resultJson = Value(resultJson),
       appliedAt = Value(appliedAt);
  static Insertable<AppliedSyncOperation> custom({
    Expression<String>? ownerId,
    Expression<String>? idempotencyKey,
    Expression<String>? contentHash,
    Expression<String>? resultJson,
    Expression<String>? appliedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (contentHash != null) 'content_hash': contentHash,
      if (resultJson != null) 'result_json': resultJson,
      if (appliedAt != null) 'applied_at': appliedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppliedSyncOperationsCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? idempotencyKey,
    Value<String>? contentHash,
    Value<String>? resultJson,
    Value<String>? appliedAt,
    Value<int>? rowid,
  }) {
    return AppliedSyncOperationsCompanion(
      ownerId: ownerId ?? this.ownerId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      contentHash: contentHash ?? this.contentHash,
      resultJson: resultJson ?? this.resultJson,
      appliedAt: appliedAt ?? this.appliedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (appliedAt.present) {
      map['applied_at'] = Variable<String>(appliedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppliedSyncOperationsCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('contentHash: $contentHash, ')
          ..write('resultJson: $resultJson, ')
          ..write('appliedAt: $appliedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedVersionMeta = const VerificationMeta(
    'expectedVersion',
  );
  @override
  late final GeneratedColumn<int> expectedVersion = GeneratedColumn<int>(
    'expected_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<int> remoteVersion = GeneratedColumn<int>(
    'remote_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localSnapshotJsonMeta = const VerificationMeta(
    'localSnapshotJson',
  );
  @override
  late final GeneratedColumn<String> localSnapshotJson =
      GeneratedColumn<String>(
        'local_snapshot_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _remoteSnapshotJsonMeta =
      const VerificationMeta('remoteSnapshotJson');
  @override
  late final GeneratedColumn<String> remoteSnapshotJson =
      GeneratedColumn<String>(
        'remote_snapshot_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolutionJsonMeta = const VerificationMeta(
    'resolutionJson',
  );
  @override
  late final GeneratedColumn<String> resolutionJson = GeneratedColumn<String>(
    'resolution_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    entityType,
    entityId,
    expectedVersion,
    remoteVersion,
    localSnapshotJson,
    remoteSnapshotJson,
    state,
    resolutionJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('expected_version')) {
      context.handle(
        _expectedVersionMeta,
        expectedVersion.isAcceptableOrUnknown(
          data['expected_version']!,
          _expectedVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedVersionMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteVersionMeta);
    }
    if (data.containsKey('local_snapshot_json')) {
      context.handle(
        _localSnapshotJsonMeta,
        localSnapshotJson.isAcceptableOrUnknown(
          data['local_snapshot_json']!,
          _localSnapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localSnapshotJsonMeta);
    }
    if (data.containsKey('remote_snapshot_json')) {
      context.handle(
        _remoteSnapshotJsonMeta,
        remoteSnapshotJson.isAcceptableOrUnknown(
          data['remote_snapshot_json']!,
          _remoteSnapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteSnapshotJsonMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('resolution_json')) {
      context.handle(
        _resolutionJsonMeta,
        resolutionJson.isAcceptableOrUnknown(
          data['resolution_json']!,
          _resolutionJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, id};
  @override
  SyncConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflict(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      expectedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_version'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_version'],
      )!,
      localSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_snapshot_json'],
      )!,
      remoteSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_snapshot_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      resolutionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_json'],
      ),
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }
}

class SyncConflict extends DataClass implements Insertable<SyncConflict> {
  final String id;
  final String ownerId;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String entityType;
  final String entityId;
  final int expectedVersion;
  final int remoteVersion;
  final String localSnapshotJson;
  final String remoteSnapshotJson;
  final String state;
  final String? resolutionJson;
  const SyncConflict({
    required this.id,
    required this.ownerId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.entityType,
    required this.entityId,
    required this.expectedVersion,
    required this.remoteVersion,
    required this.localSnapshotJson,
    required this.remoteSnapshotJson,
    required this.state,
    this.resolutionJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['expected_version'] = Variable<int>(expectedVersion);
    map['remote_version'] = Variable<int>(remoteVersion);
    map['local_snapshot_json'] = Variable<String>(localSnapshotJson);
    map['remote_snapshot_json'] = Variable<String>(remoteSnapshotJson);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || resolutionJson != null) {
      map['resolution_json'] = Variable<String>(resolutionJson);
    }
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      entityType: Value(entityType),
      entityId: Value(entityId),
      expectedVersion: Value(expectedVersion),
      remoteVersion: Value(remoteVersion),
      localSnapshotJson: Value(localSnapshotJson),
      remoteSnapshotJson: Value(remoteSnapshotJson),
      state: Value(state),
      resolutionJson: resolutionJson == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionJson),
    );
  }

  factory SyncConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflict(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      expectedVersion: serializer.fromJson<int>(json['expectedVersion']),
      remoteVersion: serializer.fromJson<int>(json['remoteVersion']),
      localSnapshotJson: serializer.fromJson<String>(json['localSnapshotJson']),
      remoteSnapshotJson: serializer.fromJson<String>(
        json['remoteSnapshotJson'],
      ),
      state: serializer.fromJson<String>(json['state']),
      resolutionJson: serializer.fromJson<String?>(json['resolutionJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'expectedVersion': serializer.toJson<int>(expectedVersion),
      'remoteVersion': serializer.toJson<int>(remoteVersion),
      'localSnapshotJson': serializer.toJson<String>(localSnapshotJson),
      'remoteSnapshotJson': serializer.toJson<String>(remoteSnapshotJson),
      'state': serializer.toJson<String>(state),
      'resolutionJson': serializer.toJson<String?>(resolutionJson),
    };
  }

  SyncConflict copyWith({
    String? id,
    String? ownerId,
    int? version,
    String? createdAt,
    String? updatedAt,
    String? entityType,
    String? entityId,
    int? expectedVersion,
    int? remoteVersion,
    String? localSnapshotJson,
    String? remoteSnapshotJson,
    String? state,
    Value<String?> resolutionJson = const Value.absent(),
  }) => SyncConflict(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    expectedVersion: expectedVersion ?? this.expectedVersion,
    remoteVersion: remoteVersion ?? this.remoteVersion,
    localSnapshotJson: localSnapshotJson ?? this.localSnapshotJson,
    remoteSnapshotJson: remoteSnapshotJson ?? this.remoteSnapshotJson,
    state: state ?? this.state,
    resolutionJson: resolutionJson.present
        ? resolutionJson.value
        : this.resolutionJson,
  );
  SyncConflict copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflict(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      expectedVersion: data.expectedVersion.present
          ? data.expectedVersion.value
          : this.expectedVersion,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      localSnapshotJson: data.localSnapshotJson.present
          ? data.localSnapshotJson.value
          : this.localSnapshotJson,
      remoteSnapshotJson: data.remoteSnapshotJson.present
          ? data.remoteSnapshotJson.value
          : this.remoteSnapshotJson,
      state: data.state.present ? data.state.value : this.state,
      resolutionJson: data.resolutionJson.present
          ? data.resolutionJson.value
          : this.resolutionJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflict(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('localSnapshotJson: $localSnapshotJson, ')
          ..write('remoteSnapshotJson: $remoteSnapshotJson, ')
          ..write('state: $state, ')
          ..write('resolutionJson: $resolutionJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    version,
    createdAt,
    updatedAt,
    entityType,
    entityId,
    expectedVersion,
    remoteVersion,
    localSnapshotJson,
    remoteSnapshotJson,
    state,
    resolutionJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflict &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.expectedVersion == this.expectedVersion &&
          other.remoteVersion == this.remoteVersion &&
          other.localSnapshotJson == this.localSnapshotJson &&
          other.remoteSnapshotJson == this.remoteSnapshotJson &&
          other.state == this.state &&
          other.resolutionJson == this.resolutionJson);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflict> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<int> version;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> expectedVersion;
  final Value<int> remoteVersion;
  final Value<String> localSnapshotJson;
  final Value<String> remoteSnapshotJson;
  final Value<String> state;
  final Value<String?> resolutionJson;
  final Value<int> rowid;
  const SyncConflictsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.expectedVersion = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.localSnapshotJson = const Value.absent(),
    this.remoteSnapshotJson = const Value.absent(),
    this.state = const Value.absent(),
    this.resolutionJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    required String id,
    required String ownerId,
    this.version = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    required String entityType,
    required String entityId,
    required int expectedVersion,
    required int remoteVersion,
    required String localSnapshotJson,
    required String remoteSnapshotJson,
    required String state,
    this.resolutionJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       entityType = Value(entityType),
       entityId = Value(entityId),
       expectedVersion = Value(expectedVersion),
       remoteVersion = Value(remoteVersion),
       localSnapshotJson = Value(localSnapshotJson),
       remoteSnapshotJson = Value(remoteSnapshotJson),
       state = Value(state);
  static Insertable<SyncConflict> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? expectedVersion,
    Expression<int>? remoteVersion,
    Expression<String>? localSnapshotJson,
    Expression<String>? remoteSnapshotJson,
    Expression<String>? state,
    Expression<String>? resolutionJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (expectedVersion != null) 'expected_version': expectedVersion,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (localSnapshotJson != null) 'local_snapshot_json': localSnapshotJson,
      if (remoteSnapshotJson != null)
        'remote_snapshot_json': remoteSnapshotJson,
      if (state != null) 'state': state,
      if (resolutionJson != null) 'resolution_json': resolutionJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<int>? version,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? expectedVersion,
    Value<int>? remoteVersion,
    Value<String>? localSnapshotJson,
    Value<String>? remoteSnapshotJson,
    Value<String>? state,
    Value<String?>? resolutionJson,
    Value<int>? rowid,
  }) {
    return SyncConflictsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      localSnapshotJson: localSnapshotJson ?? this.localSnapshotJson,
      remoteSnapshotJson: remoteSnapshotJson ?? this.remoteSnapshotJson,
      state: state ?? this.state,
      resolutionJson: resolutionJson ?? this.resolutionJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (expectedVersion.present) {
      map['expected_version'] = Variable<int>(expectedVersion.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<int>(remoteVersion.value);
    }
    if (localSnapshotJson.present) {
      map['local_snapshot_json'] = Variable<String>(localSnapshotJson.value);
    }
    if (remoteSnapshotJson.present) {
      map['remote_snapshot_json'] = Variable<String>(remoteSnapshotJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (resolutionJson.present) {
      map['resolution_json'] = Variable<String>(resolutionJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('localSnapshotJson: $localSnapshotJson, ')
          ..write('remoteSnapshotJson: $remoteSnapshotJson, ')
          ..write('state: $state, ')
          ..write('resolutionJson: $resolutionJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedVersionMeta = const VerificationMeta(
    'expectedVersion',
  );
  @override
  late final GeneratedColumn<int> expectedVersion = GeneratedColumn<int>(
    'expected_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<String> nextRetryAt = GeneratedColumn<String>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    idempotencyKey,
    entityType,
    entityId,
    expectedVersion,
    payloadJson,
    state,
    attempts,
    nextRetryAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('expected_version')) {
      context.handle(
        _expectedVersionMeta,
        expectedVersion.isAcceptableOrUnknown(
          data['expected_version']!,
          _expectedVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedVersionMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, idempotencyKey};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      expectedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_version'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_retry_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final String ownerId;
  final String idempotencyKey;
  final String entityType;
  final String entityId;
  final int expectedVersion;
  final String payloadJson;
  final String state;
  final int attempts;
  final String? nextRetryAt;
  final String? lastError;
  const SyncOutboxData({
    required this.ownerId,
    required this.idempotencyKey,
    required this.entityType,
    required this.entityId,
    required this.expectedVersion,
    required this.payloadJson,
    required this.state,
    required this.attempts,
    this.nextRetryAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['expected_version'] = Variable<int>(expectedVersion);
    map['payload_json'] = Variable<String>(payloadJson);
    map['state'] = Variable<String>(state);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<String>(nextRetryAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      ownerId: Value(ownerId),
      idempotencyKey: Value(idempotencyKey),
      entityType: Value(entityType),
      entityId: Value(entityId),
      expectedVersion: Value(expectedVersion),
      payloadJson: Value(payloadJson),
      state: Value(state),
      attempts: Value(attempts),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      expectedVersion: serializer.fromJson<int>(json['expectedVersion']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      state: serializer.fromJson<String>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextRetryAt: serializer.fromJson<String?>(json['nextRetryAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'expectedVersion': serializer.toJson<int>(expectedVersion),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'state': serializer.toJson<String>(state),
      'attempts': serializer.toJson<int>(attempts),
      'nextRetryAt': serializer.toJson<String?>(nextRetryAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncOutboxData copyWith({
    String? ownerId,
    String? idempotencyKey,
    String? entityType,
    String? entityId,
    int? expectedVersion,
    String? payloadJson,
    String? state,
    int? attempts,
    Value<String?> nextRetryAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => SyncOutboxData(
    ownerId: ownerId ?? this.ownerId,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    expectedVersion: expectedVersion ?? this.expectedVersion,
    payloadJson: payloadJson ?? this.payloadJson,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      expectedVersion: data.expectedVersion.present
          ? data.expectedVersion.value
          : this.expectedVersion,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('ownerId: $ownerId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    idempotencyKey,
    entityType,
    entityId,
    expectedVersion,
    payloadJson,
    state,
    attempts,
    nextRetryAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.ownerId == this.ownerId &&
          other.idempotencyKey == this.idempotencyKey &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.expectedVersion == this.expectedVersion &&
          other.payloadJson == this.payloadJson &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastError == this.lastError);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<String> ownerId;
  final Value<String> idempotencyKey;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> expectedVersion;
  final Value<String> payloadJson;
  final Value<String> state;
  final Value<int> attempts;
  final Value<String?> nextRetryAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.ownerId = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.expectedVersion = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String ownerId,
    required String idempotencyKey,
    required String entityType,
    required String entityId,
    required int expectedVersion,
    required String payloadJson,
    required String state,
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       idempotencyKey = Value(idempotencyKey),
       entityType = Value(entityType),
       entityId = Value(entityId),
       expectedVersion = Value(expectedVersion),
       payloadJson = Value(payloadJson),
       state = Value(state);
  static Insertable<SyncOutboxData> custom({
    Expression<String>? ownerId,
    Expression<String>? idempotencyKey,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? expectedVersion,
    Expression<String>? payloadJson,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<String>? nextRetryAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (expectedVersion != null) 'expected_version': expectedVersion,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? idempotencyKey,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? expectedVersion,
    Value<String>? payloadJson,
    Value<String>? state,
    Value<int>? attempts,
    Value<String?>? nextRetryAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return SyncOutboxCompanion(
      ownerId: ownerId ?? this.ownerId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      payloadJson: payloadJson ?? this.payloadJson,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (expectedVersion.present) {
      map['expected_version'] = Variable<int>(expectedVersion.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<String>(nextRetryAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTableMeta = const VerificationMeta(
    'sourceTable',
  );
  @override
  late final GeneratedColumn<String> sourceTable = GeneratedColumn<String>(
    'source_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOrderValueMeta = const VerificationMeta(
    'lastOrderValue',
  );
  @override
  late final GeneratedColumn<String> lastOrderValue = GeneratedColumn<String>(
    'last_order_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastIdMeta = const VerificationMeta('lastId');
  @override
  late final GeneratedColumn<String> lastId = GeneratedColumn<String>(
    'last_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    sourceTable,
    lastOrderValue,
    lastId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('source_table')) {
      context.handle(
        _sourceTableMeta,
        sourceTable.isAcceptableOrUnknown(
          data['source_table']!,
          _sourceTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceTableMeta);
    }
    if (data.containsKey('last_order_value')) {
      context.handle(
        _lastOrderValueMeta,
        lastOrderValue.isAcceptableOrUnknown(
          data['last_order_value']!,
          _lastOrderValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOrderValueMeta);
    }
    if (data.containsKey('last_id')) {
      context.handle(
        _lastIdMeta,
        lastId.isAcceptableOrUnknown(data['last_id']!, _lastIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, sourceTable};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      sourceTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_table'],
      )!,
      lastOrderValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_order_value'],
      )!,
      lastId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_id'],
      ),
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String ownerId;
  final String sourceTable;
  final String lastOrderValue;
  final String? lastId;
  const SyncCursor({
    required this.ownerId,
    required this.sourceTable,
    required this.lastOrderValue,
    this.lastId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['source_table'] = Variable<String>(sourceTable);
    map['last_order_value'] = Variable<String>(lastOrderValue);
    if (!nullToAbsent || lastId != null) {
      map['last_id'] = Variable<String>(lastId);
    }
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      ownerId: Value(ownerId),
      sourceTable: Value(sourceTable),
      lastOrderValue: Value(lastOrderValue),
      lastId: lastId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastId),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      sourceTable: serializer.fromJson<String>(json['sourceTable']),
      lastOrderValue: serializer.fromJson<String>(json['lastOrderValue']),
      lastId: serializer.fromJson<String?>(json['lastId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'sourceTable': serializer.toJson<String>(sourceTable),
      'lastOrderValue': serializer.toJson<String>(lastOrderValue),
      'lastId': serializer.toJson<String?>(lastId),
    };
  }

  SyncCursor copyWith({
    String? ownerId,
    String? sourceTable,
    String? lastOrderValue,
    Value<String?> lastId = const Value.absent(),
  }) => SyncCursor(
    ownerId: ownerId ?? this.ownerId,
    sourceTable: sourceTable ?? this.sourceTable,
    lastOrderValue: lastOrderValue ?? this.lastOrderValue,
    lastId: lastId.present ? lastId.value : this.lastId,
  );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      sourceTable: data.sourceTable.present
          ? data.sourceTable.value
          : this.sourceTable,
      lastOrderValue: data.lastOrderValue.present
          ? data.lastOrderValue.value
          : this.lastOrderValue,
      lastId: data.lastId.present ? data.lastId.value : this.lastId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('ownerId: $ownerId, ')
          ..write('sourceTable: $sourceTable, ')
          ..write('lastOrderValue: $lastOrderValue, ')
          ..write('lastId: $lastId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ownerId, sourceTable, lastOrderValue, lastId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.ownerId == this.ownerId &&
          other.sourceTable == this.sourceTable &&
          other.lastOrderValue == this.lastOrderValue &&
          other.lastId == this.lastId);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> ownerId;
  final Value<String> sourceTable;
  final Value<String> lastOrderValue;
  final Value<String?> lastId;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.ownerId = const Value.absent(),
    this.sourceTable = const Value.absent(),
    this.lastOrderValue = const Value.absent(),
    this.lastId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String ownerId,
    required String sourceTable,
    required String lastOrderValue,
    this.lastId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       sourceTable = Value(sourceTable),
       lastOrderValue = Value(lastOrderValue);
  static Insertable<SyncCursor> custom({
    Expression<String>? ownerId,
    Expression<String>? sourceTable,
    Expression<String>? lastOrderValue,
    Expression<String>? lastId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (sourceTable != null) 'source_table': sourceTable,
      if (lastOrderValue != null) 'last_order_value': lastOrderValue,
      if (lastId != null) 'last_id': lastId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? sourceTable,
    Value<String>? lastOrderValue,
    Value<String?>? lastId,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      ownerId: ownerId ?? this.ownerId,
      sourceTable: sourceTable ?? this.sourceTable,
      lastOrderValue: lastOrderValue ?? this.lastOrderValue,
      lastId: lastId ?? this.lastId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (sourceTable.present) {
      map['source_table'] = Variable<String>(sourceTable.value);
    }
    if (lastOrderValue.present) {
      map['last_order_value'] = Variable<String>(lastOrderValue.value);
    }
    if (lastId.present) {
      map['last_id'] = Variable<String>(lastId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('sourceTable: $sourceTable, ')
          ..write('lastOrderValue: $lastOrderValue, ')
          ..write('lastId: $lastId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$PorquinhoDatabase extends GeneratedDatabase {
  _$PorquinhoDatabase(QueryExecutor e) : super(e);
  $PorquinhoDatabaseManager get managers => $PorquinhoDatabaseManager(this);
  late final $UserPreferencesTable userPreferences = $UserPreferencesTable(
    this,
  );
  late final $PeriodConfigurationsTable periodConfigurations =
      $PeriodConfigurationsTable(this);
  late final $AccountingPeriodsTable accountingPeriods =
      $AccountingPeriodsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $SubcategoriesTable subcategories = $SubcategoriesTable(this);
  late final $IncomeRecurrenceTemplatesTable incomeRecurrenceTemplates =
      $IncomeRecurrenceTemplatesTable(this);
  late final $ExpenseRecurrenceTemplatesTable expenseRecurrenceTemplates =
      $ExpenseRecurrenceTemplatesTable(this);
  late final $InvestmentRecurrenceTemplatesTable investmentRecurrenceTemplates =
      $InvestmentRecurrenceTemplatesTable(this);
  late final $IncomeEntriesTable incomeEntries = $IncomeEntriesTable(this);
  late final $ExpenseEntriesTable expenseEntries = $ExpenseEntriesTable(this);
  late final $InvestmentAllocationsTable investmentAllocations =
      $InvestmentAllocationsTable(this);
  late final $AuditEventsTable auditEvents = $AuditEventsTable(this);
  late final $AppliedSyncOperationsTable appliedSyncOperations =
      $AppliedSyncOperationsTable(this);
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final Index uniqueIncomeOccurrenceSchedule = Index(
    'unique_income_occurrence_schedule',
    'CREATE UNIQUE INDEX unique_income_occurrence_schedule ON income_entries (owner_id, recurrence_template_id, scheduled_for_date) WHERE recurrence_template_id IS NOT NULL',
  );
  late final Index incomeEntriesPeriodIdx = Index(
    'income_entries_period_idx',
    'CREATE INDEX income_entries_period_idx ON income_entries (owner_id, accounting_period_id)',
  );
  late final Index uniqueExpenseOccurrenceSchedule = Index(
    'unique_expense_occurrence_schedule',
    'CREATE UNIQUE INDEX unique_expense_occurrence_schedule ON expense_entries (owner_id, recurrence_template_id, scheduled_for_date) WHERE recurrence_template_id IS NOT NULL',
  );
  late final Index expenseEntriesPeriodIdx = Index(
    'expense_entries_period_idx',
    'CREATE INDEX expense_entries_period_idx ON expense_entries (owner_id, accounting_period_id)',
  );
  late final Index uniqueInvestmentOccurrenceSchedule = Index(
    'unique_investment_occurrence_schedule',
    'CREATE UNIQUE INDEX unique_investment_occurrence_schedule ON investment_allocations (owner_id, recurrence_template_id, scheduled_for_date) WHERE recurrence_template_id IS NOT NULL',
  );
  late final Index investmentAllocationsPeriodIdx = Index(
    'investment_allocations_period_idx',
    'CREATE INDEX investment_allocations_period_idx ON investment_allocations (owner_id, accounting_period_id)',
  );
  late final Index syncOutboxStateIdx = Index(
    'sync_outbox_state_idx',
    'CREATE INDEX sync_outbox_state_idx ON sync_outbox (owner_id, state)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userPreferences,
    periodConfigurations,
    accountingPeriods,
    categories,
    subcategories,
    incomeRecurrenceTemplates,
    expenseRecurrenceTemplates,
    investmentRecurrenceTemplates,
    incomeEntries,
    expenseEntries,
    investmentAllocations,
    auditEvents,
    appliedSyncOperations,
    syncConflicts,
    syncOutbox,
    syncCursors,
    uniqueIncomeOccurrenceSchedule,
    incomeEntriesPeriodIdx,
    uniqueExpenseOccurrenceSchedule,
    expenseEntriesPeriodIdx,
    uniqueInvestmentOccurrenceSchedule,
    investmentAllocationsPeriodIdx,
    syncOutboxStateIdx,
  ];
}

typedef $$UserPreferencesTableCreateCompanionBuilder =
    UserPreferencesCompanion Function({
      required String ownerId,
      Value<String?> theme,
      Value<String> timeZoneId,
      Value<int> version,
      required String updatedAt,
      Value<String> onboarding,
      Value<int> rowid,
    });
typedef $$UserPreferencesTableUpdateCompanionBuilder =
    UserPreferencesCompanion Function({
      Value<String> ownerId,
      Value<String?> theme,
      Value<String> timeZoneId,
      Value<int> version,
      Value<String> updatedAt,
      Value<String> onboarding,
      Value<int> rowid,
    });

class $$UserPreferencesTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get onboarding => $composableBuilder(
    column: $table.onboarding,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPreferencesTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get onboarding => $composableBuilder(
    column: $table.onboarding,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPreferencesTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get onboarding => $composableBuilder(
    column: $table.onboarding,
    builder: (column) => column,
  );
}

class $$UserPreferencesTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $UserPreferencesTable,
          UserPreference,
          $$UserPreferencesTableFilterComposer,
          $$UserPreferencesTableOrderingComposer,
          $$UserPreferencesTableAnnotationComposer,
          $$UserPreferencesTableCreateCompanionBuilder,
          $$UserPreferencesTableUpdateCompanionBuilder,
          (
            UserPreference,
            BaseReferences<
              _$PorquinhoDatabase,
              $UserPreferencesTable,
              UserPreference
            >,
          ),
          UserPreference,
          PrefetchHooks Function()
        > {
  $$UserPreferencesTableTableManager(
    _$PorquinhoDatabase db,
    $UserPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String?> theme = const Value.absent(),
                Value<String> timeZoneId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> onboarding = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesCompanion(
                ownerId: ownerId,
                theme: theme,
                timeZoneId: timeZoneId,
                version: version,
                updatedAt: updatedAt,
                onboarding: onboarding,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                Value<String?> theme = const Value.absent(),
                Value<String> timeZoneId = const Value.absent(),
                Value<int> version = const Value.absent(),
                required String updatedAt,
                Value<String> onboarding = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesCompanion.insert(
                ownerId: ownerId,
                theme: theme,
                timeZoneId: timeZoneId,
                version: version,
                updatedAt: updatedAt,
                onboarding: onboarding,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserPreferencesTable, UserPreference>(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $UserPreferencesTable,
                    UserPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $UserPreferencesTable,
      UserPreference,
      $$UserPreferencesTableFilterComposer,
      $$UserPreferencesTableOrderingComposer,
      $$UserPreferencesTableAnnotationComposer,
      $$UserPreferencesTableCreateCompanionBuilder,
      $$UserPreferencesTableUpdateCompanionBuilder,
      (
        UserPreference,
        BaseReferences<
          _$PorquinhoDatabase,
          $UserPreferencesTable,
          UserPreference
        >,
      ),
      UserPreference,
      PrefetchHooks Function()
    >;
typedef $$PeriodConfigurationsTableCreateCompanionBuilder =
    PeriodConfigurationsCompanion Function({
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      required String mode,
      Value<int?> customStartDay,
      required String effectiveFrom,
      Value<int> rowid,
    });
typedef $$PeriodConfigurationsTableUpdateCompanionBuilder =
    PeriodConfigurationsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String> mode,
      Value<int?> customStartDay,
      Value<String> effectiveFrom,
      Value<int> rowid,
    });

class $$PeriodConfigurationsTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $PeriodConfigurationsTable> {
  $$PeriodConfigurationsTableFilterComposer({
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

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customStartDay => $composableBuilder(
    column: $table.customStartDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeriodConfigurationsTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $PeriodConfigurationsTable> {
  $$PeriodConfigurationsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customStartDay => $composableBuilder(
    column: $table.customStartDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeriodConfigurationsTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $PeriodConfigurationsTable> {
  $$PeriodConfigurationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get customStartDay => $composableBuilder(
    column: $table.customStartDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => column,
  );
}

class $$PeriodConfigurationsTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $PeriodConfigurationsTable,
          PeriodConfiguration,
          $$PeriodConfigurationsTableFilterComposer,
          $$PeriodConfigurationsTableOrderingComposer,
          $$PeriodConfigurationsTableAnnotationComposer,
          $$PeriodConfigurationsTableCreateCompanionBuilder,
          $$PeriodConfigurationsTableUpdateCompanionBuilder,
          (
            PeriodConfiguration,
            BaseReferences<
              _$PorquinhoDatabase,
              $PeriodConfigurationsTable,
              PeriodConfiguration
            >,
          ),
          PeriodConfiguration,
          PrefetchHooks Function()
        > {
  $$PeriodConfigurationsTableTableManager(
    _$PorquinhoDatabase db,
    $PeriodConfigurationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeriodConfigurationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeriodConfigurationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PeriodConfigurationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int?> customStartDay = const Value.absent(),
                Value<String> effectiveFrom = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeriodConfigurationsCompanion(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                mode: mode,
                customStartDay: customStartDay,
                effectiveFrom: effectiveFrom,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                required String mode,
                Value<int?> customStartDay = const Value.absent(),
                required String effectiveFrom,
                Value<int> rowid = const Value.absent(),
              }) => PeriodConfigurationsCompanion.insert(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                mode: mode,
                customStartDay: customStartDay,
                effectiveFrom: effectiveFrom,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PeriodConfigurationsTable, PeriodConfiguration>(
                    table,
                  ),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $PeriodConfigurationsTable,
                    PeriodConfiguration
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeriodConfigurationsTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $PeriodConfigurationsTable,
      PeriodConfiguration,
      $$PeriodConfigurationsTableFilterComposer,
      $$PeriodConfigurationsTableOrderingComposer,
      $$PeriodConfigurationsTableAnnotationComposer,
      $$PeriodConfigurationsTableCreateCompanionBuilder,
      $$PeriodConfigurationsTableUpdateCompanionBuilder,
      (
        PeriodConfiguration,
        BaseReferences<
          _$PorquinhoDatabase,
          $PeriodConfigurationsTable,
          PeriodConfiguration
        >,
      ),
      PeriodConfiguration,
      PrefetchHooks Function()
    >;
typedef $$AccountingPeriodsTableCreateCompanionBuilder =
    AccountingPeriodsCompanion Function({
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      required String configurationId,
      required String startDate,
      required String endDate,
      Value<int> rowid,
    });
typedef $$AccountingPeriodsTableUpdateCompanionBuilder =
    AccountingPeriodsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String> configurationId,
      Value<String> startDate,
      Value<String> endDate,
      Value<int> rowid,
    });

class $$AccountingPeriodsTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $AccountingPeriodsTable> {
  $$AccountingPeriodsTableFilterComposer({
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

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configurationId => $composableBuilder(
    column: $table.configurationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountingPeriodsTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $AccountingPeriodsTable> {
  $$AccountingPeriodsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configurationId => $composableBuilder(
    column: $table.configurationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountingPeriodsTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $AccountingPeriodsTable> {
  $$AccountingPeriodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get configurationId => $composableBuilder(
    column: $table.configurationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);
}

class $$AccountingPeriodsTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $AccountingPeriodsTable,
          AccountingPeriod,
          $$AccountingPeriodsTableFilterComposer,
          $$AccountingPeriodsTableOrderingComposer,
          $$AccountingPeriodsTableAnnotationComposer,
          $$AccountingPeriodsTableCreateCompanionBuilder,
          $$AccountingPeriodsTableUpdateCompanionBuilder,
          (
            AccountingPeriod,
            BaseReferences<
              _$PorquinhoDatabase,
              $AccountingPeriodsTable,
              AccountingPeriod
            >,
          ),
          AccountingPeriod,
          PrefetchHooks Function()
        > {
  $$AccountingPeriodsTableTableManager(
    _$PorquinhoDatabase db,
    $AccountingPeriodsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountingPeriodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountingPeriodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountingPeriodsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> configurationId = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String> endDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountingPeriodsCompanion(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                configurationId: configurationId,
                startDate: startDate,
                endDate: endDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                required String configurationId,
                required String startDate,
                required String endDate,
                Value<int> rowid = const Value.absent(),
              }) => AccountingPeriodsCompanion.insert(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                configurationId: configurationId,
                startDate: startDate,
                endDate: endDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountingPeriodsTable, AccountingPeriod>(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $AccountingPeriodsTable,
                    AccountingPeriod
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountingPeriodsTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $AccountingPeriodsTable,
      AccountingPeriod,
      $$AccountingPeriodsTableFilterComposer,
      $$AccountingPeriodsTableOrderingComposer,
      $$AccountingPeriodsTableAnnotationComposer,
      $$AccountingPeriodsTableCreateCompanionBuilder,
      $$AccountingPeriodsTableUpdateCompanionBuilder,
      (
        AccountingPeriod,
        BaseReferences<
          _$PorquinhoDatabase,
          $AccountingPeriodsTable,
          AccountingPeriod
        >,
      ),
      AccountingPeriod,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      required String kind,
      required String name,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String> kind,
      Value<String> name,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (
            Category,
            BaseReferences<_$PorquinhoDatabase, $CategoriesTable, Category>,
          ),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$PorquinhoDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                kind: kind,
                name: name,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                required String kind,
                required String name,
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                kind: kind,
                name: name,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $CategoriesTable,
                    Category
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (
        Category,
        BaseReferences<_$PorquinhoDatabase, $CategoriesTable, Category>,
      ),
      Category,
      PrefetchHooks Function()
    >;
typedef $$SubcategoriesTableCreateCompanionBuilder =
    SubcategoriesCompanion Function({
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      required String categoryId,
      required String name,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$SubcategoriesTableUpdateCompanionBuilder =
    SubcategoriesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String> categoryId,
      Value<String> name,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$SubcategoriesTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $SubcategoriesTable> {
  $$SubcategoriesTableFilterComposer({
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

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubcategoriesTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $SubcategoriesTable> {
  $$SubcategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubcategoriesTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $SubcategoriesTable> {
  $$SubcategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$SubcategoriesTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $SubcategoriesTable,
          Subcategory,
          $$SubcategoriesTableFilterComposer,
          $$SubcategoriesTableOrderingComposer,
          $$SubcategoriesTableAnnotationComposer,
          $$SubcategoriesTableCreateCompanionBuilder,
          $$SubcategoriesTableUpdateCompanionBuilder,
          (
            Subcategory,
            BaseReferences<
              _$PorquinhoDatabase,
              $SubcategoriesTable,
              Subcategory
            >,
          ),
          Subcategory,
          PrefetchHooks Function()
        > {
  $$SubcategoriesTableTableManager(
    _$PorquinhoDatabase db,
    $SubcategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubcategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubcategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubcategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubcategoriesCompanion(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                categoryId: categoryId,
                name: name,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                required String categoryId,
                required String name,
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubcategoriesCompanion.insert(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                categoryId: categoryId,
                name: name,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubcategoriesTable, Subcategory>(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $SubcategoriesTable,
                    Subcategory
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubcategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $SubcategoriesTable,
      Subcategory,
      $$SubcategoriesTableFilterComposer,
      $$SubcategoriesTableOrderingComposer,
      $$SubcategoriesTableAnnotationComposer,
      $$SubcategoriesTableCreateCompanionBuilder,
      $$SubcategoriesTableUpdateCompanionBuilder,
      (
        Subcategory,
        BaseReferences<_$PorquinhoDatabase, $SubcategoriesTable, Subcategory>,
      ),
      Subcategory,
      PrefetchHooks Function()
    >;
typedef $$IncomeRecurrenceTemplatesTableCreateCompanionBuilder =
    IncomeRecurrenceTemplatesCompanion Function({
      Value<String?> description,
      required String frequency,
      required String startsOn,
      Value<int?> monthlyReferenceDay,
      required String valueMode,
      Value<BigInt?> defaultAmountCentavos,
      Value<String?> categoryId,
      Value<String?> subcategoryId,
      Value<bool> isActive,
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$IncomeRecurrenceTemplatesTableUpdateCompanionBuilder =
    IncomeRecurrenceTemplatesCompanion Function({
      Value<String?> description,
      Value<String> frequency,
      Value<String> startsOn,
      Value<int?> monthlyReferenceDay,
      Value<String> valueMode,
      Value<BigInt?> defaultAmountCentavos,
      Value<String?> categoryId,
      Value<String?> subcategoryId,
      Value<bool> isActive,
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$IncomeRecurrenceTemplatesTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $IncomeRecurrenceTemplatesTable> {
  $$IncomeRecurrenceTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthlyReferenceDay => $composableBuilder(
    column: $table.monthlyReferenceDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueMode => $composableBuilder(
    column: $table.valueMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BigInt?, BigInt, String>
  get defaultAmountCentavos => $composableBuilder(
    column: $table.defaultAmountCentavos,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IncomeRecurrenceTemplatesTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $IncomeRecurrenceTemplatesTable> {
  $$IncomeRecurrenceTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthlyReferenceDay => $composableBuilder(
    column: $table.monthlyReferenceDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueMode => $composableBuilder(
    column: $table.valueMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultAmountCentavos => $composableBuilder(
    column: $table.defaultAmountCentavos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IncomeRecurrenceTemplatesTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $IncomeRecurrenceTemplatesTable> {
  $$IncomeRecurrenceTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<String> get startsOn =>
      $composableBuilder(column: $table.startsOn, builder: (column) => column);

  GeneratedColumn<int> get monthlyReferenceDay => $composableBuilder(
    column: $table.monthlyReferenceDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valueMode =>
      $composableBuilder(column: $table.valueMode, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BigInt?, String> get defaultAmountCentavos =>
      $composableBuilder(
        column: $table.defaultAmountCentavos,
        builder: (column) => column,
      );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$IncomeRecurrenceTemplatesTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $IncomeRecurrenceTemplatesTable,
          IncomeRecurrenceTemplate,
          $$IncomeRecurrenceTemplatesTableFilterComposer,
          $$IncomeRecurrenceTemplatesTableOrderingComposer,
          $$IncomeRecurrenceTemplatesTableAnnotationComposer,
          $$IncomeRecurrenceTemplatesTableCreateCompanionBuilder,
          $$IncomeRecurrenceTemplatesTableUpdateCompanionBuilder,
          (
            IncomeRecurrenceTemplate,
            BaseReferences<
              _$PorquinhoDatabase,
              $IncomeRecurrenceTemplatesTable,
              IncomeRecurrenceTemplate
            >,
          ),
          IncomeRecurrenceTemplate,
          PrefetchHooks Function()
        > {
  $$IncomeRecurrenceTemplatesTableTableManager(
    _$PorquinhoDatabase db,
    $IncomeRecurrenceTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IncomeRecurrenceTemplatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$IncomeRecurrenceTemplatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$IncomeRecurrenceTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String?> description = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<String> startsOn = const Value.absent(),
                Value<int?> monthlyReferenceDay = const Value.absent(),
                Value<String> valueMode = const Value.absent(),
                Value<BigInt?> defaultAmountCentavos = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IncomeRecurrenceTemplatesCompanion(
                description: description,
                frequency: frequency,
                startsOn: startsOn,
                monthlyReferenceDay: monthlyReferenceDay,
                valueMode: valueMode,
                defaultAmountCentavos: defaultAmountCentavos,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                isActive: isActive,
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> description = const Value.absent(),
                required String frequency,
                required String startsOn,
                Value<int?> monthlyReferenceDay = const Value.absent(),
                required String valueMode,
                Value<BigInt?> defaultAmountCentavos = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => IncomeRecurrenceTemplatesCompanion.insert(
                description: description,
                frequency: frequency,
                startsOn: startsOn,
                monthlyReferenceDay: monthlyReferenceDay,
                valueMode: valueMode,
                defaultAmountCentavos: defaultAmountCentavos,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                isActive: isActive,
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $IncomeRecurrenceTemplatesTable,
                    IncomeRecurrenceTemplate
                  >(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $IncomeRecurrenceTemplatesTable,
                    IncomeRecurrenceTemplate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IncomeRecurrenceTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $IncomeRecurrenceTemplatesTable,
      IncomeRecurrenceTemplate,
      $$IncomeRecurrenceTemplatesTableFilterComposer,
      $$IncomeRecurrenceTemplatesTableOrderingComposer,
      $$IncomeRecurrenceTemplatesTableAnnotationComposer,
      $$IncomeRecurrenceTemplatesTableCreateCompanionBuilder,
      $$IncomeRecurrenceTemplatesTableUpdateCompanionBuilder,
      (
        IncomeRecurrenceTemplate,
        BaseReferences<
          _$PorquinhoDatabase,
          $IncomeRecurrenceTemplatesTable,
          IncomeRecurrenceTemplate
        >,
      ),
      IncomeRecurrenceTemplate,
      PrefetchHooks Function()
    >;
typedef $$ExpenseRecurrenceTemplatesTableCreateCompanionBuilder =
    ExpenseRecurrenceTemplatesCompanion Function({
      Value<String?> description,
      required String frequency,
      required String startsOn,
      Value<int?> monthlyReferenceDay,
      required String valueMode,
      Value<BigInt?> defaultAmountCentavos,
      Value<String?> categoryId,
      Value<String?> subcategoryId,
      Value<bool> isActive,
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$ExpenseRecurrenceTemplatesTableUpdateCompanionBuilder =
    ExpenseRecurrenceTemplatesCompanion Function({
      Value<String?> description,
      Value<String> frequency,
      Value<String> startsOn,
      Value<int?> monthlyReferenceDay,
      Value<String> valueMode,
      Value<BigInt?> defaultAmountCentavos,
      Value<String?> categoryId,
      Value<String?> subcategoryId,
      Value<bool> isActive,
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$ExpenseRecurrenceTemplatesTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $ExpenseRecurrenceTemplatesTable> {
  $$ExpenseRecurrenceTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthlyReferenceDay => $composableBuilder(
    column: $table.monthlyReferenceDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueMode => $composableBuilder(
    column: $table.valueMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BigInt?, BigInt, String>
  get defaultAmountCentavos => $composableBuilder(
    column: $table.defaultAmountCentavos,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExpenseRecurrenceTemplatesTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $ExpenseRecurrenceTemplatesTable> {
  $$ExpenseRecurrenceTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthlyReferenceDay => $composableBuilder(
    column: $table.monthlyReferenceDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueMode => $composableBuilder(
    column: $table.valueMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultAmountCentavos => $composableBuilder(
    column: $table.defaultAmountCentavos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExpenseRecurrenceTemplatesTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $ExpenseRecurrenceTemplatesTable> {
  $$ExpenseRecurrenceTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<String> get startsOn =>
      $composableBuilder(column: $table.startsOn, builder: (column) => column);

  GeneratedColumn<int> get monthlyReferenceDay => $composableBuilder(
    column: $table.monthlyReferenceDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valueMode =>
      $composableBuilder(column: $table.valueMode, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BigInt?, String> get defaultAmountCentavos =>
      $composableBuilder(
        column: $table.defaultAmountCentavos,
        builder: (column) => column,
      );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ExpenseRecurrenceTemplatesTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $ExpenseRecurrenceTemplatesTable,
          ExpenseRecurrenceTemplate,
          $$ExpenseRecurrenceTemplatesTableFilterComposer,
          $$ExpenseRecurrenceTemplatesTableOrderingComposer,
          $$ExpenseRecurrenceTemplatesTableAnnotationComposer,
          $$ExpenseRecurrenceTemplatesTableCreateCompanionBuilder,
          $$ExpenseRecurrenceTemplatesTableUpdateCompanionBuilder,
          (
            ExpenseRecurrenceTemplate,
            BaseReferences<
              _$PorquinhoDatabase,
              $ExpenseRecurrenceTemplatesTable,
              ExpenseRecurrenceTemplate
            >,
          ),
          ExpenseRecurrenceTemplate,
          PrefetchHooks Function()
        > {
  $$ExpenseRecurrenceTemplatesTableTableManager(
    _$PorquinhoDatabase db,
    $ExpenseRecurrenceTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpenseRecurrenceTemplatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ExpenseRecurrenceTemplatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ExpenseRecurrenceTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String?> description = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<String> startsOn = const Value.absent(),
                Value<int?> monthlyReferenceDay = const Value.absent(),
                Value<String> valueMode = const Value.absent(),
                Value<BigInt?> defaultAmountCentavos = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseRecurrenceTemplatesCompanion(
                description: description,
                frequency: frequency,
                startsOn: startsOn,
                monthlyReferenceDay: monthlyReferenceDay,
                valueMode: valueMode,
                defaultAmountCentavos: defaultAmountCentavos,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                isActive: isActive,
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> description = const Value.absent(),
                required String frequency,
                required String startsOn,
                Value<int?> monthlyReferenceDay = const Value.absent(),
                required String valueMode,
                Value<BigInt?> defaultAmountCentavos = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ExpenseRecurrenceTemplatesCompanion.insert(
                description: description,
                frequency: frequency,
                startsOn: startsOn,
                monthlyReferenceDay: monthlyReferenceDay,
                valueMode: valueMode,
                defaultAmountCentavos: defaultAmountCentavos,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                isActive: isActive,
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ExpenseRecurrenceTemplatesTable,
                    ExpenseRecurrenceTemplate
                  >(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $ExpenseRecurrenceTemplatesTable,
                    ExpenseRecurrenceTemplate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExpenseRecurrenceTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $ExpenseRecurrenceTemplatesTable,
      ExpenseRecurrenceTemplate,
      $$ExpenseRecurrenceTemplatesTableFilterComposer,
      $$ExpenseRecurrenceTemplatesTableOrderingComposer,
      $$ExpenseRecurrenceTemplatesTableAnnotationComposer,
      $$ExpenseRecurrenceTemplatesTableCreateCompanionBuilder,
      $$ExpenseRecurrenceTemplatesTableUpdateCompanionBuilder,
      (
        ExpenseRecurrenceTemplate,
        BaseReferences<
          _$PorquinhoDatabase,
          $ExpenseRecurrenceTemplatesTable,
          ExpenseRecurrenceTemplate
        >,
      ),
      ExpenseRecurrenceTemplate,
      PrefetchHooks Function()
    >;
typedef $$InvestmentRecurrenceTemplatesTableCreateCompanionBuilder =
    InvestmentRecurrenceTemplatesCompanion Function({
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      required String frequency,
      required String startsOn,
      Value<int?> monthlyReferenceDay,
      required BigInt defaultAmountCentavos,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$InvestmentRecurrenceTemplatesTableUpdateCompanionBuilder =
    InvestmentRecurrenceTemplatesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String> frequency,
      Value<String> startsOn,
      Value<int?> monthlyReferenceDay,
      Value<BigInt> defaultAmountCentavos,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$InvestmentRecurrenceTemplatesTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $InvestmentRecurrenceTemplatesTable> {
  $$InvestmentRecurrenceTemplatesTableFilterComposer({
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

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthlyReferenceDay => $composableBuilder(
    column: $table.monthlyReferenceDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BigInt, BigInt, String>
  get defaultAmountCentavos => $composableBuilder(
    column: $table.defaultAmountCentavos,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InvestmentRecurrenceTemplatesTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $InvestmentRecurrenceTemplatesTable> {
  $$InvestmentRecurrenceTemplatesTableOrderingComposer({
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

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthlyReferenceDay => $composableBuilder(
    column: $table.monthlyReferenceDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultAmountCentavos => $composableBuilder(
    column: $table.defaultAmountCentavos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InvestmentRecurrenceTemplatesTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $InvestmentRecurrenceTemplatesTable> {
  $$InvestmentRecurrenceTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<String> get startsOn =>
      $composableBuilder(column: $table.startsOn, builder: (column) => column);

  GeneratedColumn<int> get monthlyReferenceDay => $composableBuilder(
    column: $table.monthlyReferenceDay,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BigInt, String> get defaultAmountCentavos =>
      $composableBuilder(
        column: $table.defaultAmountCentavos,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$InvestmentRecurrenceTemplatesTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $InvestmentRecurrenceTemplatesTable,
          InvestmentRecurrenceTemplate,
          $$InvestmentRecurrenceTemplatesTableFilterComposer,
          $$InvestmentRecurrenceTemplatesTableOrderingComposer,
          $$InvestmentRecurrenceTemplatesTableAnnotationComposer,
          $$InvestmentRecurrenceTemplatesTableCreateCompanionBuilder,
          $$InvestmentRecurrenceTemplatesTableUpdateCompanionBuilder,
          (
            InvestmentRecurrenceTemplate,
            BaseReferences<
              _$PorquinhoDatabase,
              $InvestmentRecurrenceTemplatesTable,
              InvestmentRecurrenceTemplate
            >,
          ),
          InvestmentRecurrenceTemplate,
          PrefetchHooks Function()
        > {
  $$InvestmentRecurrenceTemplatesTableTableManager(
    _$PorquinhoDatabase db,
    $InvestmentRecurrenceTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvestmentRecurrenceTemplatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InvestmentRecurrenceTemplatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InvestmentRecurrenceTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<String> startsOn = const Value.absent(),
                Value<int?> monthlyReferenceDay = const Value.absent(),
                Value<BigInt> defaultAmountCentavos = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvestmentRecurrenceTemplatesCompanion(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                frequency: frequency,
                startsOn: startsOn,
                monthlyReferenceDay: monthlyReferenceDay,
                defaultAmountCentavos: defaultAmountCentavos,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                required String frequency,
                required String startsOn,
                Value<int?> monthlyReferenceDay = const Value.absent(),
                required BigInt defaultAmountCentavos,
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvestmentRecurrenceTemplatesCompanion.insert(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                frequency: frequency,
                startsOn: startsOn,
                monthlyReferenceDay: monthlyReferenceDay,
                defaultAmountCentavos: defaultAmountCentavos,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $InvestmentRecurrenceTemplatesTable,
                    InvestmentRecurrenceTemplate
                  >(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $InvestmentRecurrenceTemplatesTable,
                    InvestmentRecurrenceTemplate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InvestmentRecurrenceTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $InvestmentRecurrenceTemplatesTable,
      InvestmentRecurrenceTemplate,
      $$InvestmentRecurrenceTemplatesTableFilterComposer,
      $$InvestmentRecurrenceTemplatesTableOrderingComposer,
      $$InvestmentRecurrenceTemplatesTableAnnotationComposer,
      $$InvestmentRecurrenceTemplatesTableCreateCompanionBuilder,
      $$InvestmentRecurrenceTemplatesTableUpdateCompanionBuilder,
      (
        InvestmentRecurrenceTemplate,
        BaseReferences<
          _$PorquinhoDatabase,
          $InvestmentRecurrenceTemplatesTable,
          InvestmentRecurrenceTemplate
        >,
      ),
      InvestmentRecurrenceTemplate,
      PrefetchHooks Function()
    >;
typedef $$IncomeEntriesTableCreateCompanionBuilder =
    IncomeEntriesCompanion Function({
      Value<String?> description,
      Value<BigInt?> amountCentavos,
      required String status,
      Value<String?> categoryId,
      Value<String?> subcategoryId,
      Value<String?> recurrenceTemplateId,
      Value<String?> scheduledForDate,
      Value<String?> scheduledPeriodId,
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      Value<String?> receivedOn,
      Value<String?> accountingPeriodId,
      Value<int> rowid,
    });
typedef $$IncomeEntriesTableUpdateCompanionBuilder =
    IncomeEntriesCompanion Function({
      Value<String?> description,
      Value<BigInt?> amountCentavos,
      Value<String> status,
      Value<String?> categoryId,
      Value<String?> subcategoryId,
      Value<String?> recurrenceTemplateId,
      Value<String?> scheduledForDate,
      Value<String?> scheduledPeriodId,
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> receivedOn,
      Value<String?> accountingPeriodId,
      Value<int> rowid,
    });

class $$IncomeEntriesTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $IncomeEntriesTable> {
  $$IncomeEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BigInt?, BigInt, String> get amountCentavos =>
      $composableBuilder(
        column: $table.amountCentavos,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceTemplateId => $composableBuilder(
    column: $table.recurrenceTemplateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledForDate => $composableBuilder(
    column: $table.scheduledForDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledPeriodId => $composableBuilder(
    column: $table.scheduledPeriodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receivedOn => $composableBuilder(
    column: $table.receivedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountingPeriodId => $composableBuilder(
    column: $table.accountingPeriodId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IncomeEntriesTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $IncomeEntriesTable> {
  $$IncomeEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountCentavos => $composableBuilder(
    column: $table.amountCentavos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceTemplateId => $composableBuilder(
    column: $table.recurrenceTemplateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledForDate => $composableBuilder(
    column: $table.scheduledForDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledPeriodId => $composableBuilder(
    column: $table.scheduledPeriodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receivedOn => $composableBuilder(
    column: $table.receivedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountingPeriodId => $composableBuilder(
    column: $table.accountingPeriodId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IncomeEntriesTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $IncomeEntriesTable> {
  $$IncomeEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BigInt?, String> get amountCentavos =>
      $composableBuilder(
        column: $table.amountCentavos,
        builder: (column) => column,
      );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceTemplateId => $composableBuilder(
    column: $table.recurrenceTemplateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduledForDate => $composableBuilder(
    column: $table.scheduledForDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduledPeriodId => $composableBuilder(
    column: $table.scheduledPeriodId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get receivedOn => $composableBuilder(
    column: $table.receivedOn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountingPeriodId => $composableBuilder(
    column: $table.accountingPeriodId,
    builder: (column) => column,
  );
}

class $$IncomeEntriesTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $IncomeEntriesTable,
          IncomeEntry,
          $$IncomeEntriesTableFilterComposer,
          $$IncomeEntriesTableOrderingComposer,
          $$IncomeEntriesTableAnnotationComposer,
          $$IncomeEntriesTableCreateCompanionBuilder,
          $$IncomeEntriesTableUpdateCompanionBuilder,
          (
            IncomeEntry,
            BaseReferences<
              _$PorquinhoDatabase,
              $IncomeEntriesTable,
              IncomeEntry
            >,
          ),
          IncomeEntry,
          PrefetchHooks Function()
        > {
  $$IncomeEntriesTableTableManager(
    _$PorquinhoDatabase db,
    $IncomeEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IncomeEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IncomeEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IncomeEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> description = const Value.absent(),
                Value<BigInt?> amountCentavos = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<String?> recurrenceTemplateId = const Value.absent(),
                Value<String?> scheduledForDate = const Value.absent(),
                Value<String?> scheduledPeriodId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> receivedOn = const Value.absent(),
                Value<String?> accountingPeriodId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IncomeEntriesCompanion(
                description: description,
                amountCentavos: amountCentavos,
                status: status,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                recurrenceTemplateId: recurrenceTemplateId,
                scheduledForDate: scheduledForDate,
                scheduledPeriodId: scheduledPeriodId,
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                receivedOn: receivedOn,
                accountingPeriodId: accountingPeriodId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> description = const Value.absent(),
                Value<BigInt?> amountCentavos = const Value.absent(),
                required String status,
                Value<String?> categoryId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<String?> recurrenceTemplateId = const Value.absent(),
                Value<String?> scheduledForDate = const Value.absent(),
                Value<String?> scheduledPeriodId = const Value.absent(),
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<String?> receivedOn = const Value.absent(),
                Value<String?> accountingPeriodId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IncomeEntriesCompanion.insert(
                description: description,
                amountCentavos: amountCentavos,
                status: status,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                recurrenceTemplateId: recurrenceTemplateId,
                scheduledForDate: scheduledForDate,
                scheduledPeriodId: scheduledPeriodId,
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                receivedOn: receivedOn,
                accountingPeriodId: accountingPeriodId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IncomeEntriesTable, IncomeEntry>(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $IncomeEntriesTable,
                    IncomeEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IncomeEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $IncomeEntriesTable,
      IncomeEntry,
      $$IncomeEntriesTableFilterComposer,
      $$IncomeEntriesTableOrderingComposer,
      $$IncomeEntriesTableAnnotationComposer,
      $$IncomeEntriesTableCreateCompanionBuilder,
      $$IncomeEntriesTableUpdateCompanionBuilder,
      (
        IncomeEntry,
        BaseReferences<_$PorquinhoDatabase, $IncomeEntriesTable, IncomeEntry>,
      ),
      IncomeEntry,
      PrefetchHooks Function()
    >;
typedef $$ExpenseEntriesTableCreateCompanionBuilder =
    ExpenseEntriesCompanion Function({
      Value<String?> description,
      Value<BigInt?> amountCentavos,
      required String status,
      Value<String?> categoryId,
      Value<String?> subcategoryId,
      Value<String?> recurrenceTemplateId,
      Value<String?> scheduledForDate,
      Value<String?> scheduledPeriodId,
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      required String accountingPeriodId,
      required String competenceOn,
      Value<String?> dueOn,
      Value<String?> paidOn,
      Value<int> rowid,
    });
typedef $$ExpenseEntriesTableUpdateCompanionBuilder =
    ExpenseEntriesCompanion Function({
      Value<String?> description,
      Value<BigInt?> amountCentavos,
      Value<String> status,
      Value<String?> categoryId,
      Value<String?> subcategoryId,
      Value<String?> recurrenceTemplateId,
      Value<String?> scheduledForDate,
      Value<String?> scheduledPeriodId,
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String> accountingPeriodId,
      Value<String> competenceOn,
      Value<String?> dueOn,
      Value<String?> paidOn,
      Value<int> rowid,
    });

class $$ExpenseEntriesTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $ExpenseEntriesTable> {
  $$ExpenseEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BigInt?, BigInt, String> get amountCentavos =>
      $composableBuilder(
        column: $table.amountCentavos,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceTemplateId => $composableBuilder(
    column: $table.recurrenceTemplateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledForDate => $composableBuilder(
    column: $table.scheduledForDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledPeriodId => $composableBuilder(
    column: $table.scheduledPeriodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountingPeriodId => $composableBuilder(
    column: $table.accountingPeriodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get competenceOn => $composableBuilder(
    column: $table.competenceOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueOn => $composableBuilder(
    column: $table.dueOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paidOn => $composableBuilder(
    column: $table.paidOn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExpenseEntriesTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $ExpenseEntriesTable> {
  $$ExpenseEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountCentavos => $composableBuilder(
    column: $table.amountCentavos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceTemplateId => $composableBuilder(
    column: $table.recurrenceTemplateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledForDate => $composableBuilder(
    column: $table.scheduledForDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledPeriodId => $composableBuilder(
    column: $table.scheduledPeriodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountingPeriodId => $composableBuilder(
    column: $table.accountingPeriodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get competenceOn => $composableBuilder(
    column: $table.competenceOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueOn => $composableBuilder(
    column: $table.dueOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paidOn => $composableBuilder(
    column: $table.paidOn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExpenseEntriesTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $ExpenseEntriesTable> {
  $$ExpenseEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BigInt?, String> get amountCentavos =>
      $composableBuilder(
        column: $table.amountCentavos,
        builder: (column) => column,
      );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subcategoryId => $composableBuilder(
    column: $table.subcategoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceTemplateId => $composableBuilder(
    column: $table.recurrenceTemplateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduledForDate => $composableBuilder(
    column: $table.scheduledForDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduledPeriodId => $composableBuilder(
    column: $table.scheduledPeriodId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get accountingPeriodId => $composableBuilder(
    column: $table.accountingPeriodId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get competenceOn => $composableBuilder(
    column: $table.competenceOn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dueOn =>
      $composableBuilder(column: $table.dueOn, builder: (column) => column);

  GeneratedColumn<String> get paidOn =>
      $composableBuilder(column: $table.paidOn, builder: (column) => column);
}

class $$ExpenseEntriesTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $ExpenseEntriesTable,
          ExpenseEntry,
          $$ExpenseEntriesTableFilterComposer,
          $$ExpenseEntriesTableOrderingComposer,
          $$ExpenseEntriesTableAnnotationComposer,
          $$ExpenseEntriesTableCreateCompanionBuilder,
          $$ExpenseEntriesTableUpdateCompanionBuilder,
          (
            ExpenseEntry,
            BaseReferences<
              _$PorquinhoDatabase,
              $ExpenseEntriesTable,
              ExpenseEntry
            >,
          ),
          ExpenseEntry,
          PrefetchHooks Function()
        > {
  $$ExpenseEntriesTableTableManager(
    _$PorquinhoDatabase db,
    $ExpenseEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpenseEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpenseEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpenseEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> description = const Value.absent(),
                Value<BigInt?> amountCentavos = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<String?> recurrenceTemplateId = const Value.absent(),
                Value<String?> scheduledForDate = const Value.absent(),
                Value<String?> scheduledPeriodId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> accountingPeriodId = const Value.absent(),
                Value<String> competenceOn = const Value.absent(),
                Value<String?> dueOn = const Value.absent(),
                Value<String?> paidOn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseEntriesCompanion(
                description: description,
                amountCentavos: amountCentavos,
                status: status,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                recurrenceTemplateId: recurrenceTemplateId,
                scheduledForDate: scheduledForDate,
                scheduledPeriodId: scheduledPeriodId,
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                accountingPeriodId: accountingPeriodId,
                competenceOn: competenceOn,
                dueOn: dueOn,
                paidOn: paidOn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> description = const Value.absent(),
                Value<BigInt?> amountCentavos = const Value.absent(),
                required String status,
                Value<String?> categoryId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<String?> recurrenceTemplateId = const Value.absent(),
                Value<String?> scheduledForDate = const Value.absent(),
                Value<String?> scheduledPeriodId = const Value.absent(),
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                required String accountingPeriodId,
                required String competenceOn,
                Value<String?> dueOn = const Value.absent(),
                Value<String?> paidOn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseEntriesCompanion.insert(
                description: description,
                amountCentavos: amountCentavos,
                status: status,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                recurrenceTemplateId: recurrenceTemplateId,
                scheduledForDate: scheduledForDate,
                scheduledPeriodId: scheduledPeriodId,
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                accountingPeriodId: accountingPeriodId,
                competenceOn: competenceOn,
                dueOn: dueOn,
                paidOn: paidOn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExpenseEntriesTable, ExpenseEntry>(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $ExpenseEntriesTable,
                    ExpenseEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExpenseEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $ExpenseEntriesTable,
      ExpenseEntry,
      $$ExpenseEntriesTableFilterComposer,
      $$ExpenseEntriesTableOrderingComposer,
      $$ExpenseEntriesTableAnnotationComposer,
      $$ExpenseEntriesTableCreateCompanionBuilder,
      $$ExpenseEntriesTableUpdateCompanionBuilder,
      (
        ExpenseEntry,
        BaseReferences<_$PorquinhoDatabase, $ExpenseEntriesTable, ExpenseEntry>,
      ),
      ExpenseEntry,
      PrefetchHooks Function()
    >;
typedef $$InvestmentAllocationsTableCreateCompanionBuilder =
    InvestmentAllocationsCompanion Function({
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      required BigInt amountCentavos,
      required String allocatedOn,
      required String accountingPeriodId,
      Value<String?> cancelledAt,
      Value<String?> recurrenceTemplateId,
      Value<String?> scheduledForDate,
      Value<String?> scheduledPeriodId,
      Value<int> rowid,
    });
typedef $$InvestmentAllocationsTableUpdateCompanionBuilder =
    InvestmentAllocationsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<BigInt> amountCentavos,
      Value<String> allocatedOn,
      Value<String> accountingPeriodId,
      Value<String?> cancelledAt,
      Value<String?> recurrenceTemplateId,
      Value<String?> scheduledForDate,
      Value<String?> scheduledPeriodId,
      Value<int> rowid,
    });

class $$InvestmentAllocationsTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $InvestmentAllocationsTable> {
  $$InvestmentAllocationsTableFilterComposer({
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

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BigInt, BigInt, String> get amountCentavos =>
      $composableBuilder(
        column: $table.amountCentavos,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get allocatedOn => $composableBuilder(
    column: $table.allocatedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountingPeriodId => $composableBuilder(
    column: $table.accountingPeriodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceTemplateId => $composableBuilder(
    column: $table.recurrenceTemplateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledForDate => $composableBuilder(
    column: $table.scheduledForDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledPeriodId => $composableBuilder(
    column: $table.scheduledPeriodId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InvestmentAllocationsTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $InvestmentAllocationsTable> {
  $$InvestmentAllocationsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountCentavos => $composableBuilder(
    column: $table.amountCentavos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allocatedOn => $composableBuilder(
    column: $table.allocatedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountingPeriodId => $composableBuilder(
    column: $table.accountingPeriodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceTemplateId => $composableBuilder(
    column: $table.recurrenceTemplateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledForDate => $composableBuilder(
    column: $table.scheduledForDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledPeriodId => $composableBuilder(
    column: $table.scheduledPeriodId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InvestmentAllocationsTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $InvestmentAllocationsTable> {
  $$InvestmentAllocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BigInt, String> get amountCentavos =>
      $composableBuilder(
        column: $table.amountCentavos,
        builder: (column) => column,
      );

  GeneratedColumn<String> get allocatedOn => $composableBuilder(
    column: $table.allocatedOn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountingPeriodId => $composableBuilder(
    column: $table.accountingPeriodId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceTemplateId => $composableBuilder(
    column: $table.recurrenceTemplateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduledForDate => $composableBuilder(
    column: $table.scheduledForDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduledPeriodId => $composableBuilder(
    column: $table.scheduledPeriodId,
    builder: (column) => column,
  );
}

class $$InvestmentAllocationsTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $InvestmentAllocationsTable,
          InvestmentAllocation,
          $$InvestmentAllocationsTableFilterComposer,
          $$InvestmentAllocationsTableOrderingComposer,
          $$InvestmentAllocationsTableAnnotationComposer,
          $$InvestmentAllocationsTableCreateCompanionBuilder,
          $$InvestmentAllocationsTableUpdateCompanionBuilder,
          (
            InvestmentAllocation,
            BaseReferences<
              _$PorquinhoDatabase,
              $InvestmentAllocationsTable,
              InvestmentAllocation
            >,
          ),
          InvestmentAllocation,
          PrefetchHooks Function()
        > {
  $$InvestmentAllocationsTableTableManager(
    _$PorquinhoDatabase db,
    $InvestmentAllocationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvestmentAllocationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InvestmentAllocationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InvestmentAllocationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<BigInt> amountCentavos = const Value.absent(),
                Value<String> allocatedOn = const Value.absent(),
                Value<String> accountingPeriodId = const Value.absent(),
                Value<String?> cancelledAt = const Value.absent(),
                Value<String?> recurrenceTemplateId = const Value.absent(),
                Value<String?> scheduledForDate = const Value.absent(),
                Value<String?> scheduledPeriodId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvestmentAllocationsCompanion(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                amountCentavos: amountCentavos,
                allocatedOn: allocatedOn,
                accountingPeriodId: accountingPeriodId,
                cancelledAt: cancelledAt,
                recurrenceTemplateId: recurrenceTemplateId,
                scheduledForDate: scheduledForDate,
                scheduledPeriodId: scheduledPeriodId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                required BigInt amountCentavos,
                required String allocatedOn,
                required String accountingPeriodId,
                Value<String?> cancelledAt = const Value.absent(),
                Value<String?> recurrenceTemplateId = const Value.absent(),
                Value<String?> scheduledForDate = const Value.absent(),
                Value<String?> scheduledPeriodId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvestmentAllocationsCompanion.insert(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                amountCentavos: amountCentavos,
                allocatedOn: allocatedOn,
                accountingPeriodId: accountingPeriodId,
                cancelledAt: cancelledAt,
                recurrenceTemplateId: recurrenceTemplateId,
                scheduledForDate: scheduledForDate,
                scheduledPeriodId: scheduledPeriodId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $InvestmentAllocationsTable,
                    InvestmentAllocation
                  >(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $InvestmentAllocationsTable,
                    InvestmentAllocation
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InvestmentAllocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $InvestmentAllocationsTable,
      InvestmentAllocation,
      $$InvestmentAllocationsTableFilterComposer,
      $$InvestmentAllocationsTableOrderingComposer,
      $$InvestmentAllocationsTableAnnotationComposer,
      $$InvestmentAllocationsTableCreateCompanionBuilder,
      $$InvestmentAllocationsTableUpdateCompanionBuilder,
      (
        InvestmentAllocation,
        BaseReferences<
          _$PorquinhoDatabase,
          $InvestmentAllocationsTable,
          InvestmentAllocation
        >,
      ),
      InvestmentAllocation,
      PrefetchHooks Function()
    >;
typedef $$AuditEventsTableCreateCompanionBuilder =
    AuditEventsCompanion Function({
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      required String entityType,
      required String entityId,
      required String operation,
      Value<String?> actorId,
      required String occurredAt,
      Value<String?> oldSnapshotJson,
      Value<String?> newSnapshotJson,
      required String operationId,
      Value<int> rowid,
    });
typedef $$AuditEventsTableUpdateCompanionBuilder =
    AuditEventsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operation,
      Value<String?> actorId,
      Value<String> occurredAt,
      Value<String?> oldSnapshotJson,
      Value<String?> newSnapshotJson,
      Value<String> operationId,
      Value<int> rowid,
    });

class $$AuditEventsTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $AuditEventsTable> {
  $$AuditEventsTableFilterComposer({
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

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldSnapshotJson => $composableBuilder(
    column: $table.oldSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newSnapshotJson => $composableBuilder(
    column: $table.newSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuditEventsTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $AuditEventsTable> {
  $$AuditEventsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldSnapshotJson => $composableBuilder(
    column: $table.oldSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newSnapshotJson => $composableBuilder(
    column: $table.newSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditEventsTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $AuditEventsTable> {
  $$AuditEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get oldSnapshotJson => $composableBuilder(
    column: $table.oldSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get newSnapshotJson => $composableBuilder(
    column: $table.newSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );
}

class $$AuditEventsTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $AuditEventsTable,
          AuditEvent,
          $$AuditEventsTableFilterComposer,
          $$AuditEventsTableOrderingComposer,
          $$AuditEventsTableAnnotationComposer,
          $$AuditEventsTableCreateCompanionBuilder,
          $$AuditEventsTableUpdateCompanionBuilder,
          (
            AuditEvent,
            BaseReferences<_$PorquinhoDatabase, $AuditEventsTable, AuditEvent>,
          ),
          AuditEvent,
          PrefetchHooks Function()
        > {
  $$AuditEventsTableTableManager(
    _$PorquinhoDatabase db,
    $AuditEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                Value<String> occurredAt = const Value.absent(),
                Value<String?> oldSnapshotJson = const Value.absent(),
                Value<String?> newSnapshotJson = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditEventsCompanion(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                actorId: actorId,
                occurredAt: occurredAt,
                oldSnapshotJson: oldSnapshotJson,
                newSnapshotJson: newSnapshotJson,
                operationId: operationId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                required String entityType,
                required String entityId,
                required String operation,
                Value<String?> actorId = const Value.absent(),
                required String occurredAt,
                Value<String?> oldSnapshotJson = const Value.absent(),
                Value<String?> newSnapshotJson = const Value.absent(),
                required String operationId,
                Value<int> rowid = const Value.absent(),
              }) => AuditEventsCompanion.insert(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                actorId: actorId,
                occurredAt: occurredAt,
                oldSnapshotJson: oldSnapshotJson,
                newSnapshotJson: newSnapshotJson,
                operationId: operationId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AuditEventsTable, AuditEvent>(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $AuditEventsTable,
                    AuditEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuditEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $AuditEventsTable,
      AuditEvent,
      $$AuditEventsTableFilterComposer,
      $$AuditEventsTableOrderingComposer,
      $$AuditEventsTableAnnotationComposer,
      $$AuditEventsTableCreateCompanionBuilder,
      $$AuditEventsTableUpdateCompanionBuilder,
      (
        AuditEvent,
        BaseReferences<_$PorquinhoDatabase, $AuditEventsTable, AuditEvent>,
      ),
      AuditEvent,
      PrefetchHooks Function()
    >;
typedef $$AppliedSyncOperationsTableCreateCompanionBuilder =
    AppliedSyncOperationsCompanion Function({
      required String ownerId,
      required String idempotencyKey,
      required String contentHash,
      required String resultJson,
      required String appliedAt,
      Value<int> rowid,
    });
typedef $$AppliedSyncOperationsTableUpdateCompanionBuilder =
    AppliedSyncOperationsCompanion Function({
      Value<String> ownerId,
      Value<String> idempotencyKey,
      Value<String> contentHash,
      Value<String> resultJson,
      Value<String> appliedAt,
      Value<int> rowid,
    });

class $$AppliedSyncOperationsTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $AppliedSyncOperationsTable> {
  $$AppliedSyncOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppliedSyncOperationsTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $AppliedSyncOperationsTable> {
  $$AppliedSyncOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppliedSyncOperationsTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $AppliedSyncOperationsTable> {
  $$AppliedSyncOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appliedAt =>
      $composableBuilder(column: $table.appliedAt, builder: (column) => column);
}

class $$AppliedSyncOperationsTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $AppliedSyncOperationsTable,
          AppliedSyncOperation,
          $$AppliedSyncOperationsTableFilterComposer,
          $$AppliedSyncOperationsTableOrderingComposer,
          $$AppliedSyncOperationsTableAnnotationComposer,
          $$AppliedSyncOperationsTableCreateCompanionBuilder,
          $$AppliedSyncOperationsTableUpdateCompanionBuilder,
          (
            AppliedSyncOperation,
            BaseReferences<
              _$PorquinhoDatabase,
              $AppliedSyncOperationsTable,
              AppliedSyncOperation
            >,
          ),
          AppliedSyncOperation,
          PrefetchHooks Function()
        > {
  $$AppliedSyncOperationsTableTableManager(
    _$PorquinhoDatabase db,
    $AppliedSyncOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppliedSyncOperationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AppliedSyncOperationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AppliedSyncOperationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String> resultJson = const Value.absent(),
                Value<String> appliedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppliedSyncOperationsCompanion(
                ownerId: ownerId,
                idempotencyKey: idempotencyKey,
                contentHash: contentHash,
                resultJson: resultJson,
                appliedAt: appliedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String idempotencyKey,
                required String contentHash,
                required String resultJson,
                required String appliedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppliedSyncOperationsCompanion.insert(
                ownerId: ownerId,
                idempotencyKey: idempotencyKey,
                contentHash: contentHash,
                resultJson: resultJson,
                appliedAt: appliedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $AppliedSyncOperationsTable,
                    AppliedSyncOperation
                  >(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $AppliedSyncOperationsTable,
                    AppliedSyncOperation
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppliedSyncOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $AppliedSyncOperationsTable,
      AppliedSyncOperation,
      $$AppliedSyncOperationsTableFilterComposer,
      $$AppliedSyncOperationsTableOrderingComposer,
      $$AppliedSyncOperationsTableAnnotationComposer,
      $$AppliedSyncOperationsTableCreateCompanionBuilder,
      $$AppliedSyncOperationsTableUpdateCompanionBuilder,
      (
        AppliedSyncOperation,
        BaseReferences<
          _$PorquinhoDatabase,
          $AppliedSyncOperationsTable,
          AppliedSyncOperation
        >,
      ),
      AppliedSyncOperation,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      required String id,
      required String ownerId,
      Value<int> version,
      required String createdAt,
      required String updatedAt,
      required String entityType,
      required String entityId,
      required int expectedVersion,
      required int remoteVersion,
      required String localSnapshotJson,
      required String remoteSnapshotJson,
      required String state,
      Value<String?> resolutionJson,
      Value<int> rowid,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<int> version,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String> entityType,
      Value<String> entityId,
      Value<int> expectedVersion,
      Value<int> remoteVersion,
      Value<String> localSnapshotJson,
      Value<String> remoteSnapshotJson,
      Value<String> state,
      Value<String?> resolutionJson,
      Value<int> rowid,
    });

class $$SyncConflictsTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
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

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localSnapshotJson => $composableBuilder(
    column: $table.localSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteSnapshotJson => $composableBuilder(
    column: $table.remoteSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolutionJson => $composableBuilder(
    column: $table.resolutionJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
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

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localSnapshotJson => $composableBuilder(
    column: $table.localSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteSnapshotJson => $composableBuilder(
    column: $table.remoteSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolutionJson => $composableBuilder(
    column: $table.resolutionJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localSnapshotJson => $composableBuilder(
    column: $table.localSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteSnapshotJson => $composableBuilder(
    column: $table.remoteSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get resolutionJson => $composableBuilder(
    column: $table.resolutionJson,
    builder: (column) => column,
  );
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $SyncConflictsTable,
          SyncConflict,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (
            SyncConflict,
            BaseReferences<
              _$PorquinhoDatabase,
              $SyncConflictsTable,
              SyncConflict
            >,
          ),
          SyncConflict,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(
    _$PorquinhoDatabase db,
    $SyncConflictsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> expectedVersion = const Value.absent(),
                Value<int> remoteVersion = const Value.absent(),
                Value<String> localSnapshotJson = const Value.absent(),
                Value<String> remoteSnapshotJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> resolutionJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                entityType: entityType,
                entityId: entityId,
                expectedVersion: expectedVersion,
                remoteVersion: remoteVersion,
                localSnapshotJson: localSnapshotJson,
                remoteSnapshotJson: remoteSnapshotJson,
                state: state,
                resolutionJson: resolutionJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                Value<int> version = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                required String entityType,
                required String entityId,
                required int expectedVersion,
                required int remoteVersion,
                required String localSnapshotJson,
                required String remoteSnapshotJson,
                required String state,
                Value<String?> resolutionJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion.insert(
                id: id,
                ownerId: ownerId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                entityType: entityType,
                entityId: entityId,
                expectedVersion: expectedVersion,
                remoteVersion: remoteVersion,
                localSnapshotJson: localSnapshotJson,
                remoteSnapshotJson: remoteSnapshotJson,
                state: state,
                resolutionJson: resolutionJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncConflictsTable, SyncConflict>(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $SyncConflictsTable,
                    SyncConflict
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $SyncConflictsTable,
      SyncConflict,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (
        SyncConflict,
        BaseReferences<_$PorquinhoDatabase, $SyncConflictsTable, SyncConflict>,
      ),
      SyncConflict,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder =
    SyncOutboxCompanion Function({
      required String ownerId,
      required String idempotencyKey,
      required String entityType,
      required String entityId,
      required int expectedVersion,
      required String payloadJson,
      required String state,
      Value<int> attempts,
      Value<String?> nextRetryAt,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$SyncOutboxTableUpdateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<String> ownerId,
      Value<String> idempotencyKey,
      Value<String> entityType,
      Value<String> entityId,
      Value<int> expectedVersion,
      Value<String> payloadJson,
      Value<String> state,
      Value<int> attempts,
      Value<String?> nextRetryAt,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$SyncOutboxTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $SyncOutboxTable,
          SyncOutboxData,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxData,
            BaseReferences<
              _$PorquinhoDatabase,
              $SyncOutboxTable,
              SyncOutboxData
            >,
          ),
          SyncOutboxData,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$PorquinhoDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> expectedVersion = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion(
                ownerId: ownerId,
                idempotencyKey: idempotencyKey,
                entityType: entityType,
                entityId: entityId,
                expectedVersion: expectedVersion,
                payloadJson: payloadJson,
                state: state,
                attempts: attempts,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String idempotencyKey,
                required String entityType,
                required String entityId,
                required int expectedVersion,
                required String payloadJson,
                required String state,
                Value<int> attempts = const Value.absent(),
                Value<String?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                ownerId: ownerId,
                idempotencyKey: idempotencyKey,
                entityType: entityType,
                entityId: entityId,
                expectedVersion: expectedVersion,
                payloadJson: payloadJson,
                state: state,
                attempts: attempts,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxTable, SyncOutboxData>(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $SyncOutboxTable,
                    SyncOutboxData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $SyncOutboxTable,
      SyncOutboxData,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxData,
        BaseReferences<_$PorquinhoDatabase, $SyncOutboxTable, SyncOutboxData>,
      ),
      SyncOutboxData,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String ownerId,
      required String sourceTable,
      required String lastOrderValue,
      Value<String?> lastId,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> ownerId,
      Value<String> sourceTable,
      Value<String> lastOrderValue,
      Value<String?> lastId,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$PorquinhoDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTable => $composableBuilder(
    column: $table.sourceTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastOrderValue => $composableBuilder(
    column: $table.lastOrderValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastId => $composableBuilder(
    column: $table.lastId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$PorquinhoDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTable => $composableBuilder(
    column: $table.sourceTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastOrderValue => $composableBuilder(
    column: $table.lastOrderValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastId => $composableBuilder(
    column: $table.lastId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$PorquinhoDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get sourceTable => $composableBuilder(
    column: $table.sourceTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastOrderValue => $composableBuilder(
    column: $table.lastOrderValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastId =>
      $composableBuilder(column: $table.lastId, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$PorquinhoDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursor,
            BaseReferences<_$PorquinhoDatabase, $SyncCursorsTable, SyncCursor>,
          ),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(
    _$PorquinhoDatabase db,
    $SyncCursorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> sourceTable = const Value.absent(),
                Value<String> lastOrderValue = const Value.absent(),
                Value<String?> lastId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                ownerId: ownerId,
                sourceTable: sourceTable,
                lastOrderValue: lastOrderValue,
                lastId: lastId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String sourceTable,
                required String lastOrderValue,
                Value<String?> lastId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                ownerId: ownerId,
                sourceTable: sourceTable,
                lastOrderValue: lastOrderValue,
                lastId: lastId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncCursorsTable, SyncCursor>(table),
                  BaseReferences<
                    _$PorquinhoDatabase,
                    $SyncCursorsTable,
                    SyncCursor
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$PorquinhoDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursor,
        BaseReferences<_$PorquinhoDatabase, $SyncCursorsTable, SyncCursor>,
      ),
      SyncCursor,
      PrefetchHooks Function()
    >;

class $PorquinhoDatabaseManager {
  final _$PorquinhoDatabase _db;
  $PorquinhoDatabaseManager(this._db);
  $$UserPreferencesTableTableManager get userPreferences =>
      $$UserPreferencesTableTableManager(_db, _db.userPreferences);
  $$PeriodConfigurationsTableTableManager get periodConfigurations =>
      $$PeriodConfigurationsTableTableManager(_db, _db.periodConfigurations);
  $$AccountingPeriodsTableTableManager get accountingPeriods =>
      $$AccountingPeriodsTableTableManager(_db, _db.accountingPeriods);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$SubcategoriesTableTableManager get subcategories =>
      $$SubcategoriesTableTableManager(_db, _db.subcategories);
  $$IncomeRecurrenceTemplatesTableTableManager get incomeRecurrenceTemplates =>
      $$IncomeRecurrenceTemplatesTableTableManager(
        _db,
        _db.incomeRecurrenceTemplates,
      );
  $$ExpenseRecurrenceTemplatesTableTableManager
  get expenseRecurrenceTemplates =>
      $$ExpenseRecurrenceTemplatesTableTableManager(
        _db,
        _db.expenseRecurrenceTemplates,
      );
  $$InvestmentRecurrenceTemplatesTableTableManager
  get investmentRecurrenceTemplates =>
      $$InvestmentRecurrenceTemplatesTableTableManager(
        _db,
        _db.investmentRecurrenceTemplates,
      );
  $$IncomeEntriesTableTableManager get incomeEntries =>
      $$IncomeEntriesTableTableManager(_db, _db.incomeEntries);
  $$ExpenseEntriesTableTableManager get expenseEntries =>
      $$ExpenseEntriesTableTableManager(_db, _db.expenseEntries);
  $$InvestmentAllocationsTableTableManager get investmentAllocations =>
      $$InvestmentAllocationsTableTableManager(_db, _db.investmentAllocations);
  $$AuditEventsTableTableManager get auditEvents =>
      $$AuditEventsTableTableManager(_db, _db.auditEvents);
  $$AppliedSyncOperationsTableTableManager get appliedSyncOperations =>
      $$AppliedSyncOperationsTableTableManager(_db, _db.appliedSyncOperations);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
}
