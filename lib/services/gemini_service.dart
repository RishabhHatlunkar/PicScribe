import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:jinja/jinja.dart';

class GeminiService {
  final Environment env = Environment();

  Future<String> extractTextFromImage(File imageFile, String apiKey) async {
    if (!isValidApiKey(apiKey)) {
      throw ArgumentError('Invalid API Key');
    }

    try {
      final model = GenerativeModel(model: 'gemini-2.0-flash-exp', apiKey: apiKey);

       // Load the template file
      final String prompt = await _loadTemplate('lib/templates/prompt.jinja2');

      final content = Content.multi([
        DataPart('image/jpeg', await imageFile.readAsBytes()),
        TextPart(prompt),
      ]);

      final response = await model.generateContent([content]).timeout(const Duration(seconds: 30));

      return response.text ?? 'No text found.';
    } catch (e) {
      print('Error in GeminiService: $e');
      if (e is GenerativeAIException) {
        if (e.message.contains("API key not valid")) {
          throw Exception("Invalid API Key. Please check your key.");
        }
        throw Exception('Gemini API Error: ${e.message}');
      } else if (e is TimeoutException) {
        throw Exception('Gemini API Timeout: Request took too long.');
      }
      else {
        throw Exception('Could not extract text: ${e.toString()}');
      }
    }
  }

  bool isValidApiKey(String apiKey) {
    return apiKey.isNotEmpty && apiKey.length > 30;
  }

   Future<String> _loadTemplate(String path) async {
     final String templateString = await rootBundle.loadString(path);
      return templateString;
  }
}