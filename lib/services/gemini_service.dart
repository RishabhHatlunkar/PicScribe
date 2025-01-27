import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:jinja/jinja.dart' as jj;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pixelsheet/providers/providers.dart';

class GeminiService {
  final String apiKey;

  GeminiService(this.apiKey);

  // Function to parse the Gemini API response
  List<dynamic> parseGeminiResponse(String rawString) {
    // Regular expression to extract the Type and the content within the triple backticks
    final RegExp regex = RegExp(
        r"\s*Type:\s*(Table|Text)\s*\n+```(?:csv|markdown)?\n([\s\S]*?)```\s*",
        caseSensitive: false);

    final Match? match = regex.firstMatch(rawString);

    if (match != null) {
      final String type = match.group(1)!.trim();
      final String content = match.group(2)!.trim();
         return [type, content];
    } else {
        return ["Error", "Could not parse response.\n" + rawString];
    }
  }

  Future<String> _loadTemplate(String templatePath) async {
    return await rootBundle.loadString(templatePath);
  }

  Future<List<dynamic>> extractTextFromImage(XFile imageFile, String instruction) async {
     try {
      final model = GenerativeModel(model: 'gemini-2.0-flash-exp', apiKey: apiKey);
       final promptTemplate = await _loadTemplate('lib/templates/prompt.jinja2');
      final template = jj.Template(promptTemplate);
      final prompt = template.render({'api_key': apiKey,'instruction': instruction});
       final content = Content.multi([
         DataPart('image/jpeg', await imageFile.readAsBytes()),
         TextPart(prompt),
       ]);

      final response = await model.generateContent([content]);

      final rawText = response.text ?? 'No text found.';

      // Parse the response using the parseGeminiResponse function
      return parseGeminiResponse(rawText);
    }  on GenerativeAIException catch (e) {
      print('Error in GeminiService: $e');
        if (e.message.contains("API key not valid")) {
          throw Exception("Invalid API Key. Please check your key.");
        }
        throw Exception('Gemini API Error: ${e.message}');
      } on TimeoutException catch (e) {
        print('Timeout in GeminiService: $e');
          throw Exception('Gemini API Timeout: Request took too long.');
      }  on SocketException catch (e) {
            print('SocketException in GeminiService: $e');
          throw Exception("Could not connect to the server. Check your network connection.");
      } catch (e){
          print('Exception in GeminiService: $e');
          throw Exception('Could not extract text: ${e.toString()}');
       }
    }

  bool isValidApiKey(String apiKey) {
    return apiKey.isNotEmpty && apiKey.length > 30;
  }
}