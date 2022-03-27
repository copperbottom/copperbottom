import 'package:copperbottom/app/database/database.dart';
import 'package:postgres/postgres.dart';

/// A PostgreSQL adapter for Copperbottom's Application Database module.
/// You are not expected to interface with the adapter's API directly, rather
/// you would be expected to use the Copperbottom Database or Table API.
class CDBPostgresAdapter implements CDBAdapter {
  final PostgreSQLConnection _connection;

  /// Private constructor for a Copperbottom Database PostgreSQL adapter.
  /// This is private to allow for a static 'constructor' to ensure that a
  /// valid connection was made before returning the adapter.
  CDBPostgresAdapter._construct({required PostgreSQLConnection connection}) : _connection = connection;

  /// Initializes a Copperbottom Database PostgreSQL adapter and connects to
  /// the database with the specified credentials.
  static Future<CDBPostgresAdapter> connect({
    required String hostname,
    int port = 5432,
    required String database,
    required String username,
    required String password,
    bool useSSL = false,
  }) async {
    var adapter = CDBPostgresAdapter._construct(
      connection: PostgreSQLConnection(
        hostname,
        port,
        database,
        username: username,
        password: password,
        useSSL: useSSL,
      ),
    );

    await adapter._connection.open();
    await adapter._connection.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');
    return adapter;
  }

  @override
  Future<bool> queryTable({
    required String table,
    List<CDBEntityField>? fields,
  }) async {
    // We query whether the table exists separately to the create statement,
    // because if fields is not specified we can't create the table so we
    // should exit early.
    bool tableExists = ['true', 't'].contains((await _connection.query(
                "SELECT EXISTS ("
                "SELECT FROM pg_tables "
                "WHERE "
                "schemaname = 'public' AND "
                "tablename = @tableName"
                ");",
                substitutionValues: {
          'tableName': table,
        }))
            // SELECT EXISTS returns either true or false (or 't' or 'f'
            // apparently, depending on PostgreSQL configuration, so we get the
            // first column of the first row to retrieve this value and check
            // if it matches 't' or 'true'.
            [0][0]
        .toString()
        .toLowerCase());

    // If the table exists, (or if it doesn't but fields isn't specified), we
    // can exit early.
    if (tableExists) return true;
    if (!tableExists && fields == null) return false;

    // Otherwise, we'll attempt to create the table.
    try {
      final columns = fields!
          .map((field) {
            String type = (() {
              switch (field.type) {
                case UUID:
                  if (field.autogenerate) return 'UUID DEFAULT uuid_generate_v4()';
                  return 'UUID';
                case bool:
                  return 'BOOLEAN';
                case int:
                  if (field.autogenerate) return 'SERIAL';
                  return 'INTEGER';
                case String:
                  return field.length != null ? 'VARCHAR(${field.length})' : 'TEXT';
                case List:
                  return 'ARRAY';
                case DateTime:
                  if (field.autogenerate) return "TIMESTAMP WITHOUT TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')";
                  return 'TIMESTAMP WITHOUT TIME ZONE';
                default:
                  throw ArgumentError('Unknown column type in table $table for field ${field.name}: ${field.type.toString()}');
              }
            })();

            String constraints = ' ' +
                [
                  field.unique ? 'UNIQUE' : null,
                  field.nullable ? null : 'NOT NULL',
                ].where((constraint) => constraint?.isNotEmpty ?? false).join(' ');
            if (field.primary) constraints = ' PRIMARY KEY';
            if (field.defaultValue != null && !field.autogenerate) {
              constraints += ' DEFAULT ${field.defaultValue}';
            }

            return '"${field.name}" $type$constraints';
          })
          .join(', ')
          .trim();

      await _connection.transaction((ctx) async {
        await ctx.query('CREATE TABLE "$table" ($columns);');
      });
      return true;
    } catch (ex) {
      print(ex);
      return false;
    }
  }

  @override
  Future<T?> getById<T extends CDBEntity<T>>({
    required String table,
    required String id,
    required CBDDeserializerFunction<T> deserializer,
  }) async {
    var result = await _connection.mappedResultsQuery(
      'SELECT * FROM "$table" WHERE id = @id',
      substitutionValues: {'id': id},
    );
    if (result.isEmpty) return null;

    var data = result[0][table];
    if (data == null) return null;

    return deserializer(data);
  }

  @override
  CDBQueryBuilder<T> where<T extends CDBEntity<T>>(CDBTable<T> table, String condition, {Map<String, dynamic>? parameters}) {
    return CDBPostgresAdapterQueryBuilder<T>(table, condition, parameters);
  }

  @override
  CDBQueryBuilder<T> whereColumn<T extends CDBEntity<T>>(CDBTable<T> table, String column, dynamic value) {
    return CDBPostgresAdapterQueryBuilder<T>(
      table,
      '"$column" = @$column',
      {column: value},
    );
  }

