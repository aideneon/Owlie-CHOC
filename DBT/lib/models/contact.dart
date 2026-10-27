class SupportContact {
  const SupportContact({
    required this.name,
    required this.phoneNumber,
  });

  final String name;
  final String phoneNumber;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phoneNumber': phoneNumber,
      };

  factory SupportContact.fromJson(Map<String, dynamic> json) {
    return SupportContact(
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
    );
  }

  SupportContact copyWith({String? name, String? phoneNumber}) {
    return SupportContact(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
