// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProjectsTable extends Projects
    with TableInfo<$ProjectsTable, ProjectDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _customerMeta =
      const VerificationMeta('customer');
  @override
  late final GeneratedColumn<String> customer = GeneratedColumn<String>(
      'customer', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, description, customer, isDeleted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(Insertable<ProjectDb> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('customer')) {
      context.handle(_customerMeta,
          customer.isAcceptableOrUnknown(data['customer']!, _customerMeta));
    } else if (isInserting) {
      context.missing(_customerMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectDb(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      customer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class ProjectDb extends DataClass implements Insertable<ProjectDb> {
  final String id;
  final String name;
  final String description;
  final String customer;
  final bool isDeleted;
  const ProjectDb(
      {required this.id,
      required this.name,
      required this.description,
      required this.customer,
      required this.isDeleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['customer'] = Variable<String>(customer);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      customer: Value(customer),
      isDeleted: Value(isDeleted),
    );
  }

  factory ProjectDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectDb(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      customer: serializer.fromJson<String>(json['customer']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'customer': serializer.toJson<String>(customer),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  ProjectDb copyWith(
          {String? id,
          String? name,
          String? description,
          String? customer,
          bool? isDeleted}) =>
      ProjectDb(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        customer: customer ?? this.customer,
        isDeleted: isDeleted ?? this.isDeleted,
      );
  ProjectDb copyWithCompanion(ProjectsCompanion data) {
    return ProjectDb(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      customer: data.customer.present ? data.customer.value : this.customer,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectDb(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('customer: $customer, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, customer, isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectDb &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.customer == this.customer &&
          other.isDeleted == this.isDeleted);
}

class ProjectsCompanion extends UpdateCompanion<ProjectDb> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String> customer;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.customer = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    required String description,
    required String customer,
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        description = Value(description),
        customer = Value(customer);
  static Insertable<ProjectDb> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? customer,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (customer != null) 'customer': customer,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? description,
      Value<String>? customer,
      Value<bool>? isDeleted,
      Value<int>? rowid}) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      customer: customer ?? this.customer,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (customer.present) {
      map['customer'] = Variable<String>(customer.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('customer: $customer, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BuildingsTable extends Buildings
    with TableInfo<$BuildingsTable, BuildingDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BuildingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES projects (id) ON DELETE CASCADE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _postalCodeMeta =
      const VerificationMeta('postalCode');
  @override
  late final GeneratedColumn<String> postalCode = GeneratedColumn<String>(
      'postal_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bgfMeta = const VerificationMeta('bgf');
  @override
  late final GeneratedColumn<double> bgf = GeneratedColumn<double>(
      'bgf', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _constructionYearMeta =
      const VerificationMeta('constructionYear');
  @override
  late final GeneratedColumn<int> constructionYear = GeneratedColumn<int>(
      'construction_year', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _renovationYearsMeta =
      const VerificationMeta('renovationYears');
  @override
  late final GeneratedColumn<String> renovationYears = GeneratedColumn<String>(
      'renovation_years', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _protectedMonumentMeta =
      const VerificationMeta('protectedMonument');
  @override
  late final GeneratedColumn<bool> protectedMonument = GeneratedColumn<bool>(
      'protected_monument', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("protected_monument" IN (0, 1))'));
  static const VerificationMeta _unitsMeta = const VerificationMeta('units');
  @override
  late final GeneratedColumn<int> units = GeneratedColumn<int>(
      'units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _floorAreaMeta =
      const VerificationMeta('floorArea');
  @override
  late final GeneratedColumn<double> floorArea = GeneratedColumn<double>(
      'floor_area', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        name,
        address,
        postalCode,
        city,
        type,
        bgf,
        constructionYear,
        renovationYears,
        protectedMonument,
        units,
        floorArea,
        isDeleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'buildings';
  @override
  VerificationContext validateIntegrity(Insertable<BuildingDb> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('postal_code')) {
      context.handle(
          _postalCodeMeta,
          postalCode.isAcceptableOrUnknown(
              data['postal_code']!, _postalCodeMeta));
    } else if (isInserting) {
      context.missing(_postalCodeMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('bgf')) {
      context.handle(
          _bgfMeta, bgf.isAcceptableOrUnknown(data['bgf']!, _bgfMeta));
    } else if (isInserting) {
      context.missing(_bgfMeta);
    }
    if (data.containsKey('construction_year')) {
      context.handle(
          _constructionYearMeta,
          constructionYear.isAcceptableOrUnknown(
              data['construction_year']!, _constructionYearMeta));
    } else if (isInserting) {
      context.missing(_constructionYearMeta);
    }
    if (data.containsKey('renovation_years')) {
      context.handle(
          _renovationYearsMeta,
          renovationYears.isAcceptableOrUnknown(
              data['renovation_years']!, _renovationYearsMeta));
    } else if (isInserting) {
      context.missing(_renovationYearsMeta);
    }
    if (data.containsKey('protected_monument')) {
      context.handle(
          _protectedMonumentMeta,
          protectedMonument.isAcceptableOrUnknown(
              data['protected_monument']!, _protectedMonumentMeta));
    } else if (isInserting) {
      context.missing(_protectedMonumentMeta);
    }
    if (data.containsKey('units')) {
      context.handle(
          _unitsMeta, units.isAcceptableOrUnknown(data['units']!, _unitsMeta));
    } else if (isInserting) {
      context.missing(_unitsMeta);
    }
    if (data.containsKey('floor_area')) {
      context.handle(_floorAreaMeta,
          floorArea.isAcceptableOrUnknown(data['floor_area']!, _floorAreaMeta));
    } else if (isInserting) {
      context.missing(_floorAreaMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BuildingDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BuildingDb(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address'])!,
      postalCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}postal_code'])!,
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      bgf: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}bgf'])!,
      constructionYear: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}construction_year'])!,
      renovationYears: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}renovation_years'])!,
      protectedMonument: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}protected_monument'])!,
      units: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}units'])!,
      floorArea: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}floor_area'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
    );
  }

  @override
  $BuildingsTable createAlias(String alias) {
    return $BuildingsTable(attachedDatabase, alias);
  }
}

class BuildingDb extends DataClass implements Insertable<BuildingDb> {
  final String id;
  final String projectId;
  final String name;
  final String address;
  final String postalCode;
  final String city;
  final String type;
  final double bgf;
  final int constructionYear;
  final String renovationYears;
  final bool protectedMonument;
  final int units;
  final double floorArea;
  final bool isDeleted;
  const BuildingDb(
      {required this.id,
      required this.projectId,
      required this.name,
      required this.address,
      required this.postalCode,
      required this.city,
      required this.type,
      required this.bgf,
      required this.constructionYear,
      required this.renovationYears,
      required this.protectedMonument,
      required this.units,
      required this.floorArea,
      required this.isDeleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['name'] = Variable<String>(name);
    map['address'] = Variable<String>(address);
    map['postal_code'] = Variable<String>(postalCode);
    map['city'] = Variable<String>(city);
    map['type'] = Variable<String>(type);
    map['bgf'] = Variable<double>(bgf);
    map['construction_year'] = Variable<int>(constructionYear);
    map['renovation_years'] = Variable<String>(renovationYears);
    map['protected_monument'] = Variable<bool>(protectedMonument);
    map['units'] = Variable<int>(units);
    map['floor_area'] = Variable<double>(floorArea);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  BuildingsCompanion toCompanion(bool nullToAbsent) {
    return BuildingsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      address: Value(address),
      postalCode: Value(postalCode),
      city: Value(city),
      type: Value(type),
      bgf: Value(bgf),
      constructionYear: Value(constructionYear),
      renovationYears: Value(renovationYears),
      protectedMonument: Value(protectedMonument),
      units: Value(units),
      floorArea: Value(floorArea),
      isDeleted: Value(isDeleted),
    );
  }

  factory BuildingDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BuildingDb(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String>(json['address']),
      postalCode: serializer.fromJson<String>(json['postalCode']),
      city: serializer.fromJson<String>(json['city']),
      type: serializer.fromJson<String>(json['type']),
      bgf: serializer.fromJson<double>(json['bgf']),
      constructionYear: serializer.fromJson<int>(json['constructionYear']),
      renovationYears: serializer.fromJson<String>(json['renovationYears']),
      protectedMonument: serializer.fromJson<bool>(json['protectedMonument']),
      units: serializer.fromJson<int>(json['units']),
      floorArea: serializer.fromJson<double>(json['floorArea']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String>(address),
      'postalCode': serializer.toJson<String>(postalCode),
      'city': serializer.toJson<String>(city),
      'type': serializer.toJson<String>(type),
      'bgf': serializer.toJson<double>(bgf),
      'constructionYear': serializer.toJson<int>(constructionYear),
      'renovationYears': serializer.toJson<String>(renovationYears),
      'protectedMonument': serializer.toJson<bool>(protectedMonument),
      'units': serializer.toJson<int>(units),
      'floorArea': serializer.toJson<double>(floorArea),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  BuildingDb copyWith(
          {String? id,
          String? projectId,
          String? name,
          String? address,
          String? postalCode,
          String? city,
          String? type,
          double? bgf,
          int? constructionYear,
          String? renovationYears,
          bool? protectedMonument,
          int? units,
          double? floorArea,
          bool? isDeleted}) =>
      BuildingDb(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        name: name ?? this.name,
        address: address ?? this.address,
        postalCode: postalCode ?? this.postalCode,
        city: city ?? this.city,
        type: type ?? this.type,
        bgf: bgf ?? this.bgf,
        constructionYear: constructionYear ?? this.constructionYear,
        renovationYears: renovationYears ?? this.renovationYears,
        protectedMonument: protectedMonument ?? this.protectedMonument,
        units: units ?? this.units,
        floorArea: floorArea ?? this.floorArea,
        isDeleted: isDeleted ?? this.isDeleted,
      );
  BuildingDb copyWithCompanion(BuildingsCompanion data) {
    return BuildingDb(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      postalCode:
          data.postalCode.present ? data.postalCode.value : this.postalCode,
      city: data.city.present ? data.city.value : this.city,
      type: data.type.present ? data.type.value : this.type,
      bgf: data.bgf.present ? data.bgf.value : this.bgf,
      constructionYear: data.constructionYear.present
          ? data.constructionYear.value
          : this.constructionYear,
      renovationYears: data.renovationYears.present
          ? data.renovationYears.value
          : this.renovationYears,
      protectedMonument: data.protectedMonument.present
          ? data.protectedMonument.value
          : this.protectedMonument,
      units: data.units.present ? data.units.value : this.units,
      floorArea: data.floorArea.present ? data.floorArea.value : this.floorArea,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BuildingDb(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('postalCode: $postalCode, ')
          ..write('city: $city, ')
          ..write('type: $type, ')
          ..write('bgf: $bgf, ')
          ..write('constructionYear: $constructionYear, ')
          ..write('renovationYears: $renovationYears, ')
          ..write('protectedMonument: $protectedMonument, ')
          ..write('units: $units, ')
          ..write('floorArea: $floorArea, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      projectId,
      name,
      address,
      postalCode,
      city,
      type,
      bgf,
      constructionYear,
      renovationYears,
      protectedMonument,
      units,
      floorArea,
      isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BuildingDb &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.address == this.address &&
          other.postalCode == this.postalCode &&
          other.city == this.city &&
          other.type == this.type &&
          other.bgf == this.bgf &&
          other.constructionYear == this.constructionYear &&
          other.renovationYears == this.renovationYears &&
          other.protectedMonument == this.protectedMonument &&
          other.units == this.units &&
          other.floorArea == this.floorArea &&
          other.isDeleted == this.isDeleted);
}

class BuildingsCompanion extends UpdateCompanion<BuildingDb> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> name;
  final Value<String> address;
  final Value<String> postalCode;
  final Value<String> city;
  final Value<String> type;
  final Value<double> bgf;
  final Value<int> constructionYear;
  final Value<String> renovationYears;
  final Value<bool> protectedMonument;
  final Value<int> units;
  final Value<double> floorArea;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const BuildingsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.postalCode = const Value.absent(),
    this.city = const Value.absent(),
    this.type = const Value.absent(),
    this.bgf = const Value.absent(),
    this.constructionYear = const Value.absent(),
    this.renovationYears = const Value.absent(),
    this.protectedMonument = const Value.absent(),
    this.units = const Value.absent(),
    this.floorArea = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BuildingsCompanion.insert({
    required String id,
    required String projectId,
    required String name,
    required String address,
    required String postalCode,
    required String city,
    required String type,
    required double bgf,
    required int constructionYear,
    required String renovationYears,
    required bool protectedMonument,
    required int units,
    required double floorArea,
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        name = Value(name),
        address = Value(address),
        postalCode = Value(postalCode),
        city = Value(city),
        type = Value(type),
        bgf = Value(bgf),
        constructionYear = Value(constructionYear),
        renovationYears = Value(renovationYears),
        protectedMonument = Value(protectedMonument),
        units = Value(units),
        floorArea = Value(floorArea);
  static Insertable<BuildingDb> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<String>? address,
    Expression<String>? postalCode,
    Expression<String>? city,
    Expression<String>? type,
    Expression<double>? bgf,
    Expression<int>? constructionYear,
    Expression<String>? renovationYears,
    Expression<bool>? protectedMonument,
    Expression<int>? units,
    Expression<double>? floorArea,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (postalCode != null) 'postal_code': postalCode,
      if (city != null) 'city': city,
      if (type != null) 'type': type,
      if (bgf != null) 'bgf': bgf,
      if (constructionYear != null) 'construction_year': constructionYear,
      if (renovationYears != null) 'renovation_years': renovationYears,
      if (protectedMonument != null) 'protected_monument': protectedMonument,
      if (units != null) 'units': units,
      if (floorArea != null) 'floor_area': floorArea,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BuildingsCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? name,
      Value<String>? address,
      Value<String>? postalCode,
      Value<String>? city,
      Value<String>? type,
      Value<double>? bgf,
      Value<int>? constructionYear,
      Value<String>? renovationYears,
      Value<bool>? protectedMonument,
      Value<int>? units,
      Value<double>? floorArea,
      Value<bool>? isDeleted,
      Value<int>? rowid}) {
    return BuildingsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      address: address ?? this.address,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      type: type ?? this.type,
      bgf: bgf ?? this.bgf,
      constructionYear: constructionYear ?? this.constructionYear,
      renovationYears: renovationYears ?? this.renovationYears,
      protectedMonument: protectedMonument ?? this.protectedMonument,
      units: units ?? this.units,
      floorArea: floorArea ?? this.floorArea,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (postalCode.present) {
      map['postal_code'] = Variable<String>(postalCode.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (bgf.present) {
      map['bgf'] = Variable<double>(bgf.value);
    }
    if (constructionYear.present) {
      map['construction_year'] = Variable<int>(constructionYear.value);
    }
    if (renovationYears.present) {
      map['renovation_years'] = Variable<String>(renovationYears.value);
    }
    if (protectedMonument.present) {
      map['protected_monument'] = Variable<bool>(protectedMonument.value);
    }
    if (units.present) {
      map['units'] = Variable<int>(units.value);
    }
    if (floorArea.present) {
      map['floor_area'] = Variable<double>(floorArea.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BuildingsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('postalCode: $postalCode, ')
          ..write('city: $city, ')
          ..write('type: $type, ')
          ..write('bgf: $bgf, ')
          ..write('constructionYear: $constructionYear, ')
          ..write('renovationYears: $renovationYears, ')
          ..write('protectedMonument: $protectedMonument, ')
          ..write('units: $units, ')
          ..write('floorArea: $floorArea, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FloorPlansTable extends FloorPlans
    with TableInfo<$FloorPlansTable, FloorPlanDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FloorPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _buildingIdMeta =
      const VerificationMeta('buildingId');
  @override
  late final GeneratedColumn<String> buildingId = GeneratedColumn<String>(
      'building_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES buildings (id) ON DELETE CASCADE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pdfPathMeta =
      const VerificationMeta('pdfPath');
  @override
  late final GeneratedColumn<String> pdfPath = GeneratedColumn<String>(
      'pdf_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pdfNameMeta =
      const VerificationMeta('pdfName');
  @override
  late final GeneratedColumn<String> pdfName = GeneratedColumn<String>(
      'pdf_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, buildingId, name, pdfPath, pdfName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'floor_plans';
  @override
  VerificationContext validateIntegrity(Insertable<FloorPlanDb> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('building_id')) {
      context.handle(
          _buildingIdMeta,
          buildingId.isAcceptableOrUnknown(
              data['building_id']!, _buildingIdMeta));
    } else if (isInserting) {
      context.missing(_buildingIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('pdf_path')) {
      context.handle(_pdfPathMeta,
          pdfPath.isAcceptableOrUnknown(data['pdf_path']!, _pdfPathMeta));
    }
    if (data.containsKey('pdf_name')) {
      context.handle(_pdfNameMeta,
          pdfName.isAcceptableOrUnknown(data['pdf_name']!, _pdfNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FloorPlanDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FloorPlanDb(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      buildingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}building_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      pdfPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pdf_path']),
      pdfName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pdf_name']),
    );
  }

  @override
  $FloorPlansTable createAlias(String alias) {
    return $FloorPlansTable(attachedDatabase, alias);
  }
}

class FloorPlanDb extends DataClass implements Insertable<FloorPlanDb> {
  final String id;
  final String buildingId;
  final String name;
  final String? pdfPath;
  final String? pdfName;
  const FloorPlanDb(
      {required this.id,
      required this.buildingId,
      required this.name,
      this.pdfPath,
      this.pdfName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['building_id'] = Variable<String>(buildingId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || pdfPath != null) {
      map['pdf_path'] = Variable<String>(pdfPath);
    }
    if (!nullToAbsent || pdfName != null) {
      map['pdf_name'] = Variable<String>(pdfName);
    }
    return map;
  }

  FloorPlansCompanion toCompanion(bool nullToAbsent) {
    return FloorPlansCompanion(
      id: Value(id),
      buildingId: Value(buildingId),
      name: Value(name),
      pdfPath: pdfPath == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfPath),
      pdfName: pdfName == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfName),
    );
  }

  factory FloorPlanDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FloorPlanDb(
      id: serializer.fromJson<String>(json['id']),
      buildingId: serializer.fromJson<String>(json['buildingId']),
      name: serializer.fromJson<String>(json['name']),
      pdfPath: serializer.fromJson<String?>(json['pdfPath']),
      pdfName: serializer.fromJson<String?>(json['pdfName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'buildingId': serializer.toJson<String>(buildingId),
      'name': serializer.toJson<String>(name),
      'pdfPath': serializer.toJson<String?>(pdfPath),
      'pdfName': serializer.toJson<String?>(pdfName),
    };
  }

  FloorPlanDb copyWith(
          {String? id,
          String? buildingId,
          String? name,
          Value<String?> pdfPath = const Value.absent(),
          Value<String?> pdfName = const Value.absent()}) =>
      FloorPlanDb(
        id: id ?? this.id,
        buildingId: buildingId ?? this.buildingId,
        name: name ?? this.name,
        pdfPath: pdfPath.present ? pdfPath.value : this.pdfPath,
        pdfName: pdfName.present ? pdfName.value : this.pdfName,
      );
  FloorPlanDb copyWithCompanion(FloorPlansCompanion data) {
    return FloorPlanDb(
      id: data.id.present ? data.id.value : this.id,
      buildingId:
          data.buildingId.present ? data.buildingId.value : this.buildingId,
      name: data.name.present ? data.name.value : this.name,
      pdfPath: data.pdfPath.present ? data.pdfPath.value : this.pdfPath,
      pdfName: data.pdfName.present ? data.pdfName.value : this.pdfName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FloorPlanDb(')
          ..write('id: $id, ')
          ..write('buildingId: $buildingId, ')
          ..write('name: $name, ')
          ..write('pdfPath: $pdfPath, ')
          ..write('pdfName: $pdfName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, buildingId, name, pdfPath, pdfName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FloorPlanDb &&
          other.id == this.id &&
          other.buildingId == this.buildingId &&
          other.name == this.name &&
          other.pdfPath == this.pdfPath &&
          other.pdfName == this.pdfName);
}

class FloorPlansCompanion extends UpdateCompanion<FloorPlanDb> {
  final Value<String> id;
  final Value<String> buildingId;
  final Value<String> name;
  final Value<String?> pdfPath;
  final Value<String?> pdfName;
  final Value<int> rowid;
  const FloorPlansCompanion({
    this.id = const Value.absent(),
    this.buildingId = const Value.absent(),
    this.name = const Value.absent(),
    this.pdfPath = const Value.absent(),
    this.pdfName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FloorPlansCompanion.insert({
    required String id,
    required String buildingId,
    required String name,
    this.pdfPath = const Value.absent(),
    this.pdfName = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        buildingId = Value(buildingId),
        name = Value(name);
  static Insertable<FloorPlanDb> custom({
    Expression<String>? id,
    Expression<String>? buildingId,
    Expression<String>? name,
    Expression<String>? pdfPath,
    Expression<String>? pdfName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (buildingId != null) 'building_id': buildingId,
      if (name != null) 'name': name,
      if (pdfPath != null) 'pdf_path': pdfPath,
      if (pdfName != null) 'pdf_name': pdfName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FloorPlansCompanion copyWith(
      {Value<String>? id,
      Value<String>? buildingId,
      Value<String>? name,
      Value<String?>? pdfPath,
      Value<String?>? pdfName,
      Value<int>? rowid}) {
    return FloorPlansCompanion(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      name: name ?? this.name,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfName: pdfName ?? this.pdfName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (buildingId.present) {
      map['building_id'] = Variable<String>(buildingId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (pdfPath.present) {
      map['pdf_path'] = Variable<String>(pdfPath.value);
    }
    if (pdfName.present) {
      map['pdf_name'] = Variable<String>(pdfName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FloorPlansCompanion(')
          ..write('id: $id, ')
          ..write('buildingId: $buildingId, ')
          ..write('name: $name, ')
          ..write('pdfPath: $pdfPath, ')
          ..write('pdfName: $pdfName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnlagenTable extends Anlagen with TableInfo<$AnlagenTable, AnlageDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnlagenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _paramsMeta = const VerificationMeta('params');
  @override
  late final GeneratedColumn<String> params = GeneratedColumn<String>(
      'params', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _floorIdMeta =
      const VerificationMeta('floorId');
  @override
  late final GeneratedColumn<String> floorId = GeneratedColumn<String>(
      'floor_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _buildingIdMeta =
      const VerificationMeta('buildingId');
  @override
  late final GeneratedColumn<String> buildingId = GeneratedColumn<String>(
      'building_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES buildings (id) ON DELETE CASCADE'));
  static const VerificationMeta _isMarkerMeta =
      const VerificationMeta('isMarker');
  @override
  late final GeneratedColumn<bool> isMarker = GeneratedColumn<bool>(
      'is_marker', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_marker" IN (0, 1))'));
  static const VerificationMeta _markerInfoMeta =
      const VerificationMeta('markerInfo');
  @override
  late final GeneratedColumn<String> markerInfo = GeneratedColumn<String>(
      'marker_info', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _markerTypeMeta =
      const VerificationMeta('markerType');
  @override
  late final GeneratedColumn<String> markerType = GeneratedColumn<String>(
      'marker_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _disciplineMeta =
      const VerificationMeta('discipline');
  @override
  late final GeneratedColumn<String> discipline = GeneratedColumn<String>(
      'discipline', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        parentId,
        name,
        params,
        floorId,
        buildingId,
        isMarker,
        markerInfo,
        markerType,
        discipline,
        isDeleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'anlagen';
  @override
  VerificationContext validateIntegrity(Insertable<AnlageDb> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('params')) {
      context.handle(_paramsMeta,
          params.isAcceptableOrUnknown(data['params']!, _paramsMeta));
    } else if (isInserting) {
      context.missing(_paramsMeta);
    }
    if (data.containsKey('floor_id')) {
      context.handle(_floorIdMeta,
          floorId.isAcceptableOrUnknown(data['floor_id']!, _floorIdMeta));
    }
    if (data.containsKey('building_id')) {
      context.handle(
          _buildingIdMeta,
          buildingId.isAcceptableOrUnknown(
              data['building_id']!, _buildingIdMeta));
    } else if (isInserting) {
      context.missing(_buildingIdMeta);
    }
    if (data.containsKey('is_marker')) {
      context.handle(_isMarkerMeta,
          isMarker.isAcceptableOrUnknown(data['is_marker']!, _isMarkerMeta));
    } else if (isInserting) {
      context.missing(_isMarkerMeta);
    }
    if (data.containsKey('marker_info')) {
      context.handle(
          _markerInfoMeta,
          markerInfo.isAcceptableOrUnknown(
              data['marker_info']!, _markerInfoMeta));
    }
    if (data.containsKey('marker_type')) {
      context.handle(
          _markerTypeMeta,
          markerType.isAcceptableOrUnknown(
              data['marker_type']!, _markerTypeMeta));
    } else if (isInserting) {
      context.missing(_markerTypeMeta);
    }
    if (data.containsKey('discipline')) {
      context.handle(
          _disciplineMeta,
          discipline.isAcceptableOrUnknown(
              data['discipline']!, _disciplineMeta));
    } else if (isInserting) {
      context.missing(_disciplineMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnlageDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnlageDb(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      params: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}params'])!,
      floorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}floor_id']),
      buildingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}building_id'])!,
      isMarker: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_marker'])!,
      markerInfo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}marker_info']),
      markerType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}marker_type'])!,
      discipline: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}discipline'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
    );
  }

  @override
  $AnlagenTable createAlias(String alias) {
    return $AnlagenTable(attachedDatabase, alias);
  }
}

class AnlageDb extends DataClass implements Insertable<AnlageDb> {
  final String id;
  final String? parentId;
  final String name;
  final String params;
  final String? floorId;
  final String buildingId;
  final bool isMarker;
  final String? markerInfo;
  final String markerType;
  final String discipline;
  final bool isDeleted;
  const AnlageDb(
      {required this.id,
      this.parentId,
      required this.name,
      required this.params,
      this.floorId,
      required this.buildingId,
      required this.isMarker,
      this.markerInfo,
      required this.markerType,
      required this.discipline,
      required this.isDeleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['params'] = Variable<String>(params);
    if (!nullToAbsent || floorId != null) {
      map['floor_id'] = Variable<String>(floorId);
    }
    map['building_id'] = Variable<String>(buildingId);
    map['is_marker'] = Variable<bool>(isMarker);
    if (!nullToAbsent || markerInfo != null) {
      map['marker_info'] = Variable<String>(markerInfo);
    }
    map['marker_type'] = Variable<String>(markerType);
    map['discipline'] = Variable<String>(discipline);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  AnlagenCompanion toCompanion(bool nullToAbsent) {
    return AnlagenCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      params: Value(params),
      floorId: floorId == null && nullToAbsent
          ? const Value.absent()
          : Value(floorId),
      buildingId: Value(buildingId),
      isMarker: Value(isMarker),
      markerInfo: markerInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(markerInfo),
      markerType: Value(markerType),
      discipline: Value(discipline),
      isDeleted: Value(isDeleted),
    );
  }

  factory AnlageDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnlageDb(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      params: serializer.fromJson<String>(json['params']),
      floorId: serializer.fromJson<String?>(json['floorId']),
      buildingId: serializer.fromJson<String>(json['buildingId']),
      isMarker: serializer.fromJson<bool>(json['isMarker']),
      markerInfo: serializer.fromJson<String?>(json['markerInfo']),
      markerType: serializer.fromJson<String>(json['markerType']),
      discipline: serializer.fromJson<String>(json['discipline']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'params': serializer.toJson<String>(params),
      'floorId': serializer.toJson<String?>(floorId),
      'buildingId': serializer.toJson<String>(buildingId),
      'isMarker': serializer.toJson<bool>(isMarker),
      'markerInfo': serializer.toJson<String?>(markerInfo),
      'markerType': serializer.toJson<String>(markerType),
      'discipline': serializer.toJson<String>(discipline),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  AnlageDb copyWith(
          {String? id,
          Value<String?> parentId = const Value.absent(),
          String? name,
          String? params,
          Value<String?> floorId = const Value.absent(),
          String? buildingId,
          bool? isMarker,
          Value<String?> markerInfo = const Value.absent(),
          String? markerType,
          String? discipline,
          bool? isDeleted}) =>
      AnlageDb(
        id: id ?? this.id,
        parentId: parentId.present ? parentId.value : this.parentId,
        name: name ?? this.name,
        params: params ?? this.params,
        floorId: floorId.present ? floorId.value : this.floorId,
        buildingId: buildingId ?? this.buildingId,
        isMarker: isMarker ?? this.isMarker,
        markerInfo: markerInfo.present ? markerInfo.value : this.markerInfo,
        markerType: markerType ?? this.markerType,
        discipline: discipline ?? this.discipline,
        isDeleted: isDeleted ?? this.isDeleted,
      );
  AnlageDb copyWithCompanion(AnlagenCompanion data) {
    return AnlageDb(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      params: data.params.present ? data.params.value : this.params,
      floorId: data.floorId.present ? data.floorId.value : this.floorId,
      buildingId:
          data.buildingId.present ? data.buildingId.value : this.buildingId,
      isMarker: data.isMarker.present ? data.isMarker.value : this.isMarker,
      markerInfo:
          data.markerInfo.present ? data.markerInfo.value : this.markerInfo,
      markerType:
          data.markerType.present ? data.markerType.value : this.markerType,
      discipline:
          data.discipline.present ? data.discipline.value : this.discipline,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnlageDb(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('params: $params, ')
          ..write('floorId: $floorId, ')
          ..write('buildingId: $buildingId, ')
          ..write('isMarker: $isMarker, ')
          ..write('markerInfo: $markerInfo, ')
          ..write('markerType: $markerType, ')
          ..write('discipline: $discipline, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, name, params, floorId,
      buildingId, isMarker, markerInfo, markerType, discipline, isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnlageDb &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.params == this.params &&
          other.floorId == this.floorId &&
          other.buildingId == this.buildingId &&
          other.isMarker == this.isMarker &&
          other.markerInfo == this.markerInfo &&
          other.markerType == this.markerType &&
          other.discipline == this.discipline &&
          other.isDeleted == this.isDeleted);
}

class AnlagenCompanion extends UpdateCompanion<AnlageDb> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<String> params;
  final Value<String?> floorId;
  final Value<String> buildingId;
  final Value<bool> isMarker;
  final Value<String?> markerInfo;
  final Value<String> markerType;
  final Value<String> discipline;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const AnlagenCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.params = const Value.absent(),
    this.floorId = const Value.absent(),
    this.buildingId = const Value.absent(),
    this.isMarker = const Value.absent(),
    this.markerInfo = const Value.absent(),
    this.markerType = const Value.absent(),
    this.discipline = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnlagenCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    required String params,
    this.floorId = const Value.absent(),
    required String buildingId,
    required bool isMarker,
    this.markerInfo = const Value.absent(),
    required String markerType,
    required String discipline,
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        params = Value(params),
        buildingId = Value(buildingId),
        isMarker = Value(isMarker),
        markerType = Value(markerType),
        discipline = Value(discipline);
  static Insertable<AnlageDb> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<String>? params,
    Expression<String>? floorId,
    Expression<String>? buildingId,
    Expression<bool>? isMarker,
    Expression<String>? markerInfo,
    Expression<String>? markerType,
    Expression<String>? discipline,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (params != null) 'params': params,
      if (floorId != null) 'floor_id': floorId,
      if (buildingId != null) 'building_id': buildingId,
      if (isMarker != null) 'is_marker': isMarker,
      if (markerInfo != null) 'marker_info': markerInfo,
      if (markerType != null) 'marker_type': markerType,
      if (discipline != null) 'discipline': discipline,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnlagenCompanion copyWith(
      {Value<String>? id,
      Value<String?>? parentId,
      Value<String>? name,
      Value<String>? params,
      Value<String?>? floorId,
      Value<String>? buildingId,
      Value<bool>? isMarker,
      Value<String?>? markerInfo,
      Value<String>? markerType,
      Value<String>? discipline,
      Value<bool>? isDeleted,
      Value<int>? rowid}) {
    return AnlagenCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      params: params ?? this.params,
      floorId: floorId ?? this.floorId,
      buildingId: buildingId ?? this.buildingId,
      isMarker: isMarker ?? this.isMarker,
      markerInfo: markerInfo ?? this.markerInfo,
      markerType: markerType ?? this.markerType,
      discipline: discipline ?? this.discipline,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (params.present) {
      map['params'] = Variable<String>(params.value);
    }
    if (floorId.present) {
      map['floor_id'] = Variable<String>(floorId.value);
    }
    if (buildingId.present) {
      map['building_id'] = Variable<String>(buildingId.value);
    }
    if (isMarker.present) {
      map['is_marker'] = Variable<bool>(isMarker.value);
    }
    if (markerInfo.present) {
      map['marker_info'] = Variable<String>(markerInfo.value);
    }
    if (markerType.present) {
      map['marker_type'] = Variable<String>(markerType.value);
    }
    if (discipline.present) {
      map['discipline'] = Variable<String>(discipline.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnlagenCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('params: $params, ')
          ..write('floorId: $floorId, ')
          ..write('buildingId: $buildingId, ')
          ..write('isMarker: $isMarker, ')
          ..write('markerInfo: $markerInfo, ')
          ..write('markerType: $markerType, ')
          ..write('discipline: $discipline, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTableTable extends AttachmentsTable
    with TableInfo<$AttachmentsTableTable, AttachmentsTableDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _buildingIdMeta =
      const VerificationMeta('buildingId');
  @override
  late final GeneratedColumn<String> buildingId = GeneratedColumn<String>(
      'building_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES buildings (id) ON DELETE CASCADE'));
  static const VerificationMeta _photosMeta = const VerificationMeta('photos');
  @override
  late final GeneratedColumn<String> photos = GeneratedColumn<String>(
      'photos', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plansMeta = const VerificationMeta('plans');
  @override
  late final GeneratedColumn<String> plans = GeneratedColumn<String>(
      'plans', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, buildingId, photos, plans, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments_table';
  @override
  VerificationContext validateIntegrity(Insertable<AttachmentsTableDb> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('building_id')) {
      context.handle(
          _buildingIdMeta,
          buildingId.isAcceptableOrUnknown(
              data['building_id']!, _buildingIdMeta));
    } else if (isInserting) {
      context.missing(_buildingIdMeta);
    }
    if (data.containsKey('photos')) {
      context.handle(_photosMeta,
          photos.isAcceptableOrUnknown(data['photos']!, _photosMeta));
    } else if (isInserting) {
      context.missing(_photosMeta);
    }
    if (data.containsKey('plans')) {
      context.handle(
          _plansMeta, plans.isAcceptableOrUnknown(data['plans']!, _plansMeta));
    } else if (isInserting) {
      context.missing(_plansMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttachmentsTableDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentsTableDb(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      buildingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}building_id'])!,
      photos: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photos'])!,
      plans: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plans'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
    );
  }

  @override
  $AttachmentsTableTable createAlias(String alias) {
    return $AttachmentsTableTable(attachedDatabase, alias);
  }
}

class AttachmentsTableDb extends DataClass
    implements Insertable<AttachmentsTableDb> {
  final String id;
  final String buildingId;
  final String photos;
  final String plans;
  final String notes;
  const AttachmentsTableDb(
      {required this.id,
      required this.buildingId,
      required this.photos,
      required this.plans,
      required this.notes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['building_id'] = Variable<String>(buildingId);
    map['photos'] = Variable<String>(photos);
    map['plans'] = Variable<String>(plans);
    map['notes'] = Variable<String>(notes);
    return map;
  }

  AttachmentsTableCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsTableCompanion(
      id: Value(id),
      buildingId: Value(buildingId),
      photos: Value(photos),
      plans: Value(plans),
      notes: Value(notes),
    );
  }

  factory AttachmentsTableDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentsTableDb(
      id: serializer.fromJson<String>(json['id']),
      buildingId: serializer.fromJson<String>(json['buildingId']),
      photos: serializer.fromJson<String>(json['photos']),
      plans: serializer.fromJson<String>(json['plans']),
      notes: serializer.fromJson<String>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'buildingId': serializer.toJson<String>(buildingId),
      'photos': serializer.toJson<String>(photos),
      'plans': serializer.toJson<String>(plans),
      'notes': serializer.toJson<String>(notes),
    };
  }

  AttachmentsTableDb copyWith(
          {String? id,
          String? buildingId,
          String? photos,
          String? plans,
          String? notes}) =>
      AttachmentsTableDb(
        id: id ?? this.id,
        buildingId: buildingId ?? this.buildingId,
        photos: photos ?? this.photos,
        plans: plans ?? this.plans,
        notes: notes ?? this.notes,
      );
  AttachmentsTableDb copyWithCompanion(AttachmentsTableCompanion data) {
    return AttachmentsTableDb(
      id: data.id.present ? data.id.value : this.id,
      buildingId:
          data.buildingId.present ? data.buildingId.value : this.buildingId,
      photos: data.photos.present ? data.photos.value : this.photos,
      plans: data.plans.present ? data.plans.value : this.plans,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsTableDb(')
          ..write('id: $id, ')
          ..write('buildingId: $buildingId, ')
          ..write('photos: $photos, ')
          ..write('plans: $plans, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, buildingId, photos, plans, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentsTableDb &&
          other.id == this.id &&
          other.buildingId == this.buildingId &&
          other.photos == this.photos &&
          other.plans == this.plans &&
          other.notes == this.notes);
}

class AttachmentsTableCompanion extends UpdateCompanion<AttachmentsTableDb> {
  final Value<String> id;
  final Value<String> buildingId;
  final Value<String> photos;
  final Value<String> plans;
  final Value<String> notes;
  final Value<int> rowid;
  const AttachmentsTableCompanion({
    this.id = const Value.absent(),
    this.buildingId = const Value.absent(),
    this.photos = const Value.absent(),
    this.plans = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsTableCompanion.insert({
    required String id,
    required String buildingId,
    required String photos,
    required String plans,
    required String notes,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        buildingId = Value(buildingId),
        photos = Value(photos),
        plans = Value(plans),
        notes = Value(notes);
  static Insertable<AttachmentsTableDb> custom({
    Expression<String>? id,
    Expression<String>? buildingId,
    Expression<String>? photos,
    Expression<String>? plans,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (buildingId != null) 'building_id': buildingId,
      if (photos != null) 'photos': photos,
      if (plans != null) 'plans': plans,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? buildingId,
      Value<String>? photos,
      Value<String>? plans,
      Value<String>? notes,
      Value<int>? rowid}) {
    return AttachmentsTableCompanion(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      photos: photos ?? this.photos,
      plans: plans ?? this.plans,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (buildingId.present) {
      map['building_id'] = Variable<String>(buildingId.value);
    }
    if (photos.present) {
      map['photos'] = Variable<String>(photos.value);
    }
    if (plans.present) {
      map['plans'] = Variable<String>(plans.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsTableCompanion(')
          ..write('id: $id, ')
          ..write('buildingId: $buildingId, ')
          ..write('photos: $photos, ')
          ..write('plans: $plans, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DisziplinenTable extends Disziplinen
    with TableInfo<$DisziplinenTable, DisziplinDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DisziplinenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _buildingIdMeta =
      const VerificationMeta('buildingId');
  @override
  late final GeneratedColumn<String> buildingId = GeneratedColumn<String>(
      'building_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES buildings (id) ON DELETE CASCADE'));
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [buildingId, label, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'disziplinen';
  @override
  VerificationContext validateIntegrity(Insertable<DisziplinDb> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('building_id')) {
      context.handle(
          _buildingIdMeta,
          buildingId.isAcceptableOrUnknown(
              data['building_id']!, _buildingIdMeta));
    } else if (isInserting) {
      context.missing(_buildingIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {buildingId, label};
  @override
  DisziplinDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DisziplinDb(
      buildingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}building_id'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!,
    );
  }

  @override
  $DisziplinenTable createAlias(String alias) {
    return $DisziplinenTable(attachedDatabase, alias);
  }
}

class DisziplinDb extends DataClass implements Insertable<DisziplinDb> {
  final String buildingId;
  final String label;
  final String data;
  const DisziplinDb(
      {required this.buildingId, required this.label, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['building_id'] = Variable<String>(buildingId);
    map['label'] = Variable<String>(label);
    map['data'] = Variable<String>(data);
    return map;
  }

  DisziplinenCompanion toCompanion(bool nullToAbsent) {
    return DisziplinenCompanion(
      buildingId: Value(buildingId),
      label: Value(label),
      data: Value(data),
    );
  }

  factory DisziplinDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DisziplinDb(
      buildingId: serializer.fromJson<String>(json['buildingId']),
      label: serializer.fromJson<String>(json['label']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'buildingId': serializer.toJson<String>(buildingId),
      'label': serializer.toJson<String>(label),
      'data': serializer.toJson<String>(data),
    };
  }

  DisziplinDb copyWith({String? buildingId, String? label, String? data}) =>
      DisziplinDb(
        buildingId: buildingId ?? this.buildingId,
        label: label ?? this.label,
        data: data ?? this.data,
      );
  DisziplinDb copyWithCompanion(DisziplinenCompanion data) {
    return DisziplinDb(
      buildingId:
          data.buildingId.present ? data.buildingId.value : this.buildingId,
      label: data.label.present ? data.label.value : this.label,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DisziplinDb(')
          ..write('buildingId: $buildingId, ')
          ..write('label: $label, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(buildingId, label, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DisziplinDb &&
          other.buildingId == this.buildingId &&
          other.label == this.label &&
          other.data == this.data);
}

class DisziplinenCompanion extends UpdateCompanion<DisziplinDb> {
  final Value<String> buildingId;
  final Value<String> label;
  final Value<String> data;
  final Value<int> rowid;
  const DisziplinenCompanion({
    this.buildingId = const Value.absent(),
    this.label = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DisziplinenCompanion.insert({
    required String buildingId,
    required String label,
    required String data,
    this.rowid = const Value.absent(),
  })  : buildingId = Value(buildingId),
        label = Value(label),
        data = Value(data);
  static Insertable<DisziplinDb> custom({
    Expression<String>? buildingId,
    Expression<String>? label,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (buildingId != null) 'building_id': buildingId,
      if (label != null) 'label': label,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DisziplinenCompanion copyWith(
      {Value<String>? buildingId,
      Value<String>? label,
      Value<String>? data,
      Value<int>? rowid}) {
    return DisziplinenCompanion(
      buildingId: buildingId ?? this.buildingId,
      label: label ?? this.label,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (buildingId.present) {
      map['building_id'] = Variable<String>(buildingId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DisziplinenCompanion(')
          ..write('buildingId: $buildingId, ')
          ..write('label: $label, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TemplatesTable extends Templates
    with TableInfo<$TemplatesTable, TemplateDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES projects (id) ON DELETE CASCADE'));
  static const VerificationMeta _gewerkMeta = const VerificationMeta('gewerk');
  @override
  late final GeneratedColumn<String> gewerk = GeneratedColumn<String>(
      'gewerk', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _anlageBauteilMeta =
      const VerificationMeta('anlageBauteil');
  @override
  late final GeneratedColumn<String> anlageBauteil = GeneratedColumn<String>(
      'anlage_bauteil', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _anlagentypMeta =
      const VerificationMeta('anlagentyp');
  @override
  late final GeneratedColumn<String> anlagentyp = GeneratedColumn<String>(
      'anlagentyp', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bezeichnungMeta =
      const VerificationMeta('bezeichnung');
  @override
  late final GeneratedColumn<String> bezeichnung = GeneratedColumn<String>(
      'bezeichnung', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parameterMeta =
      const VerificationMeta('parameter');
  @override
  late final GeneratedColumn<String> parameter = GeneratedColumn<String>(
      'parameter', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        gewerk,
        anlageBauteil,
        anlagentyp,
        bezeichnung,
        parameter
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'templates';
  @override
  VerificationContext validateIntegrity(Insertable<TemplateDb> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('gewerk')) {
      context.handle(_gewerkMeta,
          gewerk.isAcceptableOrUnknown(data['gewerk']!, _gewerkMeta));
    } else if (isInserting) {
      context.missing(_gewerkMeta);
    }
    if (data.containsKey('anlage_bauteil')) {
      context.handle(
          _anlageBauteilMeta,
          anlageBauteil.isAcceptableOrUnknown(
              data['anlage_bauteil']!, _anlageBauteilMeta));
    } else if (isInserting) {
      context.missing(_anlageBauteilMeta);
    }
    if (data.containsKey('anlagentyp')) {
      context.handle(
          _anlagentypMeta,
          anlagentyp.isAcceptableOrUnknown(
              data['anlagentyp']!, _anlagentypMeta));
    } else if (isInserting) {
      context.missing(_anlagentypMeta);
    }
    if (data.containsKey('bezeichnung')) {
      context.handle(
          _bezeichnungMeta,
          bezeichnung.isAcceptableOrUnknown(
              data['bezeichnung']!, _bezeichnungMeta));
    } else if (isInserting) {
      context.missing(_bezeichnungMeta);
    }
    if (data.containsKey('parameter')) {
      context.handle(_parameterMeta,
          parameter.isAcceptableOrUnknown(data['parameter']!, _parameterMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TemplateDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TemplateDb(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      gewerk: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gewerk'])!,
      anlageBauteil: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}anlage_bauteil'])!,
      anlagentyp: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}anlagentyp'])!,
      bezeichnung: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bezeichnung'])!,
      parameter: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parameter']),
    );
  }

  @override
  $TemplatesTable createAlias(String alias) {
    return $TemplatesTable(attachedDatabase, alias);
  }
}

class TemplateDb extends DataClass implements Insertable<TemplateDb> {
  final int id;
  final String projectId;
  final String gewerk;
  final String anlageBauteil;
  final String anlagentyp;
  final String bezeichnung;
  final String? parameter;
  const TemplateDb(
      {required this.id,
      required this.projectId,
      required this.gewerk,
      required this.anlageBauteil,
      required this.anlagentyp,
      required this.bezeichnung,
      this.parameter});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<String>(projectId);
    map['gewerk'] = Variable<String>(gewerk);
    map['anlage_bauteil'] = Variable<String>(anlageBauteil);
    map['anlagentyp'] = Variable<String>(anlagentyp);
    map['bezeichnung'] = Variable<String>(bezeichnung);
    if (!nullToAbsent || parameter != null) {
      map['parameter'] = Variable<String>(parameter);
    }
    return map;
  }

  TemplatesCompanion toCompanion(bool nullToAbsent) {
    return TemplatesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      gewerk: Value(gewerk),
      anlageBauteil: Value(anlageBauteil),
      anlagentyp: Value(anlagentyp),
      bezeichnung: Value(bezeichnung),
      parameter: parameter == null && nullToAbsent
          ? const Value.absent()
          : Value(parameter),
    );
  }

  factory TemplateDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TemplateDb(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      gewerk: serializer.fromJson<String>(json['gewerk']),
      anlageBauteil: serializer.fromJson<String>(json['anlageBauteil']),
      anlagentyp: serializer.fromJson<String>(json['anlagentyp']),
      bezeichnung: serializer.fromJson<String>(json['bezeichnung']),
      parameter: serializer.fromJson<String?>(json['parameter']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<String>(projectId),
      'gewerk': serializer.toJson<String>(gewerk),
      'anlageBauteil': serializer.toJson<String>(anlageBauteil),
      'anlagentyp': serializer.toJson<String>(anlagentyp),
      'bezeichnung': serializer.toJson<String>(bezeichnung),
      'parameter': serializer.toJson<String?>(parameter),
    };
  }

  TemplateDb copyWith(
          {int? id,
          String? projectId,
          String? gewerk,
          String? anlageBauteil,
          String? anlagentyp,
          String? bezeichnung,
          Value<String?> parameter = const Value.absent()}) =>
      TemplateDb(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        gewerk: gewerk ?? this.gewerk,
        anlageBauteil: anlageBauteil ?? this.anlageBauteil,
        anlagentyp: anlagentyp ?? this.anlagentyp,
        bezeichnung: bezeichnung ?? this.bezeichnung,
        parameter: parameter.present ? parameter.value : this.parameter,
      );
  TemplateDb copyWithCompanion(TemplatesCompanion data) {
    return TemplateDb(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      gewerk: data.gewerk.present ? data.gewerk.value : this.gewerk,
      anlageBauteil: data.anlageBauteil.present
          ? data.anlageBauteil.value
          : this.anlageBauteil,
      anlagentyp:
          data.anlagentyp.present ? data.anlagentyp.value : this.anlagentyp,
      bezeichnung:
          data.bezeichnung.present ? data.bezeichnung.value : this.bezeichnung,
      parameter: data.parameter.present ? data.parameter.value : this.parameter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TemplateDb(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('gewerk: $gewerk, ')
          ..write('anlageBauteil: $anlageBauteil, ')
          ..write('anlagentyp: $anlagentyp, ')
          ..write('bezeichnung: $bezeichnung, ')
          ..write('parameter: $parameter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, projectId, gewerk, anlageBauteil, anlagentyp, bezeichnung, parameter);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TemplateDb &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.gewerk == this.gewerk &&
          other.anlageBauteil == this.anlageBauteil &&
          other.anlagentyp == this.anlagentyp &&
          other.bezeichnung == this.bezeichnung &&
          other.parameter == this.parameter);
}

class TemplatesCompanion extends UpdateCompanion<TemplateDb> {
  final Value<int> id;
  final Value<String> projectId;
  final Value<String> gewerk;
  final Value<String> anlageBauteil;
  final Value<String> anlagentyp;
  final Value<String> bezeichnung;
  final Value<String?> parameter;
  const TemplatesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.gewerk = const Value.absent(),
    this.anlageBauteil = const Value.absent(),
    this.anlagentyp = const Value.absent(),
    this.bezeichnung = const Value.absent(),
    this.parameter = const Value.absent(),
  });
  TemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String projectId,
    required String gewerk,
    required String anlageBauteil,
    required String anlagentyp,
    required String bezeichnung,
    this.parameter = const Value.absent(),
  })  : projectId = Value(projectId),
        gewerk = Value(gewerk),
        anlageBauteil = Value(anlageBauteil),
        anlagentyp = Value(anlagentyp),
        bezeichnung = Value(bezeichnung);
  static Insertable<TemplateDb> custom({
    Expression<int>? id,
    Expression<String>? projectId,
    Expression<String>? gewerk,
    Expression<String>? anlageBauteil,
    Expression<String>? anlagentyp,
    Expression<String>? bezeichnung,
    Expression<String>? parameter,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (gewerk != null) 'gewerk': gewerk,
      if (anlageBauteil != null) 'anlage_bauteil': anlageBauteil,
      if (anlagentyp != null) 'anlagentyp': anlagentyp,
      if (bezeichnung != null) 'bezeichnung': bezeichnung,
      if (parameter != null) 'parameter': parameter,
    });
  }

  TemplatesCompanion copyWith(
      {Value<int>? id,
      Value<String>? projectId,
      Value<String>? gewerk,
      Value<String>? anlageBauteil,
      Value<String>? anlagentyp,
      Value<String>? bezeichnung,
      Value<String?>? parameter}) {
    return TemplatesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      gewerk: gewerk ?? this.gewerk,
      anlageBauteil: anlageBauteil ?? this.anlageBauteil,
      anlagentyp: anlagentyp ?? this.anlagentyp,
      bezeichnung: bezeichnung ?? this.bezeichnung,
      parameter: parameter ?? this.parameter,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (gewerk.present) {
      map['gewerk'] = Variable<String>(gewerk.value);
    }
    if (anlageBauteil.present) {
      map['anlage_bauteil'] = Variable<String>(anlageBauteil.value);
    }
    if (anlagentyp.present) {
      map['anlagentyp'] = Variable<String>(anlagentyp.value);
    }
    if (bezeichnung.present) {
      map['bezeichnung'] = Variable<String>(bezeichnung.value);
    }
    if (parameter.present) {
      map['parameter'] = Variable<String>(parameter.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TemplatesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('gewerk: $gewerk, ')
          ..write('anlageBauteil: $anlageBauteil, ')
          ..write('anlagentyp: $anlagentyp, ')
          ..write('bezeichnung: $bezeichnung, ')
          ..write('parameter: $parameter')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $BuildingsTable buildings = $BuildingsTable(this);
  late final $FloorPlansTable floorPlans = $FloorPlansTable(this);
  late final $AnlagenTable anlagen = $AnlagenTable(this);
  late final $AttachmentsTableTable attachmentsTable =
      $AttachmentsTableTable(this);
  late final $DisziplinenTable disziplinen = $DisziplinenTable(this);
  late final $TemplatesTable templates = $TemplatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        projects,
        buildings,
        floorPlans,
        anlagen,
        attachmentsTable,
        disziplinen,
        templates
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('projects',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('buildings', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('buildings',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('floor_plans', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('buildings',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('anlagen', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('buildings',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('attachments_table', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('buildings',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('disziplinen', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('projects',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('templates', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  required String id,
  required String name,
  required String description,
  required String customer,
  Value<bool> isDeleted,
  Value<int> rowid,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> description,
  Value<String> customer,
  Value<bool> isDeleted,
  Value<int> rowid,
});

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, ProjectDb> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BuildingsTable, List<BuildingDb>>
      _buildingsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.buildings,
              aliasName:
                  $_aliasNameGenerator(db.projects.id, db.buildings.projectId));

  $$BuildingsTableProcessedTableManager get buildingsRefs {
    final manager = $$BuildingsTableTableManager($_db, $_db.buildings)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_buildingsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$TemplatesTable, List<TemplateDb>>
      _templatesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.templates,
              aliasName:
                  $_aliasNameGenerator(db.projects.id, db.templates.projectId));

  $$TemplatesTableProcessedTableManager get templatesRefs {
    final manager = $$TemplatesTableTableManager($_db, $_db.templates)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_templatesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customer => $composableBuilder(
      column: $table.customer, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  Expression<bool> buildingsRefs(
      Expression<bool> Function($$BuildingsTableFilterComposer f) f) {
    final $$BuildingsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableFilterComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> templatesRefs(
      Expression<bool> Function($$TemplatesTableFilterComposer f) f) {
    final $$TemplatesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.templates,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TemplatesTableFilterComposer(
              $db: $db,
              $table: $db.templates,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customer => $composableBuilder(
      column: $table.customer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get customer =>
      $composableBuilder(column: $table.customer, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  Expression<T> buildingsRefs<T extends Object>(
      Expression<T> Function($$BuildingsTableAnnotationComposer a) f) {
    final $$BuildingsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableAnnotationComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> templatesRefs<T extends Object>(
      Expression<T> Function($$TemplatesTableAnnotationComposer a) f) {
    final $$TemplatesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.templates,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TemplatesTableAnnotationComposer(
              $db: $db,
              $table: $db.templates,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProjectsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectsTable,
    ProjectDb,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (ProjectDb, $$ProjectsTableReferences),
    ProjectDb,
    PrefetchHooks Function({bool buildingsRefs, bool templatesRefs})> {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String> customer = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion(
            id: id,
            name: name,
            description: description,
            customer: customer,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String description,
            required String customer,
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion.insert(
            id: id,
            name: name,
            description: description,
            customer: customer,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ProjectsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {buildingsRefs = false, templatesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (buildingsRefs) db.buildings,
                if (templatesRefs) db.templates
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (buildingsRefs)
                    await $_getPrefetchedData<ProjectDb, $ProjectsTable,
                            BuildingDb>(
                        currentTable: table,
                        referencedTable:
                            $$ProjectsTableReferences._buildingsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableReferences(db, table, p0)
                                .buildingsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items),
                  if (templatesRefs)
                    await $_getPrefetchedData<ProjectDb, $ProjectsTable,
                            TemplateDb>(
                        currentTable: table,
                        referencedTable:
                            $$ProjectsTableReferences._templatesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableReferences(db, table, p0)
                                .templatesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProjectsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProjectsTable,
    ProjectDb,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (ProjectDb, $$ProjectsTableReferences),
    ProjectDb,
    PrefetchHooks Function({bool buildingsRefs, bool templatesRefs})>;
typedef $$BuildingsTableCreateCompanionBuilder = BuildingsCompanion Function({
  required String id,
  required String projectId,
  required String name,
  required String address,
  required String postalCode,
  required String city,
  required String type,
  required double bgf,
  required int constructionYear,
  required String renovationYears,
  required bool protectedMonument,
  required int units,
  required double floorArea,
  Value<bool> isDeleted,
  Value<int> rowid,
});
typedef $$BuildingsTableUpdateCompanionBuilder = BuildingsCompanion Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> name,
  Value<String> address,
  Value<String> postalCode,
  Value<String> city,
  Value<String> type,
  Value<double> bgf,
  Value<int> constructionYear,
  Value<String> renovationYears,
  Value<bool> protectedMonument,
  Value<int> units,
  Value<double> floorArea,
  Value<bool> isDeleted,
  Value<int> rowid,
});

final class $$BuildingsTableReferences
    extends BaseReferences<_$AppDatabase, $BuildingsTable, BuildingDb> {
  $$BuildingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
          $_aliasNameGenerator(db.buildings.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager($_db, $_db.projects)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$FloorPlansTable, List<FloorPlanDb>>
      _floorPlansRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.floorPlans,
          aliasName:
              $_aliasNameGenerator(db.buildings.id, db.floorPlans.buildingId));

  $$FloorPlansTableProcessedTableManager get floorPlansRefs {
    final manager = $$FloorPlansTableTableManager($_db, $_db.floorPlans)
        .filter((f) => f.buildingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_floorPlansRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AnlagenTable, List<AnlageDb>> _anlagenRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.anlagen,
          aliasName:
              $_aliasNameGenerator(db.buildings.id, db.anlagen.buildingId));

  $$AnlagenTableProcessedTableManager get anlagenRefs {
    final manager = $$AnlagenTableTableManager($_db, $_db.anlagen)
        .filter((f) => f.buildingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_anlagenRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AttachmentsTableTable, List<AttachmentsTableDb>>
      _attachmentsTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.attachmentsTable,
              aliasName: $_aliasNameGenerator(
                  db.buildings.id, db.attachmentsTable.buildingId));

  $$AttachmentsTableTableProcessedTableManager get attachmentsTableRefs {
    final manager = $$AttachmentsTableTableTableManager(
            $_db, $_db.attachmentsTable)
        .filter((f) => f.buildingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_attachmentsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$DisziplinenTable, List<DisziplinDb>>
      _disziplinenRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.disziplinen,
          aliasName:
              $_aliasNameGenerator(db.buildings.id, db.disziplinen.buildingId));

  $$DisziplinenTableProcessedTableManager get disziplinenRefs {
    final manager = $$DisziplinenTableTableManager($_db, $_db.disziplinen)
        .filter((f) => f.buildingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_disziplinenRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BuildingsTableFilterComposer
    extends Composer<_$AppDatabase, $BuildingsTable> {
  $$BuildingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get postalCode => $composableBuilder(
      column: $table.postalCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get bgf => $composableBuilder(
      column: $table.bgf, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get constructionYear => $composableBuilder(
      column: $table.constructionYear,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get renovationYears => $composableBuilder(
      column: $table.renovationYears,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get protectedMonument => $composableBuilder(
      column: $table.protectedMonument,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get units => $composableBuilder(
      column: $table.units, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get floorArea => $composableBuilder(
      column: $table.floorArea, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableFilterComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> floorPlansRefs(
      Expression<bool> Function($$FloorPlansTableFilterComposer f) f) {
    final $$FloorPlansTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.floorPlans,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FloorPlansTableFilterComposer(
              $db: $db,
              $table: $db.floorPlans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> anlagenRefs(
      Expression<bool> Function($$AnlagenTableFilterComposer f) f) {
    final $$AnlagenTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.anlagen,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AnlagenTableFilterComposer(
              $db: $db,
              $table: $db.anlagen,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> attachmentsTableRefs(
      Expression<bool> Function($$AttachmentsTableTableFilterComposer f) f) {
    final $$AttachmentsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.attachmentsTable,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AttachmentsTableTableFilterComposer(
              $db: $db,
              $table: $db.attachmentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> disziplinenRefs(
      Expression<bool> Function($$DisziplinenTableFilterComposer f) f) {
    final $$DisziplinenTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.disziplinen,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DisziplinenTableFilterComposer(
              $db: $db,
              $table: $db.disziplinen,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BuildingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BuildingsTable> {
  $$BuildingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get postalCode => $composableBuilder(
      column: $table.postalCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get bgf => $composableBuilder(
      column: $table.bgf, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get constructionYear => $composableBuilder(
      column: $table.constructionYear,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get renovationYears => $composableBuilder(
      column: $table.renovationYears,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get protectedMonument => $composableBuilder(
      column: $table.protectedMonument,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get units => $composableBuilder(
      column: $table.units, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get floorArea => $composableBuilder(
      column: $table.floorArea, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableOrderingComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BuildingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BuildingsTable> {
  $$BuildingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get postalCode => $composableBuilder(
      column: $table.postalCode, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get bgf =>
      $composableBuilder(column: $table.bgf, builder: (column) => column);

  GeneratedColumn<int> get constructionYear => $composableBuilder(
      column: $table.constructionYear, builder: (column) => column);

  GeneratedColumn<String> get renovationYears => $composableBuilder(
      column: $table.renovationYears, builder: (column) => column);

  GeneratedColumn<bool> get protectedMonument => $composableBuilder(
      column: $table.protectedMonument, builder: (column) => column);

  GeneratedColumn<int> get units =>
      $composableBuilder(column: $table.units, builder: (column) => column);

  GeneratedColumn<double> get floorArea =>
      $composableBuilder(column: $table.floorArea, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableAnnotationComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> floorPlansRefs<T extends Object>(
      Expression<T> Function($$FloorPlansTableAnnotationComposer a) f) {
    final $$FloorPlansTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.floorPlans,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FloorPlansTableAnnotationComposer(
              $db: $db,
              $table: $db.floorPlans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> anlagenRefs<T extends Object>(
      Expression<T> Function($$AnlagenTableAnnotationComposer a) f) {
    final $$AnlagenTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.anlagen,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AnlagenTableAnnotationComposer(
              $db: $db,
              $table: $db.anlagen,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> attachmentsTableRefs<T extends Object>(
      Expression<T> Function($$AttachmentsTableTableAnnotationComposer a) f) {
    final $$AttachmentsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.attachmentsTable,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AttachmentsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.attachmentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> disziplinenRefs<T extends Object>(
      Expression<T> Function($$DisziplinenTableAnnotationComposer a) f) {
    final $$DisziplinenTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.disziplinen,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DisziplinenTableAnnotationComposer(
              $db: $db,
              $table: $db.disziplinen,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BuildingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BuildingsTable,
    BuildingDb,
    $$BuildingsTableFilterComposer,
    $$BuildingsTableOrderingComposer,
    $$BuildingsTableAnnotationComposer,
    $$BuildingsTableCreateCompanionBuilder,
    $$BuildingsTableUpdateCompanionBuilder,
    (BuildingDb, $$BuildingsTableReferences),
    BuildingDb,
    PrefetchHooks Function(
        {bool projectId,
        bool floorPlansRefs,
        bool anlagenRefs,
        bool attachmentsTableRefs,
        bool disziplinenRefs})> {
  $$BuildingsTableTableManager(_$AppDatabase db, $BuildingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BuildingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BuildingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BuildingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> address = const Value.absent(),
            Value<String> postalCode = const Value.absent(),
            Value<String> city = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> bgf = const Value.absent(),
            Value<int> constructionYear = const Value.absent(),
            Value<String> renovationYears = const Value.absent(),
            Value<bool> protectedMonument = const Value.absent(),
            Value<int> units = const Value.absent(),
            Value<double> floorArea = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BuildingsCompanion(
            id: id,
            projectId: projectId,
            name: name,
            address: address,
            postalCode: postalCode,
            city: city,
            type: type,
            bgf: bgf,
            constructionYear: constructionYear,
            renovationYears: renovationYears,
            protectedMonument: protectedMonument,
            units: units,
            floorArea: floorArea,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String name,
            required String address,
            required String postalCode,
            required String city,
            required String type,
            required double bgf,
            required int constructionYear,
            required String renovationYears,
            required bool protectedMonument,
            required int units,
            required double floorArea,
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BuildingsCompanion.insert(
            id: id,
            projectId: projectId,
            name: name,
            address: address,
            postalCode: postalCode,
            city: city,
            type: type,
            bgf: bgf,
            constructionYear: constructionYear,
            renovationYears: renovationYears,
            protectedMonument: protectedMonument,
            units: units,
            floorArea: floorArea,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BuildingsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {projectId = false,
              floorPlansRefs = false,
              anlagenRefs = false,
              attachmentsTableRefs = false,
              disziplinenRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (floorPlansRefs) db.floorPlans,
                if (anlagenRefs) db.anlagen,
                if (attachmentsTableRefs) db.attachmentsTable,
                if (disziplinenRefs) db.disziplinen
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$BuildingsTableReferences._projectIdTable(db),
                    referencedColumn:
                        $$BuildingsTableReferences._projectIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (floorPlansRefs)
                    await $_getPrefetchedData<BuildingDb, $BuildingsTable,
                            FloorPlanDb>(
                        currentTable: table,
                        referencedTable:
                            $$BuildingsTableReferences._floorPlansRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BuildingsTableReferences(db, table, p0)
                                .floorPlansRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.buildingId == item.id),
                        typedResults: items),
                  if (anlagenRefs)
                    await $_getPrefetchedData<BuildingDb, $BuildingsTable,
                            AnlageDb>(
                        currentTable: table,
                        referencedTable:
                            $$BuildingsTableReferences._anlagenRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BuildingsTableReferences(db, table, p0)
                                .anlagenRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.buildingId == item.id),
                        typedResults: items),
                  if (attachmentsTableRefs)
                    await $_getPrefetchedData<BuildingDb, $BuildingsTable,
                            AttachmentsTableDb>(
                        currentTable: table,
                        referencedTable: $$BuildingsTableReferences
                            ._attachmentsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BuildingsTableReferences(db, table, p0)
                                .attachmentsTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.buildingId == item.id),
                        typedResults: items),
                  if (disziplinenRefs)
                    await $_getPrefetchedData<BuildingDb, $BuildingsTable,
                            DisziplinDb>(
                        currentTable: table,
                        referencedTable: $$BuildingsTableReferences
                            ._disziplinenRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BuildingsTableReferences(db, table, p0)
                                .disziplinenRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.buildingId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BuildingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BuildingsTable,
    BuildingDb,
    $$BuildingsTableFilterComposer,
    $$BuildingsTableOrderingComposer,
    $$BuildingsTableAnnotationComposer,
    $$BuildingsTableCreateCompanionBuilder,
    $$BuildingsTableUpdateCompanionBuilder,
    (BuildingDb, $$BuildingsTableReferences),
    BuildingDb,
    PrefetchHooks Function(
        {bool projectId,
        bool floorPlansRefs,
        bool anlagenRefs,
        bool attachmentsTableRefs,
        bool disziplinenRefs})>;
typedef $$FloorPlansTableCreateCompanionBuilder = FloorPlansCompanion Function({
  required String id,
  required String buildingId,
  required String name,
  Value<String?> pdfPath,
  Value<String?> pdfName,
  Value<int> rowid,
});
typedef $$FloorPlansTableUpdateCompanionBuilder = FloorPlansCompanion Function({
  Value<String> id,
  Value<String> buildingId,
  Value<String> name,
  Value<String?> pdfPath,
  Value<String?> pdfName,
  Value<int> rowid,
});

final class $$FloorPlansTableReferences
    extends BaseReferences<_$AppDatabase, $FloorPlansTable, FloorPlanDb> {
  $$FloorPlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BuildingsTable _buildingIdTable(_$AppDatabase db) =>
      db.buildings.createAlias(
          $_aliasNameGenerator(db.floorPlans.buildingId, db.buildings.id));

  $$BuildingsTableProcessedTableManager get buildingId {
    final $_column = $_itemColumn<String>('building_id')!;

    final manager = $$BuildingsTableTableManager($_db, $_db.buildings)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_buildingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$FloorPlansTableFilterComposer
    extends Composer<_$AppDatabase, $FloorPlansTable> {
  $$FloorPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pdfPath => $composableBuilder(
      column: $table.pdfPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pdfName => $composableBuilder(
      column: $table.pdfName, builder: (column) => ColumnFilters(column));

  $$BuildingsTableFilterComposer get buildingId {
    final $$BuildingsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableFilterComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FloorPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $FloorPlansTable> {
  $$FloorPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pdfPath => $composableBuilder(
      column: $table.pdfPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pdfName => $composableBuilder(
      column: $table.pdfName, builder: (column) => ColumnOrderings(column));

  $$BuildingsTableOrderingComposer get buildingId {
    final $$BuildingsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableOrderingComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FloorPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $FloorPlansTable> {
  $$FloorPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get pdfPath =>
      $composableBuilder(column: $table.pdfPath, builder: (column) => column);

  GeneratedColumn<String> get pdfName =>
      $composableBuilder(column: $table.pdfName, builder: (column) => column);

  $$BuildingsTableAnnotationComposer get buildingId {
    final $$BuildingsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableAnnotationComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FloorPlansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FloorPlansTable,
    FloorPlanDb,
    $$FloorPlansTableFilterComposer,
    $$FloorPlansTableOrderingComposer,
    $$FloorPlansTableAnnotationComposer,
    $$FloorPlansTableCreateCompanionBuilder,
    $$FloorPlansTableUpdateCompanionBuilder,
    (FloorPlanDb, $$FloorPlansTableReferences),
    FloorPlanDb,
    PrefetchHooks Function({bool buildingId})> {
  $$FloorPlansTableTableManager(_$AppDatabase db, $FloorPlansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FloorPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FloorPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FloorPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> buildingId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> pdfPath = const Value.absent(),
            Value<String?> pdfName = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FloorPlansCompanion(
            id: id,
            buildingId: buildingId,
            name: name,
            pdfPath: pdfPath,
            pdfName: pdfName,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String buildingId,
            required String name,
            Value<String?> pdfPath = const Value.absent(),
            Value<String?> pdfName = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FloorPlansCompanion.insert(
            id: id,
            buildingId: buildingId,
            name: name,
            pdfPath: pdfPath,
            pdfName: pdfName,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$FloorPlansTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({buildingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (buildingId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.buildingId,
                    referencedTable:
                        $$FloorPlansTableReferences._buildingIdTable(db),
                    referencedColumn:
                        $$FloorPlansTableReferences._buildingIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$FloorPlansTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FloorPlansTable,
    FloorPlanDb,
    $$FloorPlansTableFilterComposer,
    $$FloorPlansTableOrderingComposer,
    $$FloorPlansTableAnnotationComposer,
    $$FloorPlansTableCreateCompanionBuilder,
    $$FloorPlansTableUpdateCompanionBuilder,
    (FloorPlanDb, $$FloorPlansTableReferences),
    FloorPlanDb,
    PrefetchHooks Function({bool buildingId})>;
typedef $$AnlagenTableCreateCompanionBuilder = AnlagenCompanion Function({
  required String id,
  Value<String?> parentId,
  required String name,
  required String params,
  Value<String?> floorId,
  required String buildingId,
  required bool isMarker,
  Value<String?> markerInfo,
  required String markerType,
  required String discipline,
  Value<bool> isDeleted,
  Value<int> rowid,
});
typedef $$AnlagenTableUpdateCompanionBuilder = AnlagenCompanion Function({
  Value<String> id,
  Value<String?> parentId,
  Value<String> name,
  Value<String> params,
  Value<String?> floorId,
  Value<String> buildingId,
  Value<bool> isMarker,
  Value<String?> markerInfo,
  Value<String> markerType,
  Value<String> discipline,
  Value<bool> isDeleted,
  Value<int> rowid,
});

final class $$AnlagenTableReferences
    extends BaseReferences<_$AppDatabase, $AnlagenTable, AnlageDb> {
  $$AnlagenTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BuildingsTable _buildingIdTable(_$AppDatabase db) =>
      db.buildings.createAlias(
          $_aliasNameGenerator(db.anlagen.buildingId, db.buildings.id));

  $$BuildingsTableProcessedTableManager get buildingId {
    final $_column = $_itemColumn<String>('building_id')!;

    final manager = $$BuildingsTableTableManager($_db, $_db.buildings)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_buildingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AnlagenTableFilterComposer
    extends Composer<_$AppDatabase, $AnlagenTable> {
  $$AnlagenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get params => $composableBuilder(
      column: $table.params, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get floorId => $composableBuilder(
      column: $table.floorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMarker => $composableBuilder(
      column: $table.isMarker, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get markerInfo => $composableBuilder(
      column: $table.markerInfo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get markerType => $composableBuilder(
      column: $table.markerType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get discipline => $composableBuilder(
      column: $table.discipline, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  $$BuildingsTableFilterComposer get buildingId {
    final $$BuildingsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableFilterComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AnlagenTableOrderingComposer
    extends Composer<_$AppDatabase, $AnlagenTable> {
  $$AnlagenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get params => $composableBuilder(
      column: $table.params, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get floorId => $composableBuilder(
      column: $table.floorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMarker => $composableBuilder(
      column: $table.isMarker, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get markerInfo => $composableBuilder(
      column: $table.markerInfo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get markerType => $composableBuilder(
      column: $table.markerType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get discipline => $composableBuilder(
      column: $table.discipline, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  $$BuildingsTableOrderingComposer get buildingId {
    final $$BuildingsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableOrderingComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AnlagenTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnlagenTable> {
  $$AnlagenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get params =>
      $composableBuilder(column: $table.params, builder: (column) => column);

  GeneratedColumn<String> get floorId =>
      $composableBuilder(column: $table.floorId, builder: (column) => column);

  GeneratedColumn<bool> get isMarker =>
      $composableBuilder(column: $table.isMarker, builder: (column) => column);

  GeneratedColumn<String> get markerInfo => $composableBuilder(
      column: $table.markerInfo, builder: (column) => column);

  GeneratedColumn<String> get markerType => $composableBuilder(
      column: $table.markerType, builder: (column) => column);

  GeneratedColumn<String> get discipline => $composableBuilder(
      column: $table.discipline, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$BuildingsTableAnnotationComposer get buildingId {
    final $$BuildingsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableAnnotationComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AnlagenTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnlagenTable,
    AnlageDb,
    $$AnlagenTableFilterComposer,
    $$AnlagenTableOrderingComposer,
    $$AnlagenTableAnnotationComposer,
    $$AnlagenTableCreateCompanionBuilder,
    $$AnlagenTableUpdateCompanionBuilder,
    (AnlageDb, $$AnlagenTableReferences),
    AnlageDb,
    PrefetchHooks Function({bool buildingId})> {
  $$AnlagenTableTableManager(_$AppDatabase db, $AnlagenTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnlagenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnlagenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnlagenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> params = const Value.absent(),
            Value<String?> floorId = const Value.absent(),
            Value<String> buildingId = const Value.absent(),
            Value<bool> isMarker = const Value.absent(),
            Value<String?> markerInfo = const Value.absent(),
            Value<String> markerType = const Value.absent(),
            Value<String> discipline = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnlagenCompanion(
            id: id,
            parentId: parentId,
            name: name,
            params: params,
            floorId: floorId,
            buildingId: buildingId,
            isMarker: isMarker,
            markerInfo: markerInfo,
            markerType: markerType,
            discipline: discipline,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> parentId = const Value.absent(),
            required String name,
            required String params,
            Value<String?> floorId = const Value.absent(),
            required String buildingId,
            required bool isMarker,
            Value<String?> markerInfo = const Value.absent(),
            required String markerType,
            required String discipline,
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnlagenCompanion.insert(
            id: id,
            parentId: parentId,
            name: name,
            params: params,
            floorId: floorId,
            buildingId: buildingId,
            isMarker: isMarker,
            markerInfo: markerInfo,
            markerType: markerType,
            discipline: discipline,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$AnlagenTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({buildingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (buildingId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.buildingId,
                    referencedTable:
                        $$AnlagenTableReferences._buildingIdTable(db),
                    referencedColumn:
                        $$AnlagenTableReferences._buildingIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AnlagenTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnlagenTable,
    AnlageDb,
    $$AnlagenTableFilterComposer,
    $$AnlagenTableOrderingComposer,
    $$AnlagenTableAnnotationComposer,
    $$AnlagenTableCreateCompanionBuilder,
    $$AnlagenTableUpdateCompanionBuilder,
    (AnlageDb, $$AnlagenTableReferences),
    AnlageDb,
    PrefetchHooks Function({bool buildingId})>;
typedef $$AttachmentsTableTableCreateCompanionBuilder
    = AttachmentsTableCompanion Function({
  required String id,
  required String buildingId,
  required String photos,
  required String plans,
  required String notes,
  Value<int> rowid,
});
typedef $$AttachmentsTableTableUpdateCompanionBuilder
    = AttachmentsTableCompanion Function({
  Value<String> id,
  Value<String> buildingId,
  Value<String> photos,
  Value<String> plans,
  Value<String> notes,
  Value<int> rowid,
});

final class $$AttachmentsTableTableReferences extends BaseReferences<
    _$AppDatabase, $AttachmentsTableTable, AttachmentsTableDb> {
  $$AttachmentsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BuildingsTable _buildingIdTable(_$AppDatabase db) =>
      db.buildings.createAlias($_aliasNameGenerator(
          db.attachmentsTable.buildingId, db.buildings.id));

  $$BuildingsTableProcessedTableManager get buildingId {
    final $_column = $_itemColumn<String>('building_id')!;

    final manager = $$BuildingsTableTableManager($_db, $_db.buildings)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_buildingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AttachmentsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTableTable> {
  $$AttachmentsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photos => $composableBuilder(
      column: $table.photos, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plans => $composableBuilder(
      column: $table.plans, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  $$BuildingsTableFilterComposer get buildingId {
    final $$BuildingsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableFilterComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AttachmentsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTableTable> {
  $$AttachmentsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photos => $composableBuilder(
      column: $table.photos, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plans => $composableBuilder(
      column: $table.plans, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  $$BuildingsTableOrderingComposer get buildingId {
    final $$BuildingsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableOrderingComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AttachmentsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTableTable> {
  $$AttachmentsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get photos =>
      $composableBuilder(column: $table.photos, builder: (column) => column);

  GeneratedColumn<String> get plans =>
      $composableBuilder(column: $table.plans, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$BuildingsTableAnnotationComposer get buildingId {
    final $$BuildingsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableAnnotationComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AttachmentsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AttachmentsTableTable,
    AttachmentsTableDb,
    $$AttachmentsTableTableFilterComposer,
    $$AttachmentsTableTableOrderingComposer,
    $$AttachmentsTableTableAnnotationComposer,
    $$AttachmentsTableTableCreateCompanionBuilder,
    $$AttachmentsTableTableUpdateCompanionBuilder,
    (AttachmentsTableDb, $$AttachmentsTableTableReferences),
    AttachmentsTableDb,
    PrefetchHooks Function({bool buildingId})> {
  $$AttachmentsTableTableTableManager(
      _$AppDatabase db, $AttachmentsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> buildingId = const Value.absent(),
            Value<String> photos = const Value.absent(),
            Value<String> plans = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AttachmentsTableCompanion(
            id: id,
            buildingId: buildingId,
            photos: photos,
            plans: plans,
            notes: notes,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String buildingId,
            required String photos,
            required String plans,
            required String notes,
            Value<int> rowid = const Value.absent(),
          }) =>
              AttachmentsTableCompanion.insert(
            id: id,
            buildingId: buildingId,
            photos: photos,
            plans: plans,
            notes: notes,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AttachmentsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({buildingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (buildingId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.buildingId,
                    referencedTable:
                        $$AttachmentsTableTableReferences._buildingIdTable(db),
                    referencedColumn: $$AttachmentsTableTableReferences
                        ._buildingIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AttachmentsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AttachmentsTableTable,
    AttachmentsTableDb,
    $$AttachmentsTableTableFilterComposer,
    $$AttachmentsTableTableOrderingComposer,
    $$AttachmentsTableTableAnnotationComposer,
    $$AttachmentsTableTableCreateCompanionBuilder,
    $$AttachmentsTableTableUpdateCompanionBuilder,
    (AttachmentsTableDb, $$AttachmentsTableTableReferences),
    AttachmentsTableDb,
    PrefetchHooks Function({bool buildingId})>;
typedef $$DisziplinenTableCreateCompanionBuilder = DisziplinenCompanion
    Function({
  required String buildingId,
  required String label,
  required String data,
  Value<int> rowid,
});
typedef $$DisziplinenTableUpdateCompanionBuilder = DisziplinenCompanion
    Function({
  Value<String> buildingId,
  Value<String> label,
  Value<String> data,
  Value<int> rowid,
});

final class $$DisziplinenTableReferences
    extends BaseReferences<_$AppDatabase, $DisziplinenTable, DisziplinDb> {
  $$DisziplinenTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BuildingsTable _buildingIdTable(_$AppDatabase db) =>
      db.buildings.createAlias(
          $_aliasNameGenerator(db.disziplinen.buildingId, db.buildings.id));

  $$BuildingsTableProcessedTableManager get buildingId {
    final $_column = $_itemColumn<String>('building_id')!;

    final manager = $$BuildingsTableTableManager($_db, $_db.buildings)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_buildingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DisziplinenTableFilterComposer
    extends Composer<_$AppDatabase, $DisziplinenTable> {
  $$DisziplinenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));

  $$BuildingsTableFilterComposer get buildingId {
    final $$BuildingsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableFilterComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DisziplinenTableOrderingComposer
    extends Composer<_$AppDatabase, $DisziplinenTable> {
  $$DisziplinenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));

  $$BuildingsTableOrderingComposer get buildingId {
    final $$BuildingsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableOrderingComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DisziplinenTableAnnotationComposer
    extends Composer<_$AppDatabase, $DisziplinenTable> {
  $$DisziplinenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  $$BuildingsTableAnnotationComposer get buildingId {
    final $$BuildingsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.buildingId,
        referencedTable: $db.buildings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BuildingsTableAnnotationComposer(
              $db: $db,
              $table: $db.buildings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DisziplinenTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DisziplinenTable,
    DisziplinDb,
    $$DisziplinenTableFilterComposer,
    $$DisziplinenTableOrderingComposer,
    $$DisziplinenTableAnnotationComposer,
    $$DisziplinenTableCreateCompanionBuilder,
    $$DisziplinenTableUpdateCompanionBuilder,
    (DisziplinDb, $$DisziplinenTableReferences),
    DisziplinDb,
    PrefetchHooks Function({bool buildingId})> {
  $$DisziplinenTableTableManager(_$AppDatabase db, $DisziplinenTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DisziplinenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DisziplinenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DisziplinenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> buildingId = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DisziplinenCompanion(
            buildingId: buildingId,
            label: label,
            data: data,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String buildingId,
            required String label,
            required String data,
            Value<int> rowid = const Value.absent(),
          }) =>
              DisziplinenCompanion.insert(
            buildingId: buildingId,
            label: label,
            data: data,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DisziplinenTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({buildingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (buildingId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.buildingId,
                    referencedTable:
                        $$DisziplinenTableReferences._buildingIdTable(db),
                    referencedColumn:
                        $$DisziplinenTableReferences._buildingIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DisziplinenTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DisziplinenTable,
    DisziplinDb,
    $$DisziplinenTableFilterComposer,
    $$DisziplinenTableOrderingComposer,
    $$DisziplinenTableAnnotationComposer,
    $$DisziplinenTableCreateCompanionBuilder,
    $$DisziplinenTableUpdateCompanionBuilder,
    (DisziplinDb, $$DisziplinenTableReferences),
    DisziplinDb,
    PrefetchHooks Function({bool buildingId})>;
typedef $$TemplatesTableCreateCompanionBuilder = TemplatesCompanion Function({
  Value<int> id,
  required String projectId,
  required String gewerk,
  required String anlageBauteil,
  required String anlagentyp,
  required String bezeichnung,
  Value<String?> parameter,
});
typedef $$TemplatesTableUpdateCompanionBuilder = TemplatesCompanion Function({
  Value<int> id,
  Value<String> projectId,
  Value<String> gewerk,
  Value<String> anlageBauteil,
  Value<String> anlagentyp,
  Value<String> bezeichnung,
  Value<String?> parameter,
});

final class $$TemplatesTableReferences
    extends BaseReferences<_$AppDatabase, $TemplatesTable, TemplateDb> {
  $$TemplatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
          $_aliasNameGenerator(db.templates.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager($_db, $_db.projects)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gewerk => $composableBuilder(
      column: $table.gewerk, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get anlageBauteil => $composableBuilder(
      column: $table.anlageBauteil, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get anlagentyp => $composableBuilder(
      column: $table.anlagentyp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bezeichnung => $composableBuilder(
      column: $table.bezeichnung, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parameter => $composableBuilder(
      column: $table.parameter, builder: (column) => ColumnFilters(column));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableFilterComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gewerk => $composableBuilder(
      column: $table.gewerk, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get anlageBauteil => $composableBuilder(
      column: $table.anlageBauteil,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get anlagentyp => $composableBuilder(
      column: $table.anlagentyp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bezeichnung => $composableBuilder(
      column: $table.bezeichnung, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parameter => $composableBuilder(
      column: $table.parameter, builder: (column) => ColumnOrderings(column));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableOrderingComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get gewerk =>
      $composableBuilder(column: $table.gewerk, builder: (column) => column);

  GeneratedColumn<String> get anlageBauteil => $composableBuilder(
      column: $table.anlageBauteil, builder: (column) => column);

  GeneratedColumn<String> get anlagentyp => $composableBuilder(
      column: $table.anlagentyp, builder: (column) => column);

  GeneratedColumn<String> get bezeichnung => $composableBuilder(
      column: $table.bezeichnung, builder: (column) => column);

  GeneratedColumn<String> get parameter =>
      $composableBuilder(column: $table.parameter, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableAnnotationComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TemplatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TemplatesTable,
    TemplateDb,
    $$TemplatesTableFilterComposer,
    $$TemplatesTableOrderingComposer,
    $$TemplatesTableAnnotationComposer,
    $$TemplatesTableCreateCompanionBuilder,
    $$TemplatesTableUpdateCompanionBuilder,
    (TemplateDb, $$TemplatesTableReferences),
    TemplateDb,
    PrefetchHooks Function({bool projectId})> {
  $$TemplatesTableTableManager(_$AppDatabase db, $TemplatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> gewerk = const Value.absent(),
            Value<String> anlageBauteil = const Value.absent(),
            Value<String> anlagentyp = const Value.absent(),
            Value<String> bezeichnung = const Value.absent(),
            Value<String?> parameter = const Value.absent(),
          }) =>
              TemplatesCompanion(
            id: id,
            projectId: projectId,
            gewerk: gewerk,
            anlageBauteil: anlageBauteil,
            anlagentyp: anlagentyp,
            bezeichnung: bezeichnung,
            parameter: parameter,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String projectId,
            required String gewerk,
            required String anlageBauteil,
            required String anlagentyp,
            required String bezeichnung,
            Value<String?> parameter = const Value.absent(),
          }) =>
              TemplatesCompanion.insert(
            id: id,
            projectId: projectId,
            gewerk: gewerk,
            anlageBauteil: anlageBauteil,
            anlagentyp: anlagentyp,
            bezeichnung: bezeichnung,
            parameter: parameter,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TemplatesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$TemplatesTableReferences._projectIdTable(db),
                    referencedColumn:
                        $$TemplatesTableReferences._projectIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TemplatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TemplatesTable,
    TemplateDb,
    $$TemplatesTableFilterComposer,
    $$TemplatesTableOrderingComposer,
    $$TemplatesTableAnnotationComposer,
    $$TemplatesTableCreateCompanionBuilder,
    $$TemplatesTableUpdateCompanionBuilder,
    (TemplateDb, $$TemplatesTableReferences),
    TemplateDb,
    PrefetchHooks Function({bool projectId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$BuildingsTableTableManager get buildings =>
      $$BuildingsTableTableManager(_db, _db.buildings);
  $$FloorPlansTableTableManager get floorPlans =>
      $$FloorPlansTableTableManager(_db, _db.floorPlans);
  $$AnlagenTableTableManager get anlagen =>
      $$AnlagenTableTableManager(_db, _db.anlagen);
  $$AttachmentsTableTableTableManager get attachmentsTable =>
      $$AttachmentsTableTableTableManager(_db, _db.attachmentsTable);
  $$DisziplinenTableTableManager get disziplinen =>
      $$DisziplinenTableTableManager(_db, _db.disziplinen);
  $$TemplatesTableTableManager get templates =>
      $$TemplatesTableTableManager(_db, _db.templates);
}
