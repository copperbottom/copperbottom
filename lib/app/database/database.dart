/// Type definition for a deserializer function for a Copperbottom entity.
typedef CBDDeserializerFunction<T extends CDBEntity> = T Function(Map<String, dynamic>);

/// A stub type that represents a database UUID data type.
/// This automatically 'falls back' to a VarChar of length 36 if the database
/// adapter does not support a UUID data type.
class UUID {
  UUID._construct();
}

/// The abstract interface that Copperbottom database adapters need to
/// implement.
abstract class CDBAdapter {
  /// Queries the presence of the specified [table] in the database. Returns
  /// true if the table exists, or was created successfully. Otherwise, returns
  /// false.
  ///
  /// If [fields] is specified and the table does not exist, automatic creation
  /// will be attempted (and the return value will be whether this succeeded),
  /// otherwise the return value will be whether the table exists.
  Future<bool> queryTable({
    required String table,
    List<CDBEntityField>? fields,
  });

  /// See [CDBTable.getById].
  Future<T?> getById<T extends CDBEntity<T>>({
    required String table,
    required String id,
    required CBDDeserializerFunction<T> deserializer,
  });

  /// See [CDBTable.where].
  CDBQueryBuilder<T> where<T extends CDBEntity<T>>(
    CDBTable<T> table,
    String condition, {
    Map<String, dynamic>? parameters,
  });

  /// See [CDBTable.whereColumn].
  CDBQueryBuilder<T> whereColumn<T extends CDBEntity<T>>(
    CDBTable<T> table,
    String column,
    dynamic value,
  );

  /// See [CDBTable.deleteById].
  Future<void> deleteById({
    required String table,
    required String id,
  });

  /// See [CDBTable.delete].
  Future<void> delete<T extends CDBEntity<T>>({
    required String table,
    required T entity,
  });

  /// See [CDBTable.save].
  /// The adapter returns a [String] containing the id of the entity if it was
  /// successful, otherwise it throws an error.
  Future<String> save<T extends CDBEntity<T>>({
    required String table,
    required T entity,
  });

  /// See [CDBTable.count].
  Future<int> count({required String table});

  /// See [CDBTable.truncate].
  Future<void> truncate({required String table});

  /// Closes the connection to the database.
  Future<void> close();
}

/// The abstract interface for a query builder – a mechanism for more complex
/// queries.
abstract class CDBQueryBuilder<T extends CDBEntity<T>> {
  /// The table that the query builder should execute the query on.
  final CDBTable<T> table;

  CDBQueryBuilder(this.table);

  /// Adds the specified [condition] (ensuring any specified [parameters] will
  /// be injected) to the list of conditions such that this AND any other
  /// conditions need to be met for the row to be returned.
  CDBQueryBuilder where(String condition, {Map<String, dynamic>? parameters});

  /// A convenience method that simply executes [where] to add a condition that
  /// the specified [column] has a value of [value] for any returned rows.
  CDBQueryBuilder whereColumn(String column, dynamic value);

  /// Adds the specified ordering to the results. If this is the first call, it
  /// adds the ordering method, additional calls chain the ordering methods.
  /// The default ordering of the column is ascending, (naturally, unless
  /// [descending] is specified).
  CDBQueryBuilder orderBy(String column, {bool descending = false});

  /// Perform a count of the resulting rows.
  Future<int> count();

  /// Select all the resulting rows and automatically cast them into the model
  /// entity. Optionally, if [columns] is specified, only the specified columns
  /// will be returned.
  ///
  /// The maximum number of rows returned can be controlled with [limit].
  Future<List<T>> select({List<String>? columns, limit = 20});

  /// Delete all the resulting rows.
  Future<void> deleteAll();
}

/// An API proxy to automatically inject the table name into all method calls
/// and casts to the correct entity.
class CDBTable<T extends CDBEntity<T>> {
  /// The database that the table belongs to.
  final CopperbottomDatabase database;

