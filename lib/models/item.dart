class ChecklistItem {
  String name;
  bool isChecked;
  bool isBleDetected;
  bool isRoutine;
  bool isSuggested;
  List<String> routineDays;

  String? bleUuid;

  ChecklistItem({
    required this.name,
    this.isChecked = false,
    this.isBleDetected = false,
    this.isRoutine = false,
    this.isSuggested = false,
    this.routineDays = const [],
    this.bleUuid,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isChecked': isChecked,
      'isBleDetected': isBleDetected,
      'isRoutine': isRoutine,
      'isSuggested': isSuggested,
      'routineDays': routineDays,
      'bleUuid': bleUuid,
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      name: json['name'] as String,
      isChecked: json['isChecked'] as bool? ?? false,
      isBleDetected: json['isBleDetected'] as bool? ?? false,
      isRoutine: json['isRoutine'] as bool? ?? false,
      isSuggested: json['isSuggested'] as bool? ?? false,
      routineDays: (json['routineDays'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
      bleUuid: json['bleUuid'] as String?,
    );
  }
}
