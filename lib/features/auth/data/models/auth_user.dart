class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
  });
  final String id;
  final String name;
  final String email;
  final List<String> roles;

  factory AuthUser.fromLoginResponse(Map<String, dynamic> json) {
    final attributes = Map<String, dynamic>.from(
      json['attributes'] as Map? ?? const {},
    );
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: attributes['name']?.toString() ?? '',
      email: attributes['email']?.toString() ?? '',
      roles: (attributes['role'] as List? ?? const [])
          .map((role) => role.toString())
          .toList(),
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    roles: (json['roles'] as List? ?? const [])
        .map((role) => role.toString())
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'roles': roles,
  };
}