  /// The name of the table.
  final String table;

  /// The deserializer constructor tear-off for the entity class.
  final CBDDeserializerFunction<T> deserializer;

  /// A list of fields for automatic table creation. (Optional)
  /// If not specified, automatic table creation cannot be used.
  final List<CDBEntityField>? fields;

  /// Initializes a database table API proxy for the specified database and for
  /// the specified table name.
  CDBTable({
    String? table,
    required this.database,
    required this.deserializer,
    this.fields,
  }) : table = table ?? T.toString().toLowerCase();

  /// Fetches an entity from the [table], with the specified [id], returns null
  /// if the entity could not be found.
  Future<T?> getById(String id) {
    return database.adapter.getById<T>(
      table: table,
      id: id,
      deserializer: deserializer,
    );
  }

  /// Starts a query builder with the specified condition to allow for more
  /// granular control over queries.
  ///
  /// NOTE: Not all database adapters are guaranteed to support the query
  /// builder API, you should ensure that your adapter does.
  CDBQueryBuilder<T> where(String condition, {Map<String, dynamic>? parameters}) {
    return database.adapter.where<T>(this, condition, parameters: parameters);
  }

  /// Starts a query builder with the specified condition to allow for more
  /// granular control over queries.
  ///
  /// This is a convenience method for [where] that simply adds a condition
  /// that [column] be equal to [value] for all returned values.
  ///
  /// NOTE: Not all database adapters are guaranteed to support the query
  /// builder API, you should ensure that your adapter does.
  CDBQueryBuilder<T> whereColumn(String column, dynamic value) {
    return database.adapter.whereColumn<T>(this, column, value);
  }

  /// Deletes the entity with the specified [id] in the [table], if it exists.
  Future<void> deleteById({
    required String table,
    required String id,
  }) {
    return database.adapter.deleteById(
      table: table,
      id: id,
    );
  }

  /// Deletes the specified [entity] from the [table], if it exists.
  Future<void> delete({
    required String table,
    required T entity,
  }) {
    return database.adapter.delete(
      table: table,
      entity: entity,
    );
  }

  /// Persists the entity to the database. Throws an error if unsuccessful and
  /// injects the id of the entity if it was successful.
  Future<T> save(T entity) async {
    String id = await database.adapter.save(table: table, entity: entity);
    entity._id = id;
    return entity;
  }

  /// Counts all rows in the table.
  Future<int> count() {
    return database.adapter.count(table: table);
  }

  /// An alias for [truncate].
  Future<void> purge() {
    return truncate();
  }

  /// Deletes all rows in the table.
  Future<void> truncate() {
    return database.adapter.truncate(table: table);
  }
}

/// The main Copperbottom Database API. This takes an adapter which API
/// requests are forwarded to, for the data to be passed to the external
/// database.
class CopperbottomDatabase {
  /// The database adapter that acts as an interface between the database API
  /// and the actual database.
  final CDBAdapter adapter;

  /// Initializes the database API with a specific adapter.
  CopperbottomDatabase.fromAdapter({required this.adapter});

  /// The store of registered tables in the database.
  final Map<String, CDBTable> _tables = {};

  /// Registers an API proxy for the specified table that automatically casts
  /// entities to the specified type. The proxy can then be later retrieved
  /// with [getTable].
  ///
  /// If the table does not exist in the database but [fields] is specified,
  /// the table will be automatically created. If the table does not exist
  /// and [fields] is not specified, an exception will be thrown.
  ///
  /// Throws a [StateError] if the table name is already registered.
  Future<CDBTable<T>> registerTable<T extends CDBEntity<T>>({
    String? table,
    required CBDDeserializerFunction<T> deserializer,
    List<CDBEntityField>? fields,
  }) async {
    // If table is not explicitly specified, use the down-cased typename.
    table ??= T.toString().toLowerCase();

    if (_tables.containsKey(table)) {
      throw StateError(
        "Attempted to re-register already registered $table table.",
      );
    }

    if (!await adapter.queryTable(table: table, fields: fields)) {
      throw StateError(
        fields != null
            ? "The $table table does not exist and it could not be created."
            : "The $table table does not exist (you can specify 'fields' to enable automatic table creation).",
      );
    }

    var registeredTable = CDBTable<T>(
      database: this,
      table: table,
      deserializer: deserializer,
      fields: fields,
    );

    _tables[table] = registeredTable;
    return registeredTable;
  }

