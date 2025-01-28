import 'dart:io';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pixelsheet/services/gemini_service.dart';
import 'package:pixelsheet/services/database_service.dart';
import 'package:pixelsheet/models/conversion_item.dart';

// API Key Provider
final apiKeyProvider = StateNotifierProvider<ApiKeyNotifier, AsyncValue<String?>>((ref) {
  return ApiKeyNotifier();
});

class ApiKeyNotifier extends StateNotifier<AsyncValue<String?>> {
  final _hiveBox = Hive.box('settings');
  bool isLoading = true;

  ApiKeyNotifier() : super(const AsyncValue.loading()) {
    print('ApiKeyNotifier: Constructor called, loading key.');
    _loadApiKey();
  }

  // Load API Key from Hive
  Future<void> _loadApiKey() async {
    try {
      print('ApiKeyNotifier: Attempting to load API key from Hive.');
      final apiKey = _hiveBox.get('apiKey') as String?;
      print('ApiKeyNotifier: API key from Hive: $apiKey');
      state = AsyncValue.data(apiKey);
    } catch(e) {
      print('ApiKeyNotifier: Error loading API key from Hive: $e');
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      print('ApiKeyNotifier: Loading API key operation complete.');
      isLoading = false;
    }
  }

  // Save API Key to Hive
  Future<void> saveApiKey(String? apiKey) async {
    print('ApiKeyNotifier: Saving API key to Hive: $apiKey');
    if (apiKey != null && apiKey.isNotEmpty) {
      await _hiveBox.put('apiKey', apiKey);
    } else {
      await _hiveBox.delete('apiKey');
    }
    state = AsyncValue.data(apiKey);
    print('ApiKeyNotifier: API key saved to Hive, state updated.');
  }
}

// Images Provider (List of XFile)
final imagesProvider = StateProvider<List<XFile>>((ref) => []);

// Extracted Text Provider (List of String)
final extractedTextProvider = StateProvider<List<String>>((ref) => []);

// Loading State Provider
final loadingStateProvider = StateProvider<bool>((ref) => false);

// Gemini Service Provider
final geminiServiceProvider = Provider<GeminiService>((ref) {
  final apiKeyAsync = ref.watch(apiKeyProvider);
  final modelName = ref.watch(geminiModelProvider);
  final apiKey = apiKeyAsync.valueOrNull;


  if (apiKey == null || apiKey.isEmpty) {
    return GeminiService('', modelName); // Return a GeminiService with an empty API key
  }
  return GeminiService(apiKey, modelName);
});

// Database Service Provider
final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());

final geminiModelProvider = StateProvider<String?>((ref) => null);

final parsedDataProvider = StateProvider<List<dynamic>>((ref) => []);

// Async Function to Extract Text from Image
final extractTextProvider = FutureProvider.family<List, File>((ref, imageFile) async {
  final apiKeyAsync = ref.watch(apiKeyProvider);
  final geminiService = ref.read(geminiServiceProvider);
  final instruction = ref.read(extractedTextProvider.notifier).state.isEmpty ? "" : ref.read(extractedTextProvider.notifier).state.first;
  final apiKey = apiKeyAsync.valueOrNull;
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception('API Key is required.');
  }
  return geminiService.extractTextFromImage(imageFile as XFile,instruction); // Passing both instruction and XFile
});

// Async Function to Save Conversion to Database
final saveConversionProvider = FutureProvider.family<int, ConversionItem>((ref, item) async {
  final databaseService = ref.read(databaseServiceProvider);
  return databaseService.insertConversion(item);
});

final csvSaveProvider = FutureProvider.family<void, List>((ref, data) async {
  try {
    String directory = data[1];
    // Generating a unique file name based on current timestamp
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String fileName = 'table_data_$timestamp.csv';

    print('$directory/$fileName');
    // Creating the file and writing CSV data
    final File file = File('$directory/$fileName');

    if (!file.existsSync()) {
      await file.create(recursive: true);
    }

    await file.writeAsString(data[0]);

    // Converting the CSV string to bytes for saving
    final Uint8List bytes = Uint8List.fromList(data[0].codeUnits);

    // Saving the file using file_saver
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );
  } catch (e) {
    throw Exception('Failed to save CSV file: $e');
  }
});