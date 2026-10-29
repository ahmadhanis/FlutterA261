class UserModel {
  const UserModel({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}
