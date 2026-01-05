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
  @override
  List<GeneratedColumn> get $columns => [id, name, description, customer];
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
  const ProjectDb(
      {required this.id,
      required this.name,
      required this.description,
      required this.customer});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['customer'] = Variable<String>(customer);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      customer: Value(customer),
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
    };
  }

  ProjectDb copyWith(
          {String? id, String? name, String? description, String? customer}) =>
      ProjectDb(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        customer: customer ?? this.customer,
      );
  ProjectDb copyWithCompanion(ProjectsCompanion data) {
    return ProjectDb(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      customer: data.customer.present ? data.customer.value : this.customer,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectDb(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('customer: $customer')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, customer);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectDb &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.customer == this.customer);
}

class ProjectsCompanion extends UpdateCompanion<ProjectDb> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String> customer;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.customer = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    required String description,
    required String customer,
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (customer != null) 'customer': customer,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? description,
      Value<String>? customer,
      Value<int>? rowid}) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      customer: customer ?? this.customer,
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
        floorArea
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
      required this.floorArea});
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
          double? floorArea}) =>
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
          ..write('floorArea: $floorArea')
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
      floorArea);
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
          other.floorArea == this.floorArea);
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
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EnvelopesTable extends Envelopes
    with TableInfo<$EnvelopesTable, EnvelopeDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EnvelopesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _roofTypeMeta =
      const VerificationMeta('roofType');
  @override
  late final GeneratedColumn<String> roofType = GeneratedColumn<String>(
      'roof_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roofUValueMeta =
      const VerificationMeta('roofUValue');
  @override
  late final GeneratedColumn<double> roofUValue = GeneratedColumn<double>(
      'roof_u_value', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _roofAreaMeta =
      const VerificationMeta('roofArea');
  @override
  late final GeneratedColumn<double> roofArea = GeneratedColumn<double>(
      'roof_area', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _roofInsulationMeta =
      const VerificationMeta('roofInsulation');
  @override
  late final GeneratedColumn<bool> roofInsulation = GeneratedColumn<bool>(
      'roof_insulation', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("roof_insulation" IN (0, 1))'));
  static const VerificationMeta _floorTypeMeta =
      const VerificationMeta('floorType');
  @override
  late final GeneratedColumn<String> floorType = GeneratedColumn<String>(
      'floor_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _floorUValueMeta =
      const VerificationMeta('floorUValue');
  @override
  late final GeneratedColumn<double> floorUValue = GeneratedColumn<double>(
      'floor_u_value', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _floorAreaMeta =
      const VerificationMeta('floorArea');
  @override
  late final GeneratedColumn<double> floorArea = GeneratedColumn<double>(
      'floor_area', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _floorInsulatedMeta =
      const VerificationMeta('floorInsulated');
  @override
  late final GeneratedColumn<bool> floorInsulated = GeneratedColumn<bool>(
      'floor_insulated', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("floor_insulated" IN (0, 1))'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        buildingId,
        roofType,
        roofUValue,
        roofArea,
        roofInsulation,
        floorType,
        floorUValue,
        floorArea,
        floorInsulated
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'envelopes';
  @override
  VerificationContext validateIntegrity(Insertable<EnvelopeDb> instance,
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
    if (data.containsKey('roof_type')) {
      context.handle(_roofTypeMeta,
          roofType.isAcceptableOrUnknown(data['roof_type']!, _roofTypeMeta));
    } else if (isInserting) {
      context.missing(_roofTypeMeta);
    }
    if (data.containsKey('roof_u_value')) {
      context.handle(
          _roofUValueMeta,
          roofUValue.isAcceptableOrUnknown(
              data['roof_u_value']!, _roofUValueMeta));
    } else if (isInserting) {
      context.missing(_roofUValueMeta);
    }
    if (data.containsKey('roof_area')) {
      context.handle(_roofAreaMeta,
          roofArea.isAcceptableOrUnknown(data['roof_area']!, _roofAreaMeta));
    } else if (isInserting) {
      context.missing(_roofAreaMeta);
    }
    if (data.containsKey('roof_insulation')) {
      context.handle(
          _roofInsulationMeta,
          roofInsulation.isAcceptableOrUnknown(
              data['roof_insulation']!, _roofInsulationMeta));
    } else if (isInserting) {
      context.missing(_roofInsulationMeta);
    }
    if (data.containsKey('floor_type')) {
      context.handle(_floorTypeMeta,
          floorType.isAcceptableOrUnknown(data['floor_type']!, _floorTypeMeta));
    } else if (isInserting) {
      context.missing(_floorTypeMeta);
    }
    if (data.containsKey('floor_u_value')) {
      context.handle(
          _floorUValueMeta,
          floorUValue.isAcceptableOrUnknown(
              data['floor_u_value']!, _floorUValueMeta));
    } else if (isInserting) {
      context.missing(_floorUValueMeta);
    }
    if (data.containsKey('floor_area')) {
      context.handle(_floorAreaMeta,
          floorArea.isAcceptableOrUnknown(data['floor_area']!, _floorAreaMeta));
    } else if (isInserting) {
      context.missing(_floorAreaMeta);
    }
    if (data.containsKey('floor_insulated')) {
      context.handle(
          _floorInsulatedMeta,
          floorInsulated.isAcceptableOrUnknown(
              data['floor_insulated']!, _floorInsulatedMeta));
    } else if (isInserting) {
      context.missing(_floorInsulatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EnvelopeDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EnvelopeDb(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      buildingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}building_id'])!,
      roofType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}roof_type'])!,
      roofUValue: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}roof_u_value'])!,
      roofArea: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}roof_area'])!,
      roofInsulation: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}roof_insulation'])!,
      floorType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}floor_type'])!,
      floorUValue: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}floor_u_value'])!,
      floorArea: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}floor_area'])!,
      floorInsulated: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}floor_insulated'])!,
    );
  }

  @override
  $EnvelopesTable createAlias(String alias) {
    return $EnvelopesTable(attachedDatabase, alias);
  }
}

