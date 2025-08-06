class RoutineItem {
  final String name;
  final String day;

  RoutineItem({required this.name, required this.day});

  Map<String, dynamic> toJson() => {
    'name': name,
    'day': day,
  };

  factory RoutineItem.fromJson(Map<String, dynamic> json) {
    return RoutineItem(
      name: json['name'],
      day: json['day'],
    );
  }
}