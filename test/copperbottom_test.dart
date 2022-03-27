import 'package:copperbottom/app/database/adapters/postgres.dart';
import 'package:copperbottom/app/database/database.dart';
import 'package:copperbottom/app/struct/user.dart';
import 'package:test/test.dart';

void main() {
  group('Database ORM', () {
    /// The database instance.
    late final CopperbottomDatabase database;

    /// The user's table.
    late final CDBTable<User> usersTable;

    /// A test user.
    late User user;

    setUpAll(() async {
      database = CopperbottomDatabase.fromAdapter(
        adapter: await CDBPostgresAdapter.connect(
          hostname: 'localhost',
          database: 'copperbottom_test',
          username: 'copperbottom_test',
          password: 'copperbottom',
        ),
      );

      await database.registerTable(
        deserializer: User.deserialize,
        fields: User.fields,
      );

      usersTable = database.getTable<User>();
    });

    test('Can purge table', () async {
      await usersTable.purge();
      expect(await usersTable.count(), equals(0));
    });

    test('Can create users', () async {
      user = User.create(username: 'test', password: 'test');
      expect(() => user.id, throwsStateError);
      expect(await usersTable.save(user), isA<User>());
      expect(user.id, allOf([isA<String>(), hasLength(36)]));

      var user2 = User.create(username: 'test2', password: 'test');
      expect(() => user2.id, throwsStateError);
      expect(await usersTable.save(user2), isA<User>());
      expect(user2.id, allOf([isA<String>(), hasLength(36)]));

      var user3 = User.create(username: 'test3', password: 'test');
      expect(() => user3.id, throwsStateError);
      expect(await usersTable.save(user3), isA<User>());
      expect(user3.id, allOf([isA<String>(), hasLength(36)]));

      expect(await usersTable.count(), equals(3));
    });

    test('Can execute delete where query', () async {
      await usersTable.where(
        'username = @username',
        parameters: {'username': 'test3'},
      ).deleteAll();

      expect(await usersTable.count(), equals(2));
    });

    test('Can execute select query', () async {
      var testSelect = await usersTable.whereColumn('username', user.username).select();
      expect(testSelect.toString(), equals('[${user.toString()}]'));
      expect(testSelect, equals([user]));
      expect(testSelect.first.username, equals('test'));
      expect(testSelect.length, equals(1));
    });

    test('Can count with where clause', () async {
      expect(await usersTable.whereColumn('username', 'test2').count(), equals(1));
    });

    test('Whole-table count is correct', () async {
      expect(await usersTable.count(), equals(2));
    });

    test('Can delete with where clause', () async {
      await usersTable.whereColumn('username', 'test2').deleteAll();
    });

    test('Can count with where clause (again)', () async {
      expect(
        await usersTable.whereColumn('username', 'test2').count(),
        equals(0),
      );
    });

    test('Whole-table count is correct (again)', () async {
      expect(await usersTable.count(), equals(1));
    });

    test('Can purge table (again)', () async {
      await usersTable.purge();
      expect(await usersTable.count(), equals(0));
    });

    tearDownAll(() async {
      await database.close();
    });
  });
}
