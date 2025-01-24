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
final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());

// Database Service Provider
final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());

// Async Function to Extract Text from Image
final extractTextProvider = FutureProvider.family<String, File>((ref, imageFile) async {
  final apiKey = ref.watch(apiKeyProvider);
  final geminiService = ref.read(geminiServiceProvider);

  if (apiKey == null || apiKey.isEmpty) {
    throw Exception('API Key is required.');
  }

  return geminiService.extractTextFromImage(imageFile, apiKey);
});

// Async Function to Save Conversion to Database
final saveConversionProvider = FutureProvider.family<int, ConversionItem>((ref, item) async {
    final databaseService = ref.read(databaseServiceProvider);
    return databaseService.insertConversion(item);
});