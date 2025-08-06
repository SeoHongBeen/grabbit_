import 'package:grabbit_project/models/item.dart';

class RoutineManager {
  static final RoutineManager _instance = RoutineManager._internal();

  factory RoutineManager() => _instance;

  RoutineManager._internal();

  List<ChecklistItem> items = [];

  List<ChecklistItem> getItemsForDay(String day) {
    return items.where((item) => item.isRoutine && item.routineDays.contains(day)).toList();
  }

  void addRoutineItem(String name, String day) {
    final existing = items.where((e) => e.name == name && e.isRoutine).toList();
    if (existing.isNotEmpty) {
      for (var item in existing) {
        if (!item.routineDays.contains(day)) {
          item.routineDays.add(day);
        }
      }
    } else {
      items.add(ChecklistItem(
        name: name,
        isRoutine: true,
        routineDays: [day],
      ));
    }
  }

  void removeRoutineItem(String name, String day) {
    items.removeWhere((item) =>
    item.isRoutine &&
        item.name == name &&
        item.routineDays.length == 1 &&
        item.routineDays.contains(day));

    for (var item in items) {
      if (item.name == name && item.routineDays.contains(day)) {
        item.routineDays.remove(day);
      }
    }
  }
}