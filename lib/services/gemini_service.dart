import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:jinja/jinja.dart' as jj;
import 'package:image_picker/image_picker.dart';
import 'package:csv/csv.dart'; // Import the csv package


class GeminiService {
  final String apiKey;
  GeminiService(this.apiKey);

  // Function to parse the Gemini API response
  List<dynamic> parseGeminiResponse(String response) {
    // Regular expression to extract the Type and the content within the triple backticks
    final RegExp regex = RegExp(
        r"\s*Type:\s*(Table|Text)\s*\n+```(?:csv|markdown)?\n([\s\S]*?)```\s*",
        caseSensitive: false);

    final Match? match = regex.firstMatch(response);

    if (match != null) {
      final String type = match.group(1)!.trim();
      final String content = match.group(2)!.trim();

      if (type == "Table") {
        // Parse CSV content
        try {
          List<List<dynamic>> csvData =
          const CsvToListConverter().convert(content);
          return [type, csvData];
        } catch (e) {
          print("Error parsing CSV data: $e");
          return ["Error", "Could not parse CSV data."];
        }
      } else if (type == "Text") {
        // Return Markdown content as is
        return [type, content];
      } else {
        return ["Error", "Unknown Type: $type"];
      }
    } else {
      return ["Error", "Could not parse response.\n" + response];
    }
  }
  Future<String> _loadTemplate(String templatePath) async {
     return await rootBundle.loadString(templatePath);
  }

  Future<List<dynamic>> extractTextFromImage(XFile imageFile, String instruction) async {
    try {
      final model = GenerativeModel(model: 'gemini-2.0-flash-exp', apiKey: apiKey);

      // Load the template file
       final String promptTemplate = await _loadTemplate('lib/templates/prompt.jinja2');
        final template = jj.Template(promptTemplate);
        final prompt = template.render({'api_key': apiKey,'instruction': instruction});
      
       final content = Content.multi([
          DataPart('image/jpeg', await imageFile.readAsBytes()),
          TextPart(prompt),
       ]);

      final response = await model.generateContent([content]).timeout(const Duration(seconds: 30));

      final rawText = response.text ?? 'No text found.';

      // Parse the response using the parseGeminiResponse function
      return parseGeminiResponse(rawText);
    }  on GenerativeAIException catch (e) {
          print('Error in GeminiService: $e');
       if (e.message.contains("API key not valid")) {
         return ["Error", "Invalid API Key. Please check your key."];
       }
        return  ["Error", 'Gemini API Error: ${e.message}'];
     } on TimeoutException catch (e) {
       print('Timeout in GeminiService: $e');
     return  ["Error", 'Gemini API Timeout: Request took too long.'];
  } on SocketException catch (e) {
     print('SocketException in GeminiService: $e');
        return ["Error", "Could not connect to the server. Check your network connection."];
  }  catch(e) {
      print('Exception in GeminiService: $e');
      return ["Error", 'Could not extract text: ${e.toString()}'];
   }
}

 bool isValidApiKey(String apiKey) {
  return apiKey.isNotEmpty && apiKey.length > 30;
}
}