class EnvelopeDb extends DataClass implements Insertable<EnvelopeDb> {
  final String id;
  final String buildingId;
  final String roofType;
  final double roofUValue;
  final double roofArea;
  final bool roofInsulation;
  final String floorType;
  final double floorUValue;
  final double floorArea;
  final bool floorInsulated;
  const EnvelopeDb(
      {required this.id,
      required this.buildingId,
      required this.roofType,
      required this.roofUValue,
      required this.roofArea,
      required this.roofInsulation,
      required this.floorType,
      required this.floorUValue,
      required this.floorArea,
      required this.floorInsulated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['building_id'] = Variable<String>(buildingId);
    map['roof_type'] = Variable<String>(roofType);
    map['roof_u_value'] = Variable<double>(roofUValue);
    map['roof_area'] = Variable<double>(roofArea);
    map['roof_insulation'] = Variable<bool>(roofInsulation);
    map['floor_type'] = Variable<String>(floorType);
    map['floor_u_value'] = Variable<double>(floorUValue);
    map['floor_area'] = Variable<double>(floorArea);
    map['floor_insulated'] = Variable<bool>(floorInsulated);
    return map;
  }

  EnvelopesCompanion toCompanion(bool nullToAbsent) {
    return EnvelopesCompanion(
      id: Value(id),
      buildingId: Value(buildingId),
      roofType: Value(roofType),
      roofUValue: Value(roofUValue),
      roofArea: Value(roofArea),
      roofInsulation: Value(roofInsulation),
      floorType: Value(floorType),
      floorUValue: Value(floorUValue),
      floorArea: Value(floorArea),
      floorInsulated: Value(floorInsulated),
    );
  }

  factory EnvelopeDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EnvelopeDb(
      id: serializer.fromJson<String>(json['id']),
      buildingId: serializer.fromJson<String>(json['buildingId']),
      roofType: serializer.fromJson<String>(json['roofType']),
      roofUValue: serializer.fromJson<double>(json['roofUValue']),
      roofArea: serializer.fromJson<double>(json['roofArea']),
      roofInsulation: serializer.fromJson<bool>(json['roofInsulation']),
      floorType: serializer.fromJson<String>(json['floorType']),
      floorUValue: serializer.fromJson<double>(json['floorUValue']),
      floorArea: serializer.fromJson<double>(json['floorArea']),
      floorInsulated: serializer.fromJson<bool>(json['floorInsulated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'buildingId': serializer.toJson<String>(buildingId),
      'roofType': serializer.toJson<String>(roofType),
      'roofUValue': serializer.toJson<double>(roofUValue),
      'roofArea': serializer.toJson<double>(roofArea),
      'roofInsulation': serializer.toJson<bool>(roofInsulation),
      'floorType': serializer.toJson<String>(floorType),
      'floorUValue': serializer.toJson<double>(floorUValue),
      'floorArea': serializer.toJson<double>(floorArea),
      'floorInsulated': serializer.toJson<bool>(floorInsulated),
    };
  }

  EnvelopeDb copyWith(
          {String? id,
          String? buildingId,
          String? roofType,
          double? roofUValue,
          double? roofArea,
          bool? roofInsulation,
          String? floorType,
          double? floorUValue,
          double? floorArea,
          bool? floorInsulated}) =>
      EnvelopeDb(
        id: id ?? this.id,
        buildingId: buildingId ?? this.buildingId,
        roofType: roofType ?? this.roofType,
        roofUValue: roofUValue ?? this.roofUValue,
        roofArea: roofArea ?? this.roofArea,
        roofInsulation: roofInsulation ?? this.roofInsulation,
        floorType: floorType ?? this.floorType,
        floorUValue: floorUValue ?? this.floorUValue,
        floorArea: floorArea ?? this.floorArea,
        floorInsulated: floorInsulated ?? this.floorInsulated,
      );
  EnvelopeDb copyWithCompanion(EnvelopesCompanion data) {
    return EnvelopeDb(
      id: data.id.present ? data.id.value : this.id,
      buildingId:
          data.buildingId.present ? data.buildingId.value : this.buildingId,
      roofType: data.roofType.present ? data.roofType.value : this.roofType,
      roofUValue:
          data.roofUValue.present ? data.roofUValue.value : this.roofUValue,
      roofArea: data.roofArea.present ? data.roofArea.value : this.roofArea,
      roofInsulation: data.roofInsulation.present
          ? data.roofInsulation.value
          : this.roofInsulation,
      floorType: data.floorType.present ? data.floorType.value : this.floorType,
      floorUValue:
          data.floorUValue.present ? data.floorUValue.value : this.floorUValue,
      floorArea: data.floorArea.present ? data.floorArea.value : this.floorArea,
      floorInsulated: data.floorInsulated.present
          ? data.floorInsulated.value
          : this.floorInsulated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EnvelopeDb(')
          ..write('id: $id, ')
          ..write('buildingId: $buildingId, ')
          ..write('roofType: $roofType, ')
          ..write('roofUValue: $roofUValue, ')
          ..write('roofArea: $roofArea, ')
          ..write('roofInsulation: $roofInsulation, ')
          ..write('floorType: $floorType, ')
          ..write('floorUValue: $floorUValue, ')
          ..write('floorArea: $floorArea, ')
          ..write('floorInsulated: $floorInsulated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      buildingId,
      roofType,
      roofUValue,
      roofArea,
      roofInsulation,
      floorType,
      floorUValue,
      floorArea,
      floorInsulated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EnvelopeDb &&
          other.id == this.id &&
          other.buildingId == this.buildingId &&
          other.roofType == this.roofType &&
          other.roofUValue == this.roofUValue &&
          other.roofArea == this.roofArea &&
          other.roofInsulation == this.roofInsulation &&
          other.floorType == this.floorType &&
          other.floorUValue == this.floorUValue &&
          other.floorArea == this.floorArea &&
          other.floorInsulated == this.floorInsulated);
}

class EnvelopesCompanion extends UpdateCompanion<EnvelopeDb> {
  final Value<String> id;
  final Value<String> buildingId;
  final Value<String> roofType;
  final Value<double> roofUValue;
  final Value<double> roofArea;
  final Value<bool> roofInsulation;
  final Value<String> floorType;
  final Value<double> floorUValue;
  final Value<double> floorArea;
  final Value<bool> floorInsulated;
  final Value<int> rowid;
  const EnvelopesCompanion({
    this.id = const Value.absent(),
    this.buildingId = const Value.absent(),
    this.roofType = const Value.absent(),
    this.roofUValue = const Value.absent(),
    this.roofArea = const Value.absent(),
    this.roofInsulation = const Value.absent(),
    this.floorType = const Value.absent(),
    this.floorUValue = const Value.absent(),
    this.floorArea = const Value.absent(),
    this.floorInsulated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EnvelopesCompanion.insert({
    required String id,
    required String buildingId,
    required String roofType,
    required double roofUValue,
    required double roofArea,
    required bool roofInsulation,
    required String floorType,
    required double floorUValue,
    required double floorArea,
    required bool floorInsulated,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        buildingId = Value(buildingId),
        roofType = Value(roofType),
        roofUValue = Value(roofUValue),
        roofArea = Value(roofArea),
        roofInsulation = Value(roofInsulation),
        floorType = Value(floorType),
        floorUValue = Value(floorUValue),
        floorArea = Value(floorArea),
        floorInsulated = Value(floorInsulated);
  static Insertable<EnvelopeDb> custom({
    Expression<String>? id,
    Expression<String>? buildingId,
    Expression<String>? roofType,
    Expression<double>? roofUValue,
    Expression<double>? roofArea,
    Expression<bool>? roofInsulation,
    Expression<String>? floorType,
    Expression<double>? floorUValue,
    Expression<double>? floorArea,
    Expression<bool>? floorInsulated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (buildingId != null) 'building_id': buildingId,
      if (roofType != null) 'roof_type': roofType,
      if (roofUValue != null) 'roof_u_value': roofUValue,
      if (roofArea != null) 'roof_area': roofArea,
      if (roofInsulation != null) 'roof_insulation': roofInsulation,
      if (floorType != null) 'floor_type': floorType,
      if (floorUValue != null) 'floor_u_value': floorUValue,
      if (floorArea != null) 'floor_area': floorArea,
      if (floorInsulated != null) 'floor_insulated': floorInsulated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EnvelopesCompanion copyWith(
      {Value<String>? id,
      Value<String>? buildingId,
      Value<String>? roofType,
      Value<double>? roofUValue,
      Value<double>? roofArea,
      Value<bool>? roofInsulation,
      Value<String>? floorType,
      Value<double>? floorUValue,
      Value<double>? floorArea,
      Value<bool>? floorInsulated,
      Value<int>? rowid}) {
    return EnvelopesCompanion(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      roofType: roofType ?? this.roofType,
      roofUValue: roofUValue ?? this.roofUValue,
      roofArea: roofArea ?? this.roofArea,
      roofInsulation: roofInsulation ?? this.roofInsulation,
      floorType: floorType ?? this.floorType,
      floorUValue: floorUValue ?? this.floorUValue,
      floorArea: floorArea ?? this.floorArea,
      floorInsulated: floorInsulated ?? this.floorInsulated,
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
    if (roofType.present) {
      map['roof_type'] = Variable<String>(roofType.value);
    }
    if (roofUValue.present) {
      map['roof_u_value'] = Variable<double>(roofUValue.value);
    }
    if (roofArea.present) {
      map['roof_area'] = Variable<double>(roofArea.value);
    }
    if (roofInsulation.present) {
      map['roof_insulation'] = Variable<bool>(roofInsulation.value);
    }
    if (floorType.present) {
      map['floor_type'] = Variable<String>(floorType.value);
    }
    if (floorUValue.present) {
      map['floor_u_value'] = Variable<double>(floorUValue.value);
    }
    if (floorArea.present) {
      map['floor_area'] = Variable<double>(floorArea.value);
    }
    if (floorInsulated.present) {
      map['floor_insulated'] = Variable<bool>(floorInsulated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EnvelopesCompanion(')
          ..write('id: $id, ')
          ..write('buildingId: $buildingId, ')
          ..write('roofType: $roofType, ')
          ..write('roofUValue: $roofUValue, ')
          ..write('roofArea: $roofArea, ')
          ..write('roofInsulation: $roofInsulation, ')
          ..write('floorType: $floorType, ')
          ..write('floorUValue: $floorUValue, ')
          ..write('floorArea: $floorArea, ')
          ..write('floorInsulated: $floorInsulated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WallsTable extends Walls with TableInfo<$WallsTable, WallDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WallsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _envelopeIdMeta =
      const VerificationMeta('envelopeId');
  @override
  late final GeneratedColumn<String> envelopeId = GeneratedColumn<String>(
      'envelope_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES envelopes (id) ON DELETE CASCADE'));
  static const VerificationMeta _orientationMeta =
      const VerificationMeta('orientation');
  @override
  late final GeneratedColumn<String> orientation = GeneratedColumn<String>(
      'orientation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _uValueMeta = const VerificationMeta('uValue');
  @override
  late final GeneratedColumn<double> uValue = GeneratedColumn<double>(
      'u_value', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<double> area = GeneratedColumn<double>(
      'area', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _insulationMeta =
      const VerificationMeta('insulation');
  @override
  late final GeneratedColumn<bool> insulation = GeneratedColumn<bool>(
      'insulation', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("insulation" IN (0, 1))'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, envelopeId, orientation, type, uValue, area, insulation];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'walls';
  @override
  VerificationContext validateIntegrity(Insertable<WallDb> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('envelope_id')) {
      context.handle(
          _envelopeIdMeta,
          envelopeId.isAcceptableOrUnknown(
              data['envelope_id']!, _envelopeIdMeta));
    } else if (isInserting) {
      context.missing(_envelopeIdMeta);
    }
    if (data.containsKey('orientation')) {
      context.handle(
          _orientationMeta,
          orientation.isAcceptableOrUnknown(
              data['orientation']!, _orientationMeta));
    } else if (isInserting) {
      context.missing(_orientationMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('u_value')) {
      context.handle(_uValueMeta,
          uValue.isAcceptableOrUnknown(data['u_value']!, _uValueMeta));
    } else if (isInserting) {
      context.missing(_uValueMeta);
    }
    if (data.containsKey('area')) {
      context.handle(
          _areaMeta, area.isAcceptableOrUnknown(data['area']!, _areaMeta));
    } else if (isInserting) {
      context.missing(_areaMeta);
    }
    if (data.containsKey('insulation')) {
      context.handle(
          _insulationMeta,
          insulation.isAcceptableOrUnknown(
              data['insulation']!, _insulationMeta));
    } else if (isInserting) {
      context.missing(_insulationMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WallDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WallDb(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      envelopeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}envelope_id'])!,
      orientation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}orientation'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      uValue: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}u_value'])!,
      area: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}area'])!,
      insulation: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}insulation'])!,
    );
  }

  @override
  $WallsTable createAlias(String alias) {
    return $WallsTable(attachedDatabase, alias);
  }
}

class WallDb extends DataClass implements Insertable<WallDb> {
  final int id;
  final String envelopeId;
  final String orientation;
  final String type;
  final double uValue;
  final double area;
  final bool insulation;
  const WallDb(
      {required this.id,
      required this.envelopeId,
      required this.orientation,
      required this.type,
      required this.uValue,
      required this.area,
      required this.insulation});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['envelope_id'] = Variable<String>(envelopeId);
    map['orientation'] = Variable<String>(orientation);
    map['type'] = Variable<String>(type);
    map['u_value'] = Variable<double>(uValue);
    map['area'] = Variable<double>(area);
    map['insulation'] = Variable<bool>(insulation);
    return map;
  }

  WallsCompanion toCompanion(bool nullToAbsent) {
    return WallsCompanion(
      id: Value(id),
      envelopeId: Value(envelopeId),
      orientation: Value(orientation),
      type: Value(type),
      uValue: Value(uValue),
      area: Value(area),
      insulation: Value(insulation),
    );
  }

  factory WallDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WallDb(
      id: serializer.fromJson<int>(json['id']),
      envelopeId: serializer.fromJson<String>(json['envelopeId']),
      orientation: serializer.fromJson<String>(json['orientation']),
      type: serializer.fromJson<String>(json['type']),
      uValue: serializer.fromJson<double>(json['uValue']),
      area: serializer.fromJson<double>(json['area']),
      insulation: serializer.fromJson<bool>(json['insulation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'envelopeId': serializer.toJson<String>(envelopeId),
      'orientation': serializer.toJson<String>(orientation),
      'type': serializer.toJson<String>(type),
      'uValue': serializer.toJson<double>(uValue),
      'area': serializer.toJson<double>(area),
      'insulation': serializer.toJson<bool>(insulation),
    };
  }

  WallDb copyWith(
          {int? id,
          String? envelopeId,
          String? orientation,
          String? type,
          double? uValue,
          double? area,
          bool? insulation}) =>
      WallDb(
        id: id ?? this.id,
        envelopeId: envelopeId ?? this.envelopeId,
        orientation: orientation ?? this.orientation,
        type: type ?? this.type,
        uValue: uValue ?? this.uValue,
        area: area ?? this.area,
        insulation: insulation ?? this.insulation,
      );
  WallDb copyWithCompanion(WallsCompanion data) {
    return WallDb(
      id: data.id.present ? data.id.value : this.id,
      envelopeId:
          data.envelopeId.present ? data.envelopeId.value : this.envelopeId,
      orientation:
          data.orientation.present ? data.orientation.value : this.orientation,
      type: data.type.present ? data.type.value : this.type,
      uValue: data.uValue.present ? data.uValue.value : this.uValue,
      area: data.area.present ? data.area.value : this.area,
      insulation:
          data.insulation.present ? data.insulation.value : this.insulation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WallDb(')
          ..write('id: $id, ')
          ..write('envelopeId: $envelopeId, ')
          ..write('orientation: $orientation, ')
          ..write('type: $type, ')
          ..write('uValue: $uValue, ')
          ..write('area: $area, ')
          ..write('insulation: $insulation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, envelopeId, orientation, type, uValue, area, insulation);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WallDb &&
          other.id == this.id &&
          other.envelopeId == this.envelopeId &&
          other.orientation == this.orientation &&
          other.type == this.type &&
          other.uValue == this.uValue &&
          other.area == this.area &&
          other.insulation == this.insulation);
}

class WallsCompanion extends UpdateCompanion<WallDb> {
  final Value<int> id;
  final Value<String> envelopeId;
  final Value<String> orientation;
  final Value<String> type;
  final Value<double> uValue;
  final Value<double> area;
  final Value<bool> insulation;
  const WallsCompanion({
    this.id = const Value.absent(),
    this.envelopeId = const Value.absent(),
    this.orientation = const Value.absent(),
    this.type = const Value.absent(),
    this.uValue = const Value.absent(),
    this.area = const Value.absent(),
    this.insulation = const Value.absent(),
  });
  WallsCompanion.insert({
    this.id = const Value.absent(),
    required String envelopeId,
    required String orientation,
    required String type,
    required double uValue,
    required double area,
    required bool insulation,
  })  : envelopeId = Value(envelopeId),
        orientation = Value(orientation),
        type = Value(type),
        uValue = Value(uValue),
        area = Value(area),
        insulation = Value(insulation);
  static Insertable<WallDb> custom({
    Expression<int>? id,
    Expression<String>? envelopeId,
    Expression<String>? orientation,
    Expression<String>? type,
    Expression<double>? uValue,
    Expression<double>? area,
    Expression<bool>? insulation,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (envelopeId != null) 'envelope_id': envelopeId,
      if (orientation != null) 'orientation': orientation,
      if (type != null) 'type': type,
      if (uValue != null) 'u_value': uValue,
      if (area != null) 'area': area,
      if (insulation != null) 'insulation': insulation,
    });
  }

  WallsCompanion copyWith(
      {Value<int>? id,
      Value<String>? envelopeId,
      Value<String>? orientation,
      Value<String>? type,
      Value<double>? uValue,
      Value<double>? area,
      Value<bool>? insulation}) {
    return WallsCompanion(
      id: id ?? this.id,
      envelopeId: envelopeId ?? this.envelopeId,
      orientation: orientation ?? this.orientation,
      type: type ?? this.type,
      uValue: uValue ?? this.uValue,
      area: area ?? this.area,
      insulation: insulation ?? this.insulation,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (envelopeId.present) {
      map['envelope_id'] = Variable<String>(envelopeId.value);
    }
    if (orientation.present) {
      map['orientation'] = Variable<String>(orientation.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (uValue.present) {
      map['u_value'] = Variable<double>(uValue.value);
    }
    if (area.present) {
      map['area'] = Variable<double>(area.value);
    }
    if (insulation.present) {
      map['insulation'] = Variable<bool>(insulation.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WallsCompanion(')
          ..write('id: $id, ')
          ..write('envelopeId: $envelopeId, ')
          ..write('orientation: $orientation, ')
          ..write('type: $type, ')
          ..write('uValue: $uValue, ')
          ..write('area: $area, ')
          ..write('insulation: $insulation')
          ..write(')'))
        .toString();
  }
}

class $WindowsTable extends Windows with TableInfo<$WindowsTable, WindowDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WindowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _envelopeIdMeta =
      const VerificationMeta('envelopeId');
  @override
  late final GeneratedColumn<String> envelopeId = GeneratedColumn<String>(
      'envelope_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES envelopes (id) ON DELETE CASCADE'));
  static const VerificationMeta _orientationMeta =
      const VerificationMeta('orientation');
  @override
  late final GeneratedColumn<String> orientation = GeneratedColumn<String>(
      'orientation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
      'year', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _frameMeta = const VerificationMeta('frame');
  @override
  late final GeneratedColumn<String> frame = GeneratedColumn<String>(
      'frame', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _glazingMeta =
      const VerificationMeta('glazing');
  @override
  late final GeneratedColumn<String> glazing = GeneratedColumn<String>(
      'glazing', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _uValueMeta = const VerificationMeta('uValue');
  @override
  late final GeneratedColumn<double> uValue = GeneratedColumn<double>(
      'u_value', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<double> area = GeneratedColumn<double>(
      'area', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, envelopeId, orientation, year, frame, glazing, uValue, area];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'windows';
  @override
  VerificationContext validateIntegrity(Insertable<WindowDb> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('envelope_id')) {
      context.handle(
          _envelopeIdMeta,
          envelopeId.isAcceptableOrUnknown(
              data['envelope_id']!, _envelopeIdMeta));
    } else if (isInserting) {
      context.missing(_envelopeIdMeta);
    }
    if (data.containsKey('orientation')) {
      context.handle(
          _orientationMeta,
          orientation.isAcceptableOrUnknown(
              data['orientation']!, _orientationMeta));
    } else if (isInserting) {
      context.missing(_orientationMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
          _yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('frame')) {
      context.handle(
          _frameMeta, frame.isAcceptableOrUnknown(data['frame']!, _frameMeta));
    } else if (isInserting) {
      context.missing(_frameMeta);
    }
    if (data.containsKey('glazing')) {
      context.handle(_glazingMeta,
          glazing.isAcceptableOrUnknown(data['glazing']!, _glazingMeta));
    } else if (isInserting) {
      context.missing(_glazingMeta);
    }
    if (data.containsKey('u_value')) {
      context.handle(_uValueMeta,
          uValue.isAcceptableOrUnknown(data['u_value']!, _uValueMeta));
    } else if (isInserting) {
      context.missing(_uValueMeta);
    }
    if (data.containsKey('area')) {
      context.handle(
          _areaMeta, area.isAcceptableOrUnknown(data['area']!, _areaMeta));
    } else if (isInserting) {
      context.missing(_areaMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WindowDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WindowDb(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      envelopeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}envelope_id'])!,
      orientation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}orientation'])!,
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}year'])!,
      frame: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}frame'])!,
      glazing: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}glazing'])!,
      uValue: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}u_value'])!,
      area: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}area'])!,
    );
  }

  @override
  $WindowsTable createAlias(String alias) {
    return $WindowsTable(attachedDatabase, alias);
  }
}

class WindowDb extends DataClass implements Insertable<WindowDb> {
  final int id;
  final String envelopeId;
  final String orientation;
  final int year;
  final String frame;
  final String glazing;
  final double uValue;
  final double area;
  const WindowDb(
      {required this.id,
      required this.envelopeId,
      required this.orientation,
      required this.year,
      required this.frame,
      required this.glazing,
      required this.uValue,
      required this.area});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['envelope_id'] = Variable<String>(envelopeId);
    map['orientation'] = Variable<String>(orientation);
    map['year'] = Variable<int>(year);
    map['frame'] = Variable<String>(frame);
    map['glazing'] = Variable<String>(glazing);
    map['u_value'] = Variable<double>(uValue);
    map['area'] = Variable<double>(area);
    return map;
  }

  WindowsCompanion toCompanion(bool nullToAbsent) {
    return WindowsCompanion(
      id: Value(id),
      envelopeId: Value(envelopeId),
      orientation: Value(orientation),
      year: Value(year),
      frame: Value(frame),
      glazing: Value(glazing),
      uValue: Value(uValue),
      area: Value(area),
    );
  }

  factory WindowDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WindowDb(
      id: serializer.fromJson<int>(json['id']),
      envelopeId: serializer.fromJson<String>(json['envelopeId']),
      orientation: serializer.fromJson<String>(json['orientation']),
      year: serializer.fromJson<int>(json['year']),
      frame: serializer.fromJson<String>(json['frame']),
      glazing: serializer.fromJson<String>(json['glazing']),
      uValue: serializer.fromJson<double>(json['uValue']),
      area: serializer.fromJson<double>(json['area']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'envelopeId': serializer.toJson<String>(envelopeId),
      'orientation': serializer.toJson<String>(orientation),
      'year': serializer.toJson<int>(year),
      'frame': serializer.toJson<String>(frame),
      'glazing': serializer.toJson<String>(glazing),
      'uValue': serializer.toJson<double>(uValue),
      'area': serializer.toJson<double>(area),
    };
  }

  WindowDb copyWith(
          {int? id,
          String? envelopeId,
          String? orientation,
          int? year,
          String? frame,
          String? glazing,
          double? uValue,
          double? area}) =>
      WindowDb(
        id: id ?? this.id,
        envelopeId: envelopeId ?? this.envelopeId,
        orientation: orientation ?? this.orientation,
        year: year ?? this.year,
        frame: frame ?? this.frame,
        glazing: glazing ?? this.glazing,
        uValue: uValue ?? this.uValue,
        area: area ?? this.area,
      );
  WindowDb copyWithCompanion(WindowsCompanion data) {
    return WindowDb(
      id: data.id.present ? data.id.value : this.id,
      envelopeId:
          data.envelopeId.present ? data.envelopeId.value : this.envelopeId,
      orientation:
          data.orientation.present ? data.orientation.value : this.orientation,
      year: data.year.present ? data.year.value : this.year,
      frame: data.frame.present ? data.frame.value : this.frame,
      glazing: data.glazing.present ? data.glazing.value : this.glazing,
      uValue: data.uValue.present ? data.uValue.value : this.uValue,
      area: data.area.present ? data.area.value : this.area,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WindowDb(')
          ..write('id: $id, ')
          ..write('envelopeId: $envelopeId, ')
          ..write('orientation: $orientation, ')
          ..write('year: $year, ')
          ..write('frame: $frame, ')
          ..write('glazing: $glazing, ')
          ..write('uValue: $uValue, ')
          ..write('area: $area')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, envelopeId, orientation, year, frame, glazing, uValue, area);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WindowDb &&
          other.id == this.id &&
          other.envelopeId == this.envelopeId &&
          other.orientation == this.orientation &&
          other.year == this.year &&
          other.frame == this.frame &&
          other.glazing == this.glazing &&
          other.uValue == this.uValue &&
          other.area == this.area);
}

class WindowsCompanion extends UpdateCompanion<WindowDb> {
  final Value<int> id;
  final Value<String> envelopeId;
  final Value<String> orientation;
  final Value<int> year;
  final Value<String> frame;
  final Value<String> glazing;
  final Value<double> uValue;
  final Value<double> area;
  const WindowsCompanion({
    this.id = const Value.absent(),
    this.envelopeId = const Value.absent(),
    this.orientation = const Value.absent(),
    this.year = const Value.absent(),
    this.frame = const Value.absent(),
    this.glazing = const Value.absent(),
    this.uValue = const Value.absent(),
    this.area = const Value.absent(),
  });
  WindowsCompanion.insert({
    this.id = const Value.absent(),
    required String envelopeId,
    required String orientation,
    required int year,
    required String frame,
    required String glazing,
    required double uValue,
    required double area,
  })  : envelopeId = Value(envelopeId),
        orientation = Value(orientation),
        year = Value(year),
        frame = Value(frame),
        glazing = Value(glazing),
        uValue = Value(uValue),
        area = Value(area);
  static Insertable<WindowDb> custom({
    Expression<int>? id,
    Expression<String>? envelopeId,
    Expression<String>? orientation,
    Expression<int>? year,
    Expression<String>? frame,
    Expression<String>? glazing,
    Expression<double>? uValue,
    Expression<double>? area,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (envelopeId != null) 'envelope_id': envelopeId,
      if (orientation != null) 'orientation': orientation,
      if (year != null) 'year': year,
      if (frame != null) 'frame': frame,
      if (glazing != null) 'glazing': glazing,
      if (uValue != null) 'u_value': uValue,
      if (area != null) 'area': area,
    });
  }

  WindowsCompanion copyWith(
      {Value<int>? id,
      Value<String>? envelopeId,
      Value<String>? orientation,
      Value<int>? year,
      Value<String>? frame,
      Value<String>? glazing,
      Value<double>? uValue,
      Value<double>? area}) {
    return WindowsCompanion(
      id: id ?? this.id,
      envelopeId: envelopeId ?? this.envelopeId,
      orientation: orientation ?? this.orientation,
      year: year ?? this.year,
      frame: frame ?? this.frame,
      glazing: glazing ?? this.glazing,
      uValue: uValue ?? this.uValue,
      area: area ?? this.area,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (envelopeId.present) {
      map['envelope_id'] = Variable<String>(envelopeId.value);
    }
    if (orientation.present) {
      map['orientation'] = Variable<String>(orientation.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (frame.present) {
      map['frame'] = Variable<String>(frame.value);
    }
    if (glazing.present) {
      map['glazing'] = Variable<String>(glazing.value);
    }
    if (uValue.present) {
      map['u_value'] = Variable<double>(uValue.value);
    }
    if (area.present) {
      map['area'] = Variable<double>(area.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WindowsCompanion(')
          ..write('id: $id, ')
          ..write('envelopeId: $envelopeId, ')
          ..write('orientation: $orientation, ')
          ..write('year: $year, ')
          ..write('frame: $frame, ')
          ..write('glazing: $glazing, ')
          ..write('uValue: $uValue, ')
          ..write('area: $area')
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
        discipline
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
      required this.discipline});
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
          String? discipline}) =>
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
          ..write('discipline: $discipline')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, name, params, floorId,
      buildingId, isMarker, markerInfo, markerType, discipline);
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
          other.discipline == this.discipline);
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
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConsumptionsTable extends Consumptions
    with TableInfo<$ConsumptionsTable, ConsumptionDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConsumptionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _electricityKWhMeta =
      const VerificationMeta('electricityKWh');
  @override
  late final GeneratedColumn<String> electricityKWh = GeneratedColumn<String>(
      'electricity_k_wh', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _gasKWhMeta = const VerificationMeta('gasKWh');
  @override
  late final GeneratedColumn<String> gasKWh = GeneratedColumn<String>(
      'gas_k_wh', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, buildingId, electricityKWh, gasKWh];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'consumptions';
  @override
  VerificationContext validateIntegrity(Insertable<ConsumptionDb> instance,
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
    if (data.containsKey('electricity_k_wh')) {
      context.handle(
          _electricityKWhMeta,
          electricityKWh.isAcceptableOrUnknown(
              data['electricity_k_wh']!, _electricityKWhMeta));
    } else if (isInserting) {
      context.missing(_electricityKWhMeta);
    }
    if (data.containsKey('gas_k_wh')) {
      context.handle(_gasKWhMeta,
          gasKWh.isAcceptableOrUnknown(data['gas_k_wh']!, _gasKWhMeta));
    } else if (isInserting) {
      context.missing(_gasKWhMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConsumptionDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConsumptionDb(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      buildingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}building_id'])!,
      electricityKWh: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}electricity_k_wh'])!,
      gasKWh: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gas_k_wh'])!,
    );
  }

  @override
  $ConsumptionsTable createAlias(String alias) {
    return $ConsumptionsTable(attachedDatabase, alias);
  }
}

class ConsumptionDb extends DataClass implements Insertable<ConsumptionDb> {
  final String id;
  final String buildingId;
  final String electricityKWh;
  final String gasKWh;
  const ConsumptionDb(
      {required this.id,
      required this.buildingId,
      required this.electricityKWh,
      required this.gasKWh});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['building_id'] = Variable<String>(buildingId);
    map['electricity_k_wh'] = Variable<String>(electricityKWh);
    map['gas_k_wh'] = Variable<String>(gasKWh);
    return map;
  }

  ConsumptionsCompanion toCompanion(bool nullToAbsent) {
    return ConsumptionsCompanion(
      id: Value(id),
      buildingId: Value(buildingId),
      electricityKWh: Value(electricityKWh),
      gasKWh: Value(gasKWh),
    );
  }

  factory ConsumptionDb.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConsumptionDb(
      id: serializer.fromJson<String>(json['id']),
      buildingId: serializer.fromJson<String>(json['buildingId']),
      electricityKWh: serializer.fromJson<String>(json['electricityKWh']),
      gasKWh: serializer.fromJson<String>(json['gasKWh']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'buildingId': serializer.toJson<String>(buildingId),
      'electricityKWh': serializer.toJson<String>(electricityKWh),
      'gasKWh': serializer.toJson<String>(gasKWh),
    };
  }

  ConsumptionDb copyWith(
          {String? id,
          String? buildingId,
          String? electricityKWh,
          String? gasKWh}) =>
      ConsumptionDb(
        id: id ?? this.id,
        buildingId: buildingId ?? this.buildingId,
        electricityKWh: electricityKWh ?? this.electricityKWh,
        gasKWh: gasKWh ?? this.gasKWh,
      );
  ConsumptionDb copyWithCompanion(ConsumptionsCompanion data) {
    return ConsumptionDb(
      id: data.id.present ? data.id.value : this.id,
      buildingId:
          data.buildingId.present ? data.buildingId.value : this.buildingId,
      electricityKWh: data.electricityKWh.present
          ? data.electricityKWh.value
          : this.electricityKWh,
      gasKWh: data.gasKWh.present ? data.gasKWh.value : this.gasKWh,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConsumptionDb(')
          ..write('id: $id, ')
          ..write('buildingId: $buildingId, ')
          ..write('electricityKWh: $electricityKWh, ')
          ..write('gasKWh: $gasKWh')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, buildingId, electricityKWh, gasKWh);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConsumptionDb &&
          other.id == this.id &&
          other.buildingId == this.buildingId &&
          other.electricityKWh == this.electricityKWh &&
          other.gasKWh == this.gasKWh);
}

class ConsumptionsCompanion extends UpdateCompanion<ConsumptionDb> {
  final Value<String> id;
  final Value<String> buildingId;
  final Value<String> electricityKWh;
  final Value<String> gasKWh;
  final Value<int> rowid;
  const ConsumptionsCompanion({
    this.id = const Value.absent(),
    this.buildingId = const Value.absent(),
    this.electricityKWh = const Value.absent(),
    this.gasKWh = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConsumptionsCompanion.insert({
    required String id,
    required String buildingId,
    required String electricityKWh,
    required String gasKWh,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        buildingId = Value(buildingId),
        electricityKWh = Value(electricityKWh),
        gasKWh = Value(gasKWh);
  static Insertable<ConsumptionDb> custom({
    Expression<String>? id,
    Expression<String>? buildingId,
    Expression<String>? electricityKWh,
    Expression<String>? gasKWh,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (buildingId != null) 'building_id': buildingId,
      if (electricityKWh != null) 'electricity_k_wh': electricityKWh,
      if (gasKWh != null) 'gas_k_wh': gasKWh,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConsumptionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? buildingId,
      Value<String>? electricityKWh,
      Value<String>? gasKWh,
      Value<int>? rowid}) {
    return ConsumptionsCompanion(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      electricityKWh: electricityKWh ?? this.electricityKWh,
      gasKWh: gasKWh ?? this.gasKWh,
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
    if (electricityKWh.present) {
      map['electricity_k_wh'] = Variable<String>(electricityKWh.value);
    }
    if (gasKWh.present) {
      map['gas_k_wh'] = Variable<String>(gasKWh.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConsumptionsCompanion(')
          ..write('id: $id, ')
          ..write('buildingId: $buildingId, ')
          ..write('electricityKWh: $electricityKWh, ')
          ..write('gasKWh: $gasKWh, ')
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $BuildingsTable buildings = $BuildingsTable(this);
  late final $EnvelopesTable envelopes = $EnvelopesTable(this);
  late final $WallsTable walls = $WallsTable(this);
  late final $WindowsTable windows = $WindowsTable(this);
  late final $FloorPlansTable floorPlans = $FloorPlansTable(this);
  late final $AnlagenTable anlagen = $AnlagenTable(this);
  late final $ConsumptionsTable consumptions = $ConsumptionsTable(this);
  late final $AttachmentsTableTable attachmentsTable =
      $AttachmentsTableTable(this);
  late final $DisziplinenTable disziplinen = $DisziplinenTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        projects,
        buildings,
        envelopes,
        walls,
        windows,
        floorPlans,
        anlagen,
        consumptions,
        attachmentsTable,
        disziplinen
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
              TableUpdate('envelopes', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('envelopes',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('walls', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('envelopes',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('windows', kind: UpdateKind.delete),
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
              TableUpdate('consumptions', kind: UpdateKind.delete),
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
        ],
      );
}

typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  required String id,
  required String name,
  required String description,
  required String customer,
  Value<int> rowid,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> description,
  Value<String> customer,
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
    PrefetchHooks Function({bool buildingsRefs})> {
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
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion(
            id: id,
            name: name,
            description: description,
            customer: customer,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String description,
            required String customer,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion.insert(
            id: id,
            name: name,
            description: description,
            customer: customer,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ProjectsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({buildingsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (buildingsRefs) db.buildings],
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
    PrefetchHooks Function({bool buildingsRefs})>;
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

  static MultiTypedResultKey<$EnvelopesTable, List<EnvelopeDb>>
      _envelopesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.envelopes,
          aliasName:
              $_aliasNameGenerator(db.buildings.id, db.envelopes.buildingId));

  $$EnvelopesTableProcessedTableManager get envelopesRefs {
    final manager = $$EnvelopesTableTableManager($_db, $_db.envelopes)
        .filter((f) => f.buildingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_envelopesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
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

  static MultiTypedResultKey<$ConsumptionsTable, List<ConsumptionDb>>
      _consumptionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.consumptions,
              aliasName: $_aliasNameGenerator(
                  db.buildings.id, db.consumptions.buildingId));

  $$ConsumptionsTableProcessedTableManager get consumptionsRefs {
    final manager = $$ConsumptionsTableTableManager($_db, $_db.consumptions)
        .filter((f) => f.buildingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_consumptionsRefsTable($_db));
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

  Expression<bool> envelopesRefs(
      Expression<bool> Function($$EnvelopesTableFilterComposer f) f) {
    final $$EnvelopesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.envelopes,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnvelopesTableFilterComposer(
              $db: $db,
              $table: $db.envelopes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
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

  Expression<bool> consumptionsRefs(
      Expression<bool> Function($$ConsumptionsTableFilterComposer f) f) {
    final $$ConsumptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.consumptions,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConsumptionsTableFilterComposer(
              $db: $db,
              $table: $db.consumptions,
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

  Expression<T> envelopesRefs<T extends Object>(
      Expression<T> Function($$EnvelopesTableAnnotationComposer a) f) {
    final $$EnvelopesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.envelopes,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnvelopesTableAnnotationComposer(
              $db: $db,
              $table: $db.envelopes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
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

  Expression<T> consumptionsRefs<T extends Object>(
      Expression<T> Function($$ConsumptionsTableAnnotationComposer a) f) {
    final $$ConsumptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.consumptions,
        getReferencedColumn: (t) => t.buildingId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConsumptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.consumptions,
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
        bool envelopesRefs,
        bool floorPlansRefs,
        bool anlagenRefs,
        bool consumptionsRefs,
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
              envelopesRefs = false,
              floorPlansRefs = false,
              anlagenRefs = false,
              consumptionsRefs = false,
              attachmentsTableRefs = false,
              disziplinenRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (envelopesRefs) db.envelopes,
                if (floorPlansRefs) db.floorPlans,
                if (anlagenRefs) db.anlagen,
                if (consumptionsRefs) db.consumptions,
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
                  if (envelopesRefs)
                    await $_getPrefetchedData<BuildingDb, $BuildingsTable,
                            EnvelopeDb>(
                        currentTable: table,
                        referencedTable:
                            $$BuildingsTableReferences._envelopesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BuildingsTableReferences(db, table, p0)
                                .envelopesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.buildingId == item.id),
                        typedResults: items),
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
                  if (consumptionsRefs)
                    await $_getPrefetchedData<BuildingDb, $BuildingsTable,
                            ConsumptionDb>(
                        currentTable: table,
                        referencedTable: $$BuildingsTableReferences
                            ._consumptionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BuildingsTableReferences(db, table, p0)
                                .consumptionsRefs,
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
        bool envelopesRefs,
        bool floorPlansRefs,
        bool anlagenRefs,
        bool consumptionsRefs,
        bool attachmentsTableRefs,
        bool disziplinenRefs})>;
typedef $$EnvelopesTableCreateCompanionBuilder = EnvelopesCompanion Function({
  required String id,
  required String buildingId,
  required String roofType,
  required double roofUValue,
  required double roofArea,
  required bool roofInsulation,
  required String floorType,
  required double floorUValue,
  required double floorArea,
  required bool floorInsulated,
  Value<int> rowid,
});
typedef $$EnvelopesTableUpdateCompanionBuilder = EnvelopesCompanion Function({
  Value<String> id,
  Value<String> buildingId,
  Value<String> roofType,
  Value<double> roofUValue,
  Value<double> roofArea,
  Value<bool> roofInsulation,
  Value<String> floorType,
  Value<double> floorUValue,
  Value<double> floorArea,
  Value<bool> floorInsulated,
  Value<int> rowid,
});

final class $$EnvelopesTableReferences
    extends BaseReferences<_$AppDatabase, $EnvelopesTable, EnvelopeDb> {
  $$EnvelopesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BuildingsTable _buildingIdTable(_$AppDatabase db) =>
      db.buildings.createAlias(
          $_aliasNameGenerator(db.envelopes.buildingId, db.buildings.id));

  $$BuildingsTableProcessedTableManager get buildingId {
    final $_column = $_itemColumn<String>('building_id')!;

    final manager = $$BuildingsTableTableManager($_db, $_db.buildings)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_buildingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$WallsTable, List<WallDb>> _wallsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.walls,
          aliasName:
              $_aliasNameGenerator(db.envelopes.id, db.walls.envelopeId));

  $$WallsTableProcessedTableManager get wallsRefs {
    final manager = $$WallsTableTableManager($_db, $_db.walls)
        .filter((f) => f.envelopeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wallsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WindowsTable, List<WindowDb>> _windowsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.windows,
          aliasName:
              $_aliasNameGenerator(db.envelopes.id, db.windows.envelopeId));

  $$WindowsTableProcessedTableManager get windowsRefs {
    final manager = $$WindowsTableTableManager($_db, $_db.windows)
        .filter((f) => f.envelopeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_windowsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$EnvelopesTableFilterComposer
    extends Composer<_$AppDatabase, $EnvelopesTable> {
  $$EnvelopesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roofType => $composableBuilder(
      column: $table.roofType, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get roofUValue => $composableBuilder(
      column: $table.roofUValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get roofArea => $composableBuilder(
      column: $table.roofArea, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get roofInsulation => $composableBuilder(
      column: $table.roofInsulation,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get floorType => $composableBuilder(
      column: $table.floorType, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get floorUValue => $composableBuilder(
      column: $table.floorUValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get floorArea => $composableBuilder(
      column: $table.floorArea, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get floorInsulated => $composableBuilder(
      column: $table.floorInsulated,
      builder: (column) => ColumnFilters(column));

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

  Expression<bool> wallsRefs(
      Expression<bool> Function($$WallsTableFilterComposer f) f) {
    final $$WallsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.walls,
        getReferencedColumn: (t) => t.envelopeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WallsTableFilterComposer(
              $db: $db,
              $table: $db.walls,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> windowsRefs(
      Expression<bool> Function($$WindowsTableFilterComposer f) f) {
    final $$WindowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.windows,
        getReferencedColumn: (t) => t.envelopeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WindowsTableFilterComposer(
              $db: $db,
              $table: $db.windows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$EnvelopesTableOrderingComposer
    extends Composer<_$AppDatabase, $EnvelopesTable> {
  $$EnvelopesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roofType => $composableBuilder(
      column: $table.roofType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get roofUValue => $composableBuilder(
      column: $table.roofUValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get roofArea => $composableBuilder(
      column: $table.roofArea, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get roofInsulation => $composableBuilder(
      column: $table.roofInsulation,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get floorType => $composableBuilder(
      column: $table.floorType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get floorUValue => $composableBuilder(
      column: $table.floorUValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get floorArea => $composableBuilder(
      column: $table.floorArea, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get floorInsulated => $composableBuilder(
      column: $table.floorInsulated,
      builder: (column) => ColumnOrderings(column));

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

class $$EnvelopesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EnvelopesTable> {
  $$EnvelopesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get roofType =>
      $composableBuilder(column: $table.roofType, builder: (column) => column);

  GeneratedColumn<double> get roofUValue => $composableBuilder(
      column: $table.roofUValue, builder: (column) => column);

  GeneratedColumn<double> get roofArea =>
      $composableBuilder(column: $table.roofArea, builder: (column) => column);

  GeneratedColumn<bool> get roofInsulation => $composableBuilder(
      column: $table.roofInsulation, builder: (column) => column);

  GeneratedColumn<String> get floorType =>
      $composableBuilder(column: $table.floorType, builder: (column) => column);

  GeneratedColumn<double> get floorUValue => $composableBuilder(
      column: $table.floorUValue, builder: (column) => column);

  GeneratedColumn<double> get floorArea =>
      $composableBuilder(column: $table.floorArea, builder: (column) => column);

  GeneratedColumn<bool> get floorInsulated => $composableBuilder(
      column: $table.floorInsulated, builder: (column) => column);

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

  Expression<T> wallsRefs<T extends Object>(
      Expression<T> Function($$WallsTableAnnotationComposer a) f) {
    final $$WallsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.walls,
        getReferencedColumn: (t) => t.envelopeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WallsTableAnnotationComposer(
              $db: $db,
              $table: $db.walls,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> windowsRefs<T extends Object>(
      Expression<T> Function($$WindowsTableAnnotationComposer a) f) {
    final $$WindowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.windows,
        getReferencedColumn: (t) => t.envelopeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WindowsTableAnnotationComposer(
              $db: $db,
              $table: $db.windows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$EnvelopesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EnvelopesTable,
    EnvelopeDb,
    $$EnvelopesTableFilterComposer,
    $$EnvelopesTableOrderingComposer,
    $$EnvelopesTableAnnotationComposer,
    $$EnvelopesTableCreateCompanionBuilder,
    $$EnvelopesTableUpdateCompanionBuilder,
    (EnvelopeDb, $$EnvelopesTableReferences),
    EnvelopeDb,
    PrefetchHooks Function(
        {bool buildingId, bool wallsRefs, bool windowsRefs})> {
  $$EnvelopesTableTableManager(_$AppDatabase db, $EnvelopesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EnvelopesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EnvelopesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EnvelopesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> buildingId = const Value.absent(),
            Value<String> roofType = const Value.absent(),
            Value<double> roofUValue = const Value.absent(),
            Value<double> roofArea = const Value.absent(),
            Value<bool> roofInsulation = const Value.absent(),
            Value<String> floorType = const Value.absent(),
            Value<double> floorUValue = const Value.absent(),
            Value<double> floorArea = const Value.absent(),
            Value<bool> floorInsulated = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EnvelopesCompanion(
            id: id,
            buildingId: buildingId,
            roofType: roofType,
            roofUValue: roofUValue,
            roofArea: roofArea,
            roofInsulation: roofInsulation,
            floorType: floorType,
            floorUValue: floorUValue,
            floorArea: floorArea,
            floorInsulated: floorInsulated,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String buildingId,
            required String roofType,
            required double roofUValue,
            required double roofArea,
            required bool roofInsulation,
            required String floorType,
            required double floorUValue,
            required double floorArea,
            required bool floorInsulated,
            Value<int> rowid = const Value.absent(),
          }) =>
              EnvelopesCompanion.insert(
            id: id,
            buildingId: buildingId,
            roofType: roofType,
            roofUValue: roofUValue,
            roofArea: roofArea,
            roofInsulation: roofInsulation,
            floorType: floorType,
            floorUValue: floorUValue,
            floorArea: floorArea,
            floorInsulated: floorInsulated,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$EnvelopesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {buildingId = false, wallsRefs = false, windowsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (wallsRefs) db.walls,
                if (windowsRefs) db.windows
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
                if (buildingId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.buildingId,
                    referencedTable:
                        $$EnvelopesTableReferences._buildingIdTable(db),
                    referencedColumn:
                        $$EnvelopesTableReferences._buildingIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (wallsRefs)
                    await $_getPrefetchedData<EnvelopeDb, $EnvelopesTable,
                            WallDb>(
                        currentTable: table,
                        referencedTable:
                            $$EnvelopesTableReferences._wallsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$EnvelopesTableReferences(db, table, p0).wallsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.envelopeId == item.id),
                        typedResults: items),
                  if (windowsRefs)
                    await $_getPrefetchedData<EnvelopeDb, $EnvelopesTable,
                            WindowDb>(
                        currentTable: table,
                        referencedTable:
                            $$EnvelopesTableReferences._windowsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$EnvelopesTableReferences(db, table, p0)
                                .windowsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.envelopeId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$EnvelopesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EnvelopesTable,
    EnvelopeDb,
    $$EnvelopesTableFilterComposer,
    $$EnvelopesTableOrderingComposer,
    $$EnvelopesTableAnnotationComposer,
    $$EnvelopesTableCreateCompanionBuilder,
    $$EnvelopesTableUpdateCompanionBuilder,
    (EnvelopeDb, $$EnvelopesTableReferences),
    EnvelopeDb,
    PrefetchHooks Function(
        {bool buildingId, bool wallsRefs, bool windowsRefs})>;
typedef $$WallsTableCreateCompanionBuilder = WallsCompanion Function({
  Value<int> id,
  required String envelopeId,
  required String orientation,
  required String type,
  required double uValue,
  required double area,
  required bool insulation,
});
typedef $$WallsTableUpdateCompanionBuilder = WallsCompanion Function({
  Value<int> id,
  Value<String> envelopeId,
  Value<String> orientation,
  Value<String> type,
  Value<double> uValue,
  Value<double> area,
  Value<bool> insulation,
});

final class $$WallsTableReferences
    extends BaseReferences<_$AppDatabase, $WallsTable, WallDb> {
  $$WallsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EnvelopesTable _envelopeIdTable(_$AppDatabase db) => db.envelopes
      .createAlias($_aliasNameGenerator(db.walls.envelopeId, db.envelopes.id));

  $$EnvelopesTableProcessedTableManager get envelopeId {
    final $_column = $_itemColumn<String>('envelope_id')!;

    final manager = $$EnvelopesTableTableManager($_db, $_db.envelopes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_envelopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WallsTableFilterComposer extends Composer<_$AppDatabase, $WallsTable> {
  $$WallsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orientation => $composableBuilder(
      column: $table.orientation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get uValue => $composableBuilder(
      column: $table.uValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get area => $composableBuilder(
      column: $table.area, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get insulation => $composableBuilder(
      column: $table.insulation, builder: (column) => ColumnFilters(column));

  $$EnvelopesTableFilterComposer get envelopeId {
    final $$EnvelopesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.envelopeId,
        referencedTable: $db.envelopes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnvelopesTableFilterComposer(
              $db: $db,
              $table: $db.envelopes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WallsTableOrderingComposer
    extends Composer<_$AppDatabase, $WallsTable> {
  $$WallsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orientation => $composableBuilder(
      column: $table.orientation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get uValue => $composableBuilder(
      column: $table.uValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get area => $composableBuilder(
      column: $table.area, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get insulation => $composableBuilder(
      column: $table.insulation, builder: (column) => ColumnOrderings(column));

  $$EnvelopesTableOrderingComposer get envelopeId {
    final $$EnvelopesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.envelopeId,
        referencedTable: $db.envelopes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnvelopesTableOrderingComposer(
              $db: $db,
              $table: $db.envelopes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WallsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WallsTable> {
  $$WallsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orientation => $composableBuilder(
      column: $table.orientation, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get uValue =>
      $composableBuilder(column: $table.uValue, builder: (column) => column);

  GeneratedColumn<double> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  GeneratedColumn<bool> get insulation => $composableBuilder(
      column: $table.insulation, builder: (column) => column);

  $$EnvelopesTableAnnotationComposer get envelopeId {
    final $$EnvelopesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.envelopeId,
        referencedTable: $db.envelopes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnvelopesTableAnnotationComposer(
              $db: $db,
              $table: $db.envelopes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WallsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WallsTable,
    WallDb,
    $$WallsTableFilterComposer,
    $$WallsTableOrderingComposer,
    $$WallsTableAnnotationComposer,
    $$WallsTableCreateCompanionBuilder,
    $$WallsTableUpdateCompanionBuilder,
    (WallDb, $$WallsTableReferences),
    WallDb,
    PrefetchHooks Function({bool envelopeId})> {
  $$WallsTableTableManager(_$AppDatabase db, $WallsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WallsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WallsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WallsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> envelopeId = const Value.absent(),
            Value<String> orientation = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> uValue = const Value.absent(),
            Value<double> area = const Value.absent(),
            Value<bool> insulation = const Value.absent(),
          }) =>
              WallsCompanion(
            id: id,
            envelopeId: envelopeId,
            orientation: orientation,
            type: type,
            uValue: uValue,
            area: area,
            insulation: insulation,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String envelopeId,
            required String orientation,
            required String type,
            required double uValue,
            required double area,
            required bool insulation,
          }) =>
              WallsCompanion.insert(
            id: id,
            envelopeId: envelopeId,
            orientation: orientation,
            type: type,
            uValue: uValue,
            area: area,
            insulation: insulation,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$WallsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({envelopeId = false}) {
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
                if (envelopeId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.envelopeId,
                    referencedTable:
                        $$WallsTableReferences._envelopeIdTable(db),
                    referencedColumn:
                        $$WallsTableReferences._envelopeIdTable(db).id,
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

typedef $$WallsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WallsTable,
    WallDb,
    $$WallsTableFilterComposer,
    $$WallsTableOrderingComposer,
    $$WallsTableAnnotationComposer,
    $$WallsTableCreateCompanionBuilder,
    $$WallsTableUpdateCompanionBuilder,
    (WallDb, $$WallsTableReferences),
    WallDb,
    PrefetchHooks Function({bool envelopeId})>;
typedef $$WindowsTableCreateCompanionBuilder = WindowsCompanion Function({
  Value<int> id,
  required String envelopeId,
  required String orientation,
  required int year,
  required String frame,
  required String glazing,
  required double uValue,
  required double area,
});
typedef $$WindowsTableUpdateCompanionBuilder = WindowsCompanion Function({
  Value<int> id,
  Value<String> envelopeId,
  Value<String> orientation,
  Value<int> year,
  Value<String> frame,
  Value<String> glazing,
  Value<double> uValue,
  Value<double> area,
});

final class $$WindowsTableReferences
    extends BaseReferences<_$AppDatabase, $WindowsTable, WindowDb> {
  $$WindowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EnvelopesTable _envelopeIdTable(_$AppDatabase db) =>
      db.envelopes.createAlias(
          $_aliasNameGenerator(db.windows.envelopeId, db.envelopes.id));

  $$EnvelopesTableProcessedTableManager get envelopeId {
    final $_column = $_itemColumn<String>('envelope_id')!;

    final manager = $$EnvelopesTableTableManager($_db, $_db.envelopes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_envelopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WindowsTableFilterComposer
    extends Composer<_$AppDatabase, $WindowsTable> {
  $$WindowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orientation => $composableBuilder(
      column: $table.orientation, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get frame => $composableBuilder(
      column: $table.frame, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get glazing => $composableBuilder(
      column: $table.glazing, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get uValue => $composableBuilder(
      column: $table.uValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get area => $composableBuilder(
      column: $table.area, builder: (column) => ColumnFilters(column));

  $$EnvelopesTableFilterComposer get envelopeId {
    final $$EnvelopesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.envelopeId,
        referencedTable: $db.envelopes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnvelopesTableFilterComposer(
              $db: $db,
              $table: $db.envelopes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WindowsTableOrderingComposer
    extends Composer<_$AppDatabase, $WindowsTable> {
  $$WindowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orientation => $composableBuilder(
      column: $table.orientation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get frame => $composableBuilder(
      column: $table.frame, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get glazing => $composableBuilder(
      column: $table.glazing, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get uValue => $composableBuilder(
      column: $table.uValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get area => $composableBuilder(
      column: $table.area, builder: (column) => ColumnOrderings(column));

  $$EnvelopesTableOrderingComposer get envelopeId {
    final $$EnvelopesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.envelopeId,
        referencedTable: $db.envelopes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnvelopesTableOrderingComposer(
              $db: $db,
              $table: $db.envelopes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WindowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WindowsTable> {
  $$WindowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orientation => $composableBuilder(
      column: $table.orientation, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get frame =>
      $composableBuilder(column: $table.frame, builder: (column) => column);

  GeneratedColumn<String> get glazing =>
      $composableBuilder(column: $table.glazing, builder: (column) => column);

  GeneratedColumn<double> get uValue =>
      $composableBuilder(column: $table.uValue, builder: (column) => column);

  GeneratedColumn<double> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  $$EnvelopesTableAnnotationComposer get envelopeId {
    final $$EnvelopesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.envelopeId,
        referencedTable: $db.envelopes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnvelopesTableAnnotationComposer(
              $db: $db,
              $table: $db.envelopes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WindowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WindowsTable,
    WindowDb,
    $$WindowsTableFilterComposer,
    $$WindowsTableOrderingComposer,
    $$WindowsTableAnnotationComposer,
    $$WindowsTableCreateCompanionBuilder,
    $$WindowsTableUpdateCompanionBuilder,
    (WindowDb, $$WindowsTableReferences),
    WindowDb,
    PrefetchHooks Function({bool envelopeId})> {
  $$WindowsTableTableManager(_$AppDatabase db, $WindowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WindowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WindowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WindowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> envelopeId = const Value.absent(),
            Value<String> orientation = const Value.absent(),
            Value<int> year = const Value.absent(),
            Value<String> frame = const Value.absent(),
            Value<String> glazing = const Value.absent(),
            Value<double> uValue = const Value.absent(),
            Value<double> area = const Value.absent(),
          }) =>
              WindowsCompanion(
            id: id,
            envelopeId: envelopeId,
            orientation: orientation,
            year: year,
            frame: frame,
            glazing: glazing,
            uValue: uValue,
            area: area,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String envelopeId,
            required String orientation,
            required int year,
            required String frame,
            required String glazing,
            required double uValue,
            required double area,
          }) =>
              WindowsCompanion.insert(
            id: id,
            envelopeId: envelopeId,
            orientation: orientation,
            year: year,
            frame: frame,
            glazing: glazing,
            uValue: uValue,
            area: area,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$WindowsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({envelopeId = false}) {
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
                if (envelopeId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.envelopeId,
                    referencedTable:
                        $$WindowsTableReferences._envelopeIdTable(db),
                    referencedColumn:
                        $$WindowsTableReferences._envelopeIdTable(db).id,
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

typedef $$WindowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WindowsTable,
    WindowDb,
    $$WindowsTableFilterComposer,
    $$WindowsTableOrderingComposer,
    $$WindowsTableAnnotationComposer,
    $$WindowsTableCreateCompanionBuilder,
    $$WindowsTableUpdateCompanionBuilder,
    (WindowDb, $$WindowsTableReferences),
    WindowDb,
    PrefetchHooks Function({bool envelopeId})>;
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
typedef $$ConsumptionsTableCreateCompanionBuilder = ConsumptionsCompanion
    Function({
  required String id,
  required String buildingId,
  required String electricityKWh,
  required String gasKWh,
  Value<int> rowid,
});
typedef $$ConsumptionsTableUpdateCompanionBuilder = ConsumptionsCompanion
    Function({
  Value<String> id,
  Value<String> buildingId,
  Value<String> electricityKWh,
  Value<String> gasKWh,
  Value<int> rowid,
});

final class $$ConsumptionsTableReferences
    extends BaseReferences<_$AppDatabase, $ConsumptionsTable, ConsumptionDb> {
  $$ConsumptionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BuildingsTable _buildingIdTable(_$AppDatabase db) =>
      db.buildings.createAlias(
          $_aliasNameGenerator(db.consumptions.buildingId, db.buildings.id));

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

class $$ConsumptionsTableFilterComposer
    extends Composer<_$AppDatabase, $ConsumptionsTable> {
  $$ConsumptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get electricityKWh => $composableBuilder(
      column: $table.electricityKWh,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gasKWh => $composableBuilder(
      column: $table.gasKWh, builder: (column) => ColumnFilters(column));

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

class $$ConsumptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConsumptionsTable> {
  $$ConsumptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get electricityKWh => $composableBuilder(
      column: $table.electricityKWh,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gasKWh => $composableBuilder(
      column: $table.gasKWh, builder: (column) => ColumnOrderings(column));

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

class $$ConsumptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConsumptionsTable> {
  $$ConsumptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get electricityKWh => $composableBuilder(
      column: $table.electricityKWh, builder: (column) => column);

  GeneratedColumn<String> get gasKWh =>
      $composableBuilder(column: $table.gasKWh, builder: (column) => column);

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

class $$ConsumptionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConsumptionsTable,
    ConsumptionDb,
    $$ConsumptionsTableFilterComposer,
    $$ConsumptionsTableOrderingComposer,
    $$ConsumptionsTableAnnotationComposer,
    $$ConsumptionsTableCreateCompanionBuilder,
    $$ConsumptionsTableUpdateCompanionBuilder,
    (ConsumptionDb, $$ConsumptionsTableReferences),
    ConsumptionDb,
    PrefetchHooks Function({bool buildingId})> {
  $$ConsumptionsTableTableManager(_$AppDatabase db, $ConsumptionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConsumptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConsumptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConsumptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> buildingId = const Value.absent(),
            Value<String> electricityKWh = const Value.absent(),
            Value<String> gasKWh = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConsumptionsCompanion(
            id: id,
            buildingId: buildingId,
            electricityKWh: electricityKWh,
            gasKWh: gasKWh,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String buildingId,
            required String electricityKWh,
            required String gasKWh,
            Value<int> rowid = const Value.absent(),
          }) =>
              ConsumptionsCompanion.insert(
            id: id,
            buildingId: buildingId,
            electricityKWh: electricityKWh,
            gasKWh: gasKWh,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ConsumptionsTableReferences(db, table, e)
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
                        $$ConsumptionsTableReferences._buildingIdTable(db),
                    referencedColumn:
                        $$ConsumptionsTableReferences._buildingIdTable(db).id,
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

typedef $$ConsumptionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ConsumptionsTable,
    ConsumptionDb,
    $$ConsumptionsTableFilterComposer,
    $$ConsumptionsTableOrderingComposer,
    $$ConsumptionsTableAnnotationComposer,
    $$ConsumptionsTableCreateCompanionBuilder,
    $$ConsumptionsTableUpdateCompanionBuilder,
    (ConsumptionDb, $$ConsumptionsTableReferences),
    ConsumptionDb,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$BuildingsTableTableManager get buildings =>
      $$BuildingsTableTableManager(_db, _db.buildings);
  $$EnvelopesTableTableManager get envelopes =>
      $$EnvelopesTableTableManager(_db, _db.envelopes);
  $$WallsTableTableManager get walls =>
      $$WallsTableTableManager(_db, _db.walls);
  $$WindowsTableTableManager get windows =>
      $$WindowsTableTableManager(_db, _db.windows);
  $$FloorPlansTableTableManager get floorPlans =>
      $$FloorPlansTableTableManager(_db, _db.floorPlans);
  $$AnlagenTableTableManager get anlagen =>
      $$AnlagenTableTableManager(_db, _db.anlagen);
  $$ConsumptionsTableTableManager get consumptions =>
      $$ConsumptionsTableTableManager(_db, _db.consumptions);
  $$AttachmentsTableTableTableManager get attachmentsTable =>
      $$AttachmentsTableTableTableManager(_db, _db.attachmentsTable);
  $$DisziplinenTableTableManager get disziplinen =>
      $$DisziplinenTableTableManager(_db, _db.disziplinen);
}
