import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixelsheet/widgets/custom_app_bar.dart';
import 'package:pixelsheet/providers/providers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pixelsheet/widgets/loading_indicator.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  String? _selectedModel;
  List<String> _availableModels = [];
  bool _isLoading = false;
  bool _isApiKeyVisible = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = ref.read(apiKeyProvider) ?? '';
    _selectedModel = ref.read(geminiModelProvider);
    _fetchAvailableModels();
  }

  Future<void> _fetchAvailableModels() async {
    setState(() {
      _isLoading = true;
      _availableModels = [];
    });
    final apiKey = ref.read(apiKeyProvider);

    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _availableModels = ['API Key not set'];
        _isLoading = false;
        _selectedModel = null;
        ref.read(geminiModelProvider.notifier).state = null;
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

        models.sort((a, b) {
          final aVersion = a.split('/').last;
          final bVersion = b.split('/').last;

          final aParts = aVersion.split('-');
          final bParts = bVersion.split('-');

          for (int i = 0; i < aParts.length && i < bParts.length; i++) {
            if (int.tryParse(aParts[i]) != null &&
                int.tryParse(bParts[i]) != null) {
              final int aNum = int.parse(aParts[i]);
              final int bNum = int.parse(bParts[i]);
              if (aNum != bNum) {
                return bNum.compareTo(aNum);
              }
            } else {
              final int strCompare = bParts[i].compareTo(aParts[i]);
              if (strCompare != 0) return strCompare;
            }
          }
          return bVersion.length.compareTo(aVersion.length);
        });

        String? defaultModel;
        if (models.contains('models/gemini-2.0-flash-exp')) {
          defaultModel = 'models/gemini-2.0-flash-exp';
        } else if (models.isNotEmpty) {
          defaultModel = models.first;
        }

        if (!mounted) return; // Check if the widget is still mounted
        setState(() {
          _availableModels = models;
          _isLoading = false;
          if (_selectedModel == null ||
              !_availableModels.contains(_selectedModel)) {
            _selectedModel = defaultModel;
            ref.read(geminiModelProvider.notifier).state = _selectedModel;
          }
        });
      } else {
        if (!mounted) return; // Check if the widget is still mounted
        setState(() {
          _availableModels = ['Failed to load models'];
          _isLoading = false;
          _selectedModel = null;
          ref.read(geminiModelProvider.notifier).state = null;
        });
      }
    } catch (e) {
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _availableModels = ['Error: ${e.toString()}'];
        _isLoading = false;
        _selectedModel = null;
        ref.read(geminiModelProvider.notifier).state = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(title: 'Settings'),
      body: IgnorePointer(
        ignoring: _isLoading,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _apiKeyController,
                  obscureText: !_isApiKeyVisible,
                  decoration: InputDecoration(
                    labelText: 'Gemini API Key',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isApiKeyVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isApiKeyVisible = !_isApiKeyVisible; // Toggle state
                        });
                      },
                    ),
                  ),
                  onChanged: (value) {
                    ref.read(apiKeyProvider.notifier).state = value;
                    _fetchAvailableModels();
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedModel,
                  decoration: const InputDecoration(
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
                    if (newValue != null) {
                      ref.read(geminiModelProvider.notifier).state = newValue;
                    }
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(apiKeyProvider.notifier).state =
                        _apiKeyController.text;
                    if (_selectedModel != null) {
                      ref.read(geminiModelProvider.notifier).state =
                          _selectedModel!;
                    }
                    _showSnackBar('Settings saved successfully.');
                  },
                  child: const Text('Save Settings'),
                ),
              ],
            ),
            if (_isLoading) Center(child: LoadingIndicator())
          ]),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (_scaffoldKey.currentContext == null) return;
    ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
        content: Text(
      message,
      style: const TextStyle(color: Colors.blue),
    )));
  }
}
