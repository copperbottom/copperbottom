import 'package:copperbottom/app/database/database.dart';

class User extends CDBEntity<User> {
  /// Field options for automatic table creation. (Runtime-only API)
  static const List<CDBEntityField> fields = [
    CDBEntityField(name: 'id', type: UUID, primary: true, autogenerate: true, nullable: false),
    CDBEntityField(name: 'username', type: String, length: 64, unique: true, nullable: false),
    CDBEntityField(name: 'password', type: String, length: 512, nullable: false),
    CDBEntityField(name: 'createdAt', type: DateTime, autogenerate: true, nullable: false),
  ];

  /// The user's system name. This is the name that e-mails will be addressed
  /// to and the name they will use to authenticate to the system with.
  String username;

  /// The user's (hashed) password.
  String password;

  /// The date-time that the user was created.
  final DateTime createdAt;

  User({
    required String id,
    required this.username,
    required this.password,
    required this.createdAt,
  }) : super(id: id);

  @override
  User.create({
    required this.username,
    required this.password,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        super.create();

  @override
  Map<String, dynamic> serialize({Map<String, dynamic>? withData}) {
    return super.serialize(withData: {
      'username': username,
      'password': password,
      'createdAt': createdAt,
      if (withData != null) ...withData,
    });
  }

  @override
  User.deserialize(Map<String, dynamic> object)
      : username = object['username'],
        password = object['password'],
        createdAt = object['createdAt'],
        super.deserialize(object);
}
