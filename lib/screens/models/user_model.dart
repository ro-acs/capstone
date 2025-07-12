class AppUser {
  final String uid;
  final String name;
  final String email;
  final String profileImageUrl;
  final String role; // 'client' or 'photographer'
  final bool isVerified;
  final bool isPaid;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.profileImageUrl,
    required this.role,
    this.isVerified = false,
    this.isPaid = false,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String documentId) {
    return AppUser(
      uid: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      role: data['role'] ?? 'client',
      isVerified: data['isVerified'] ?? false,
      isPaid: data['isPaid'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'role': role,
      'isVerified': isVerified,
      'isPaid': isPaid,
    };
  }
}
