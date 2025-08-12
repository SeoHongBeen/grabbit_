import 'package:flutter/material.dart';
import 'package:grabbit_project/utils/shared_preferences_helper.dart';
import 'package:grabbit_project/models/ble_tag.dart';

class BleSettingsPage extends StatefulWidget {
  const BleSettingsPage({super.key});

  @override
  State<BleSettingsPage> createState() => _BleSettingsPageState();
}

class _BleSettingsPageState extends State<BleSettingsPage> {
  final List<BleTag> _bleTags = [];

  final _nameController = TextEditingController();
  final _uuidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  void _loadTags() async {
    final tags = await SharedPreferencesHelper.loadBleTags();
    setState(() {
      _bleTags.addAll(tags);
    });
  }

  void _saveTags() {
    SharedPreferencesHelper.saveBleTags(_bleTags);
  }

  void _addTag() {
    final name = _nameController.text.trim();
    final uuid = _uuidController.text.trim().toLowerCase();

    if (name.isNotEmpty && uuid.isNotEmpty) {
      setState(() {
        _bleTags.add(BleTag(name: name, uuid: uuid));
        _nameController.clear();
        _uuidController.clear();
        _saveTags(); //저장
      });
    }
  }

  void _deleteTag(BleTag tag) {
    setState(() {
      _bleTags.remove(tag);
      _saveTags(); //저장
    });
  }

  void _editTag(BleTag tag, String newName) {
    setState(() {
      tag.name = newName;
      _saveTags(); //저장
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE 태그 설정')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '장치 이름'),
                ),
                TextField(
                  controller: _uuidController,
                  decoration: const InputDecoration(labelText: 'UUID'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _addTag,
                  child: const Text('BLE 태그 추가'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _bleTags.length,
              itemBuilder: (context, index) {
                final tag = _bleTags[index];
                final controller = TextEditingController(text: tag.name);

                return ListTile(
                  title: TextField(
                    controller: controller,
                    onSubmitted: (value) => _editTag(tag, value.trim()),
                  ),
                  subtitle: Text(tag.uuid),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTag(tag),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
