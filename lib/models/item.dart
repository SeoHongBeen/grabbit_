class ChecklistItem {
  String name;
  bool isChecked;
  bool isBleDetected;
  bool isRoutine;
  bool isSuggested;
  List<String> routineDays;

  // 🔽 추가: BLE UUID
  String? bleUuid;

  ChecklistItem({
    required this.name,
    this.isChecked = false,
    this.isBleDetected = false,
    this.isRoutine = false,
    this.isSuggested = false,
    this.routineDays = const [],
    this.bleUuid, // 🔽 생성자에 추가
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isChecked': isChecked,
      'isBleDetected': isBleDetected,
      'isRoutine': isRoutine,
      'isSuggested': isSuggested,
      'routineDays': routineDays,
      'bleUuid': bleUuid, // 🔽 저장용
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
      bleUuid: json['bleUuid'] as String?, // 🔽 불러오기
    );
  }
}