  @override
  Future<void> deleteById({
    required String table,
    required String id,
  }) async {
    await _connection.query(
      'DELETE FROM "$table" WHERE id = @id',
      substitutionValues: {'id': id},
    );
  }

  @override
  Future<void> delete<T extends CDBEntity<T>>({
    required String table,
    required T entity,
  }) async {
    await _connection.query(
      'DELETE FROM "$table" WHERE id = @id',
      substitutionValues: {'id': entity.id},
    );
  }

  @override
  Future<String> save<T extends CDBEntity<T>>({
    required String table,
    required T entity,
  }) async {
    var data = entity.serialize();
    var keys = data.keys.toList();

    try {
      var result = await _connection.transaction((ctx) async {
        if (entity.persisted) {
          return await ctx.query(
            'UPDATE "$table" '
            'SET ${keys.where((key) => key != 'id').map((key) => '"$key" = @$key').join(', ')} '
            'WHERE id = @id '
            'RETURNING id',
            substitutionValues: data,
          );
        } else {
          return await ctx.query(
            'INSERT INTO "$table" (${keys.map((key) => '"$key"').join(', ')}) '
            'VALUES(${keys.map((key) => '@$key').join(', ')}) '
            'RETURNING id',
            substitutionValues: data,
          );
        }
      });

      // Return the first column of the first row of the result, which will be
      // the id of the created entity.
      return result[0][0];
    } catch (ex) {
      rethrow;
    }
  }

  @override
  Future<int> count({required String table}) async {
    final result = await _connection.query('SELECT COUNT(*) FROM "$table"');
    return result[0][0];
  }

  @override
  Future<void> truncate({required String table, bool cascade = true}) async {
    await _connection.query('TRUNCATE "$table"' + (cascade ? ' CASCADE' : ''));
  }

  @override
  Future<void> close() async {
    await _connection.close();
  }
}

class CDBPostgresAdapterQueryBuilder<T extends CDBEntity<T>> extends CDBQueryBuilder<T> {
  /// The list of conditions to be applied.
  final List<String> _whereConditions;

  /// The list of ordering to be applied.
  final List<String> _ordering;

  /// The list of parameters to inject.
  final Map<String, dynamic> _parameters;

  CDBPostgresAdapterQueryBuilder(
    CDBTable<T> table,
    String condition,
    Map<String, dynamic>? parameters,
  )   : _whereConditions = [condition],
        _ordering = [],
        _parameters = parameters ?? {},
        super(table);

  @override
  CDBQueryBuilder where(String condition, {Map<String, dynamic>? parameters}) {
    _whereConditions.add(condition);

    // If the parameters are set, check that there are no conflicting values.
    if (parameters != null) {
      var duplicateKeys = parameters.keys.where(
        (key) => _parameters.containsKey(key),
      );

      if (duplicateKeys.isNotEmpty) {
        throw ArgumentError(
          "Conflicting query parameter(s) specified: ${duplicateKeys.toString()}.",
        );
      }

      // ...and if there aren't any, add them all to the internal parameters
      // map.
      _parameters.addAll(parameters);
    }

    return this;
  }

  @override
  CDBQueryBuilder whereColumn(String column, dynamic value) {
    return where('"$column" = @$column', parameters: {column: value});
  }

  @override
  CDBQueryBuilder orderBy(String column, {bool descending = false}) {
    _ordering.add('"$column" ${descending ? 'DESC' : 'ASC'}');
    return this;
  }

  @override
  Future<int> count() async {
    final adapter = table.database.adapter as CDBPostgresAdapter;
    final result = await adapter._connection.query(
      'SELECT COUNT(*) FROM "${table.table}" '
              'WHERE ${_whereConditions.join(',')}' +
          (_ordering.isNotEmpty ? ' ORDER BY ${_ordering.join(', ')}' : ''),
      substitutionValues: _parameters,
    );

    return result[0][0];
  }

  @override
  Future<List<T>> select({List<String>? columns, limit = 20}) async {
    final columnsString = columns != null && columns.isNotEmpty ? columns.join(', ') : '*';

    final adapter = table.database.adapter as CDBPostgresAdapter;
    final result = await adapter._connection.mappedResultsQuery(
      'SELECT $columnsString FROM "${table.table}" '
              'WHERE ${_whereConditions.join(',')}' +
          (_ordering.isNotEmpty ? ' ORDER BY ${_ordering.join(', ')}' : '') +
          ' LIMIT $limit',
      substitutionValues: _parameters,
    );

    return result.map((entry) => table.deserializer(entry[table.table]!)).toList().cast<T>();
  }

  @override
  Future<void> deleteAll() async {
    final adapter = table.database.adapter as CDBPostgresAdapter;
    await adapter._connection.transaction((ctx) {
      return ctx.query(
        'DELETE FROM "${table.table}" '
        'WHERE ${_whereConditions.join(',')}',
        substitutionValues: _parameters,
      );
    });
  }
}
