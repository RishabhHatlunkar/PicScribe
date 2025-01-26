import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pixelsheet/services/gemini_service.dart';
import 'package:pixelsheet/services/database_service.dart';
import 'package:pixelsheet/models/conversion_item.dart';

// API Key Provider
final apiKeyProvider = StateProvider<String?>((ref) => null);

// Images Provider (List of XFile)
final imagesProvider = StateProvider<List<XFile>>((ref) => []);

// Extracted Text Provider (List of String)
final extractedTextProvider = StateProvider<List<String>>((ref) => []);

// Loading State Provider
final loadingStateProvider = StateProvider<bool>((ref) => false);

// Gemini Service Provider
// Gemini Service Provider
final geminiServiceProvider = Provider<GeminiService>((ref) {
    final apiKey = ref.watch(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
        return GeminiService(''); // Return a GeminiService with an empty API key
    }
    return GeminiService(apiKey);
});


// Database Service Provider
final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());

final geminiModelProvider = StateProvider<String?>((ref) => null);

final parsedDataProvider = StateProvider<List<dynamic>>((ref) => []);

// Async Function to Extract Text from Image
final extractTextProvider = FutureProvider.family<List, File>((ref, imageFile) async {
    final apiKey = ref.watch(apiKeyProvider);
    final geminiService = ref.read(geminiServiceProvider);
    final instruction = ref.read(extractedTextProvider.notifier).state.isEmpty ? "" : ref.read(extractedTextProvider.notifier).state.first;

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