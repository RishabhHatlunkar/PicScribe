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

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = basename(image.path);
      final savedImage = File(join(appDir.path, fileName));

      await File(image.path).copy(savedImage.path);
      setState(() {
        _imageFile = savedImage;
      });
      ref.read(imagesProvider.notifier).state = [XFile(savedImage.path)]; // Store the selected image in list
    }
  }

  Future<void> _extractTextFromImages() async {
    final images = ref.read(imagesProvider);
    final apiKey = ref.read(apiKeyProvider);
    final geminiService = ref.read(geminiServiceProvider);
    final instruction = _instructionController.text;

    if (images.isEmpty) {
      _showSnackBar('Please select an image first.');
      return;
    }

     if (images.length > 1) {
      _showSnackBar('Please select only one image.');
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
      // since there is one image we get the first one from the list
        var image = images[0];
        final result =
            await geminiService.extractTextFromImage(image, instruction);

        if (result[0] == "Error") {
          throw Exception(result[1]);
        }
        parsedData.add(result[1]); // Here I am taking the text directly and sending it
        final conversionItem = ConversionItem(
            imagePath: image.path,
            extractedText: result[1] is String
                ? result[1]
                : const ListToCsvConverter().convert(result[1]),
            timestamp: DateTime.now(),
            instruction: instruction,
            );
          await ref.read(saveConversionProvider(conversionItem).future);
       // Update the provider with the parsed data
      ref.read(parsedDataProvider.notifier).state = parsedData;
      if (_scaffoldKey.currentContext != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(imagesProvider.notifier).state = [];
          Navigator.push(
              _scaffoldKey.currentContext!,
              MaterialPageRoute(
                builder: (context) => TableDisplayPage(
                  images: images,
                  parsedData: parsedData,
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
    _imageFile = null;
    _instructionController.text = "";
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
      _showSnackBar('Error saving CSV: $e');
    }
  }

  void _showSnackBar(String message) {
    if (_scaffoldKey.currentContext == null) return;
    ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.blue))));
  }

  void _showImageSourceOptions() {
    if (_scaffoldKey.currentContext == null) return;
    showModalBottomSheet(
      context: _scaffoldKey.currentContext!,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final images = ref.watch(imagesProvider);
    final extractedText = ref.watch(extractedTextProvider);
    final isLoading = ref.watch(loadingStateProvider);
    FocusNode _focusNode = FocusNode();

    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(title: 'Image to Text Converter'),
      body:  isLoading
          ?  Center(
              child: LoadingIndicator(), // Show loading indicator instead of content
            )
          : SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _showImageSourceOptions,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 300),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _imageFile != null
                        ? Container(
                                                height: 200,
                                                width: 200,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.1),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.file(
                                                    _imageFile!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              )
                        : const Icon(Icons.add, size: 60, color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _instructionController,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Color.fromARGB(255, 60, 60, 60)),
                    cursorColor: Color.fromARGB(255, 60, 60, 60),
                    decoration: InputDecoration(
                      labelText: 'Instruction to Extract',
                      labelStyle: const TextStyle(
                        color: Color.fromARGB(255, 60, 60, 60),
                      ),
                      border: const OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                    maxLines: null,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _extractTextFromImages,
                    child: const Text(
                      'Extract Text',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}