import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixelsheet/widgets/custom_app_bar.dart';
import 'package:pixelsheet/providers/providers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  String? _selectedModel;
  List<String> _availableModels = [];

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = ref.read(apiKeyProvider) ?? '';
    _selectedModel = ref.read(geminiModelProvider);
    _fetchAvailableModels().then((_) {
      if (_selectedModel == null && _availableModels.isNotEmpty) {
        _selectedModel = _availableModels.first;
        ref.read(geminiModelProvider.notifier).state = _selectedModel;
      }
    });
  }

  Future<void> _fetchAvailableModels() async {
    final apiKey = ref.read(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _availableModels = ['API Key not set'];
      });
      return;
    }

    const url = 'https://generativelanguage.googleapis.com/v1beta/models?key=';
    try {
      final response = await http.get(Uri.parse('$url$apiKey'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = (data['models'] as List)
            .map((model) => model['name'].toString())
            .where((name) => name.startsWith('models/gemini'))
            .toList();
        models.sort((a, b) => b.compareTo(a));

        setState(() {
          _availableModels = models;
        });
      } else {
        setState(() {
          _availableModels = ['Failed to load models'];
        });
      }
    } catch (e) {
      setState(() {
        _availableModels = ['Error: ${e.toString()}'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(geminiModelProvider, (previous, next) {
      if (next != null && _availableModels.contains(next)) {
        setState(() {
          _selectedModel = next;
        });
      }
    });

    return Scaffold(
      appBar: CustomAppBar(title: 'Settings'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                ref.read(apiKeyProvider.notifier).state = value;
                _fetchAvailableModels();
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              decoration: InputDecoration(
                labelText: 'Gemini Model',
                border: OutlineInputBorder(),
              ),
              items: _availableModels.map<DropdownMenuItem<String>>(
                    (String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                },
              ).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedModel = newValue;
                });
                if (newValue != null) {
                  ref.read(geminiModelProvider.notifier).state = newValue;
                }
              },
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(apiKeyProvider.notifier).state = _apiKeyController.text;
                if (_selectedModel != null) {
                  ref.read(geminiModelProvider.notifier).state = _selectedModel!;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Settings saved successfully.')));
              },
              child: Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }
}