  /// Fetches a registered table (with the specified name), throwing a
  /// [StateError] if it wasn't registered.
  ///
  /// (You should call [registerTable] with all tables you will use on
  /// initialization.)
  CDBTable<T> getTable<T extends CDBEntity<T>>({String? table}) {
    // If table is not explicitly specified, use the down-cased typename.
    table ??= T.toString().toLowerCase();

    if (!_tables.containsKey(table)) {
      throw StateError(
        "Attempted to load the $table table, but it was not registered.",
      );
    }

    return _tables[table] as CDBTable<T>;
  }

  /// Closes the connection to the database.
  Future<void> close() {
    return adapter.close();
  }
}

/// An API interface that ensures entities have the necessary fields and
/// (de)serialization methods for fluent usage with the database API.
abstract class CDBEntity<T> {
  bool get persisted => _id != null;

  String? _id;

  /// The entity's ID. The default for IDs is that they're represented as
  /// UUID (and therefore stored as a string).
  ///
  /// API developers: If this needs to be changed for certain models,
  /// this can be added as a generic parameter.
  String get id {
    if (_id != null) {
      return _id!;
    } else {
      throw StateError('Tried to get id from un-persisted entity.');
    }
  }

  /// Serializes the model into a map for query generation.
  /// If [withData] is specified, this data is also included in the object.
  Map<String, dynamic> serialize({Map<String, dynamic>? withData}) {
    return {
      if (persisted) 'id': id,
      if (withData != null) ...withData,
    };
  }

  /// Initializes the entity with the specified ID.
  CDBEntity({required String id}) : _id = id;

  /// Initializes the entity without an ID for creation.
  CDBEntity.create();

  /// The superclass template for deserialization. This automatically sets the
  /// ID from the data.
  CDBEntity.deserialize(Map<String, dynamic> object) : _id = object['id'];

  @override
  String toString() {
    return '${runtimeType.toString()}: ${serialize().toString()}';
  }

  @override
  bool operator ==(Object other) {
    if (other is CDBEntity<T> && persisted && other.persisted) {
      return _id == other._id;
    }

    return super == other;
  }

  @override
  int get hashCode {
    if (persisted) return _id.hashCode;
    return super.hashCode;
  }
}

/// Represents field options for table creation on a given entity.
/// Specifying these is optional, however it is obviously needed for automatic
/// table creation.
///
/// This can be used to interact with the database API at runtime only by
/// simply declaring a constant set of fields for a CDBEntity (usually, in the
/// class) – or – it can be used as part of a compile-time codegen pipeline.
class CDBEntityField {
  /// The name of the field.
  final String name;

  /// The field type.
  final Type type;

  /// Optionally, the length of the field.
  final int? length;

  /// Whether the field is nullable. (Default is true).
  final bool nullable;

  /// Whether or not a unique constraint should be applied to the field.
  final bool unique;

  /// Whether or not the field should be defined as a primary key. If this is
  /// true, any other constraints will be ignored.
  final bool primary;

  /// Whether or not the field should be autogenerated. This will be ignored
  /// for fields where the value cannot be autogenerated.
  final bool autogenerate;

  /// If specified, the default value of the field.
  /// This value will be ignored if [autogenerate] is set to true.
  final dynamic defaultValue;

  const CDBEntityField({
    required this.name,
    required this.type,
    this.length,
    this.nullable = true,
    this.unique = false,
    this.primary = false,
    this.autogenerate = false,
    this.defaultValue,
  });
}
