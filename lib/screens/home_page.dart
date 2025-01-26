import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pixelsheet/widgets/api_key_dialog.dart';
import 'package:pixelsheet/widgets/loading_indicator.dart';
import 'package:pixelsheet/widgets/custom_app_bar.dart';
import 'package:pixelsheet/services/csv_service.dart';
import 'package:pixelsheet/providers/providers.dart';
import 'package:pixelsheet/models/conversion_item.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixelsheet/screens/table_display_page.dart';
import 'package:csv/csv.dart';


class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _instructionController = TextEditingController();
  File? _imageFile;

  @override
  void initState() {
    super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiKeyAndShowDialog();
    });
  }

  Future<void> _checkApiKeyAndShowDialog() async {
      if (ref.read(apiKeyProvider) == null) {
       _showApiKeyDialog();
       }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = basename(image.path);
      final savedImage = File(join(appDir.path, fileName));

      await File(image.path).copy(savedImage.path);
       setState(() {
          _imageFile = savedImage;
       });
      ref.read(imagesProvider.notifier).state = [XFile(savedImage.path)];
    }
  }

    Future<void> _extractTextFromImages() async {
    final images = ref.read(imagesProvider);
    final apiKey = ref.read(apiKeyProvider);
    final geminiService =
    ref.read(geminiServiceProvider);
     final instruction = _instructionController.text;

    if (images.isEmpty) {
      _showSnackBar('Please select images first.');
      return;
    }

    if (apiKey == null || apiKey.isEmpty) {
      _showApiKeyDialog();
      return;
    }

    ref.read(extractedTextProvider.notifier).state = [];
    ref.read(loadingStateProvider.notifier).state = true;

    try {
      List<dynamic> parsedData = [];
      for (var image in images) {
        // Use the geminiService instance to call extractTextFromImage
        final result = await geminiService.extractTextFromImage(image, instruction);

        if (result[0] == "Error") {
          throw Exception(result[1]);
        }
        parsedData.add(result);
       final conversionItem = ConversionItem(
            imagePath: image.path,
            extractedText: result[1] is String ? result[1] : const ListToCsvConverter().convert(result[1]),
            timestamp: DateTime.now(),
            instruction: instruction
            );
        await ref.read(saveConversionProvider(conversionItem).future);
      }
      // Update the provider with the parsed data
      ref.read(parsedDataProvider.notifier).state = parsedData;
       setState(() {
          _imageFile = null;
          _instructionController.clear();
        });

         if(_scaffoldKey.currentContext != null)
        {
           WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(imagesProvider.notifier).state = [];
          Navigator.push(
              _scaffoldKey.currentContext!,
            MaterialPageRoute(
              builder: (context) => TableDisplayPage(
               parsedData: parsedData,
                 images: images,
                ),
            ));
         });
        }
    } catch (e) {
      print('Error extracting text: $e');
      _showSnackBar('Error extracting text: $e');
    } finally {
      ref.read(loadingStateProvider.notifier).state = false;
    }
  }

  void _showApiKeyDialog() {
     if (_scaffoldKey.currentContext == null) return;
    showDialog(
      context: _scaffoldKey.currentContext!,
      builder: (context) {
        return ApiKeyDialog(
          onApiKeySaved: (apiKey) {
            ref.read(apiKeyProvider.notifier).state = apiKey;
          },
        );
      },
    );
  }
  Future<void> _exportToCsv() async {
    final extractedText = ref.read(extractedTextProvider);
    final images = ref.read(imagesProvider);

    if (extractedText.isEmpty) {
        _showSnackBar('No text extracted to export.');
      return;
    }

    List<List<dynamic>> csvData = [
      ['Image', 'Extracted Text']
    ];

    for (int i = 0; i < images.length; i++) {
      csvData.add([images[i].name, extractedText[i]]);
    }

    try {
      String message = await CsvService.exportToCsv(csvData, 'image_text');
         _showSnackBar(message);
    } catch (e) {
          _showSnackBar( 'Error saving CSV: $e');
    }
  }

    Widget _buildImageGrid() {
      final images = ref.watch(imagesProvider);
    return  SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, // Added horizontal scrolling
        itemCount: images.length,
        itemBuilder: (context, index) {
          final image = images[index];
            return SizedBox(
            width: 150,
              child:  Image.file(
                 File(image.path),
                    fit: BoxFit.cover,
               ),
             );
        },
      ),
    );
  }
  void _showSnackBar(String message) {
      if (_scaffoldKey.currentContext == null) return;
       ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
              content: Text(message, style: const TextStyle(color: Colors.blue))));
  }
 @override
  Widget build(BuildContext context) {
    final images = ref.watch(imagesProvider);
    final extractedText = ref.watch(extractedTextProvider);
    final isLoading = ref.watch(loadingStateProvider);

      return Scaffold(
        key: _scaffoldKey,
      appBar: CustomAppBar(title: 'Image to Text Converter'),
       body: SingleChildScrollView(
         child: Stack(
           children: [
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _pickImage,
                       style: ElevatedButton.styleFrom(
                         minimumSize: const Size(100, 300),
                          backgroundColor: Colors.white,
                         shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                     ),
                       child: _imageFile != null
                             ? SizedBox(
                               width: 100,
                                height: 100,
                                  child:  Image.file(
                                    _imageFile!,
                                      fit: BoxFit.cover,
                                    ),
                             )
                           : const Icon(Icons.add, size: 60, color: Colors.blue),
                       ),
                      const SizedBox(height: 16),
                      if (images.isNotEmpty)
                       SizedBox(
                          height: 150,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                               itemCount: images.length,
                                itemBuilder: (context, index) {
                                  final image = images[index];
                                    return SizedBox(
                                    width: 150,
                                       child:  Image.file(
                                          File(image.path),
                                           fit: BoxFit.cover,
                                        ),
                                    );
                                },
                             ),
                          ),
                     const SizedBox(height: 16),
                      TextField(
                        controller: _instructionController,
                         style: const TextStyle(color: Colors.blue),
                          decoration: const InputDecoration(
                           labelText: 'Instruction to Extract',
                             border: OutlineInputBorder(
                               borderSide: BorderSide(color: Colors.blue)
                             ),
                            focusedBorder: OutlineInputBorder(
                             borderSide: BorderSide(color: Colors.blue)
                            ),
                         ),
                         maxLines: null,
                      ),
                    const SizedBox(height: 16),
                   ElevatedButton(
                     onPressed: _extractTextFromImages,
                     child: const Text('Extract Text', style: TextStyle(color: Colors.blue),),
                   ),
                     const SizedBox(height: 16),
                      
                   if (extractedText.isNotEmpty)
                      ElevatedButton(
                         onPressed: _exportToCsv,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue,),
                       child: const Text('Export to CSV', style: TextStyle(color: Colors.white),),
                    ),
                  ],
                ),),
               if (isLoading)
               Center(
                  child: LoadingIndicator(), // Loading indicator is in Center
                ),
            ],
           ),
         ),
      );
  }
}