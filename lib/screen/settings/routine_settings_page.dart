import 'package:flutter/material.dart';
import 'package:grabbit_project/service/routine_manager.dart';

class RoutineSettingsPage extends StatefulWidget {
  const RoutineSettingsPage({super.key});

  @override
  State<RoutineSettingsPage> createState() => _RoutineSettingsPageState();
}

class _RoutineSettingsPageState extends State<RoutineSettingsPage> {
  String _selectedDay = '월';
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final routineManager = RoutineManager();
    final items = routineManager.getItemsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(title: const Text('요일별 루틴 설정')),
      body: Column(
        children: [
          _buildDaySelector(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '루틴 물건 입력',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isNotEmpty) {
                      routineManager.addRoutineItem(text, _selectedDay);
                      _controller.clear();
                      setState(() {});
                    }
                  },
                  child: const Text('추가'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      routineManager.removeRoutineItem(item.name, _selectedDay);
                      setState(() {});
                    },
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        children: days.map((day) {
          final isSelected = day == _selectedDay;
          return ChoiceChip(
            label: Text(day),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedDay = day),
            selectedColor: Colors.green,
          );
        }).toList(),
      ),
    );
  }
}