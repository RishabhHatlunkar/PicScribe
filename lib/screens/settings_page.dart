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
    print('SettingsPage: initState called.');
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    print('SettingsPage: _initializeSettings called.');
    final apiKeyAsync = ref.read(apiKeyProvider);
    final apiKey = apiKeyAsync.valueOrNull;
    print('SettingsPage: _initializeSettings, apiKey from provider: $apiKey');
    _apiKeyController.text = apiKey ?? '';
    _selectedModel = ref.read(geminiModelProvider);
    if(apiKey != null){
      print('SettingsPage: _initializeSettings, API key is not null, fetching models.');
      await _fetchAvailableModels();
    }else{
      print('SettingsPage: _initializeSettings, API key is null, skipping fetch models.');
    }
  }

  Future<void> _fetchAvailableModels() async {
    print('SettingsPage: _fetchAvailableModels called.');
    setState(() {
      _isLoading = true;
      _availableModels = [];
      print('SettingsPage: _fetchAvailableModels, setting loading state to true.');
    });
    final apiKeyAsync = ref.read(apiKeyProvider);
    final apiKey = apiKeyAsync.valueOrNull;
    print('SettingsPage: _fetchAvailableModels, apiKey from provider: $apiKey');
    if (apiKey == null || apiKey.isEmpty) {
      print('SettingsPage: _fetchAvailableModels, API Key is null or empty.');
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _availableModels = ['API Key not set'];
        _isLoading = false;
        _selectedModel = null;
        ref.read(geminiModelProvider.notifier).state = null;
        print('SettingsPage: _fetchAvailableModels, setting models to default because apiKey is not set.');
      });
      return;
    }


    const url = 'https://generativelanguage.googleapis.com/v1beta/models?key=';
    try {
      final response = await http.get(Uri.parse('$url$apiKey'));
      if (response.statusCode == 200) {
        print('SettingsPage: _fetchAvailableModels, API call successful, parsing models.');
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
          print('SettingsPage: _fetchAvailableModels, models loaded and updating state.');
          _availableModels = models;
          _isLoading = false;
          if (_selectedModel == null ||
              !_availableModels.contains(_selectedModel)) {
            _selectedModel = defaultModel;
            ref.read(geminiModelProvider.notifier).state = _selectedModel;
          }
        });
      } else {
        print('SettingsPage: _fetchAvailableModels, API call failed.');
        if (!mounted) return; // Check if the widget is still mounted
        setState(() {
          _availableModels = ['Failed to load models'];
          _isLoading = false;
          _selectedModel = null;
          ref.read(geminiModelProvider.notifier).state = null;
          print('SettingsPage: _fetchAvailableModels, setting default models due to api failure.');
        });
      }
    } catch (e) {
      print('SettingsPage: _fetchAvailableModels, Exception thrown: $e.');
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _availableModels = ['Error: ${e.toString()}'];
        _isLoading = false;
        _selectedModel = null;
        ref.read(geminiModelProvider.notifier).state = null;
        print('SettingsPage: _fetchAvailableModels, setting default models due to exception.');
      });
    }
  }
@override
  Widget build(BuildContext context) {
   print('SettingsPage: build method called.');
    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(
        title: 'Settings',
      ),
      body: IgnorePointer(
        ignoring: _isLoading,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer(builder: (context, ref, child) {
                    final apiKeyAsync = ref.watch(apiKeyProvider);
                    return apiKeyAsync.when(
                      data: (apiKey) {
                        return TextField(
                          controller: _apiKeyController,
                          obscureText: !_isApiKeyVisible,
                          cursorColor: Colors.blue,
                          style: const TextStyle(
                              color: Color.fromARGB(255, 60, 60, 60)),
                          decoration: InputDecoration(
                            labelText: 'Gemini API Key',
                            labelStyle: const TextStyle(
                              color: Color.fromARGB(255, 60, 60, 60),
                            ),
                            border: const OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Color.fromARGB(255, 0, 0, 0))),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isApiKeyVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isApiKeyVisible = !_isApiKeyVisible;
                                });
                              },
                            ),
                          ),
                          onChanged: (value) async {
                            await ref
                                .read(apiKeyProvider.notifier)
                                .saveApiKey(value);
                            _fetchAvailableModels();
                          },
                        );
                      },
                      error: (error, stacktrace) => Text(
                        'Error loading API Key: ${error.toString()}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      loading: () => const Text(
                        'Loading API Key...',
                        style: TextStyle(color: Colors.blue),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedModel,
                    decoration: const InputDecoration(
                      labelText: 'Gemini Model',
                      labelStyle: TextStyle(
                        color: Color.fromARGB(255, 60, 60, 60),
                      ),
                      border: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromARGB(255, 0, 0, 0))),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                    items: _availableModels
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value,
                            style: const TextStyle(color: Colors.blue)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        ref.read(geminiModelProvider.notifier).state =
                            newValue;
                        setState(() {
                          _selectedModel = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        print('SettingsPage: Save settings button tapped.');
                        await ref
                            .read(apiKeyProvider.notifier)
                            .saveApiKey(_apiKeyController.text);
                        if (_selectedModel != null) {
                          ref.read(geminiModelProvider.notifier).state =
                              _selectedModel!;
                        }
                        _showSnackBar('Settings saved successfully.');
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Want to know who am I?',
                     style: TextStyle(
                       fontWeight: FontWeight.w500,
                       color: Colors.black87
                     ),),
                     ElevatedButton(
                       onPressed: () {
                         Navigator.push(context,
                             MaterialPageRoute(builder: (context) => const AboutUsPage()));
                       },
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.white,
                             foregroundColor: Colors.blue,
                           elevation: 2,
                           shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(8)
                           )
                         ),
                       child: const Text('About Us',),

                     )
                  ],
                ),
              )
            ),
            if (_isLoading) Center(child: LoadingIndicator())
          ],
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

class AboutUsPage extends ConsumerStatefulWidget {
  const AboutUsPage({super.key});
  @override
  ConsumerState<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends ConsumerState<AboutUsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'About Picscrabe',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Picscrabe',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 16),
              Text(
                'Picscrabe is a mobile application developed to streamline the process of extracting text from images. We understand the challenges of manually typing information from photos, so we created a powerful tool that does it for you quickly and accurately.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 16),
              Text(
                'Key Features:',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '* Easy image selection from gallery or camera',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '* Fast and accurate text extraction',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '* Options to save extracted text as CSV',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '* Intuitive and user-friendly design',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Our goal is to provide a seamless experience, making information extraction effortless and convenient for everyone.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Developed by Rishabh Hatlnkar and Atharva Jagtap.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}