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
                // Extract version parts from both strings
               final aVersion = a.split('/').last;
               final bVersion = b.split('/').last;


              // Split string by hyphen
               final aParts = aVersion.split('-');
                final bParts = bVersion.split('-');


               // Compare by comparing numeric components if available
               for (int i = 0; i < aParts.length && i < bParts.length; i++) {
                   // Check if the parts are numbers
                   if (int.tryParse(aParts[i]) != null && int.tryParse(bParts[i]) != null) {
                       final int aNum = int.parse(aParts[i]);
                        final int bNum = int.parse(bParts[i]);
                      // Compare numerical components
                      if (aNum != bNum) {
                          return bNum.compareTo(aNum); // If difference is found compare by numerical values in descending order
                      }
                    }
                     else {
                    // Compare String components for alphabets
                     final int strCompare = bParts[i].compareTo(aParts[i]);
                      if(strCompare != 0) return strCompare;
                 }
             }
                // Compare by length of the string
                  return bVersion.length.compareTo(aVersion.length);

              });
            String? defaultModel;
         if (models.contains('models/gemini-2.0-flash-exp')){
                defaultModel = 'models/gemini-2.0-flash-exp';
             }
            else if (models.isNotEmpty){
            defaultModel = models.first;

          }

        setState(() {
          _availableModels = models;
           _isLoading = false;
           if(_selectedModel == null || !_availableModels.contains(_selectedModel))
           {
             if(defaultModel != null)
               {
                 _selectedModel = defaultModel;
                  ref.read(geminiModelProvider.notifier).state = _selectedModel;
               }else {
                  _selectedModel = null;
                   ref.read(geminiModelProvider.notifier).state = null;
                }
           }
        });

      } else {
        setState(() {
          _availableModels = ['Failed to load models'];
          _isLoading = false;
           _selectedModel = null;
            ref.read(geminiModelProvider.notifier).state = null;
        });
      }
    } catch (e) {
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
                child: Stack(
                  children: [
                   Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         TextField(
                           controller: _apiKeyController,
                          decoration: const InputDecoration(
                           labelText: 'Gemini API Key',
                              border: OutlineInputBorder(),
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
                              ref.read(apiKeyProvider.notifier).state = _apiKeyController.text;
                             if (_selectedModel != null) {
                                ref.read(geminiModelProvider.notifier).state = _selectedModel!;
                             }
                           _showSnackBar('Settings saved successfully.');
                        },
                         child: const Text('Save Settings'),
                        ),
                   ],
                 ),
             if (_isLoading) Center(child: LoadingIndicator())
            ]
          ),
         ),
      ),
    );
  }
   void _showSnackBar(String message) {
      if(_scaffoldKey.currentContext == null) return;
       ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
             content: Text(message, style: const TextStyle(color: Colors.blue),)));
    }
}