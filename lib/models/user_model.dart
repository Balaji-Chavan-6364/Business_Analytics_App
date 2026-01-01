class UserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String mobileNumber;
  final String businessName;
  final String profileImageUrl;

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.mobileNumber,
    required this.businessName,
    this.profileImageUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'mobileNumber': mobileNumber,
      'businessName': businessName,
      'profileImageUrl': profileImageUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      businessName: map['businessName'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
    );
  }
}
