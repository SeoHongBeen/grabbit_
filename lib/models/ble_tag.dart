class BleTag {
  String name;
  String uuid;

  BleTag({required this.name, required this.uuid});

  Map<String, dynamic> toJson() => {
    'name': name,
    'uuid': uuid,
  };

  factory BleTag.fromJson(Map<String, dynamic> json) {
    return BleTag(
      name: json['name'],
      uuid: json['uuid'],
    );
  }
}