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
import 'package:csv/csv.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pixelsheet/screens/table_display_page.dart';


class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late Future<List<ConversionItem>> _historyItems;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showHistory = false; // Added this to manage the bottom sheet

  @override
  void initState() {
    super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiKeyAndShowDialog();
    });
    _loadHistory();
  }

    Future<void> _checkApiKeyAndShowDialog() async {
      if (ref.read(apiKeyProvider) == null) {
       _showApiKeyDialog();
       }
  }


  Future<void> _loadHistory() async {
    final databaseService = ref.read(databaseServiceProvider);
    _historyItems = databaseService.getConversions();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = basename(image.path);
      final savedImage = File(join(appDir.path, fileName));

      await File(image.path).copy(savedImage.path);
      ref.read(imagesProvider.notifier).state = [XFile(savedImage.path)];
    }
  }

  Future<void> _extractTextFromImages() async {
    final images = ref.read(imagesProvider);
    final apiKey = ref.read(apiKeyProvider);
    final geminiService =
    ref.read(geminiServiceProvider); // Get the GeminiService instance

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
        final result = await geminiService.extractTextFromImage(image as XFile);

        if (result[0] == "Error") {
          throw Exception(result[1]);
        }

        parsedData.add(result);
// Add the [Type, Data] list to parsedData

        final conversionItem = ConversionItem(
            imagePath: image.path,
            extractedText: result[1] is String ? result[1] : const ListToCsvConverter().convert(result[1]), // Get raw text from result
            timestamp: DateTime.now());
        await ref.read(saveConversionProvider(conversionItem).future);
      }

      // Update the provider with the parsed data
      ref.read(parsedDataProvider.notifier).state = parsedData;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(imagesProvider.notifier).state = []; // Remove the selected image.
        Navigator.push(
            _scaffoldKey.currentContext!,
            MaterialPageRoute(
              builder: (context) => TableDisplayPage(
                parsedData: parsedData, // Pass the parsed data
                images: images,
              ),
            ));
      });

      _loadHistory();
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

   Future<void> _exportConversionToCsv(ConversionItem item) async {
    List<List<dynamic>> csvData = [
      ['Image Path', 'Extracted Text', 'Timestamp'],
      [
        item.imagePath,
        item.extractedText,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(item.timestamp),
      ]
    ];

    try {
      String message = await CsvService.exportToCsv(csvData, 'conversion_${item.id}');
      _showSnackBar( message);

    } catch (e) {
        _showSnackBar( 'Error saving CSV: $e');
    }
  }

    Future<void> _deleteConversion(ConversionItem item) async {
    final databaseService = ref.read(databaseServiceProvider);
    try {
      await databaseService.close();
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'conversion_history.db');
      await deleteDatabase(path);
      await databaseService.insertConversion(item);
      setState(() {
        _loadHistory();
      });
      _showSnackBar('Conversion deleted!');
    } catch (e) {
          _showSnackBar( 'Error during deletion: $e');
    }
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
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        return Stack(
          children: [
            Image.file(
              File(image.path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ],
        );
      },
    );
  }
     void _showSnackBar(String message) {
      if (_scaffoldKey.currentContext == null) return;
       ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
              content: Text(message, style: const TextStyle(color: Colors.blue))));
  }
  void _showHistoryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
           return FutureBuilder<List<ConversionItem>>(
                  future: _historyItems,
                  builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                           return const Center(child: CircularProgressIndicator(color: Colors.blue,));
                      } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.blue),));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                         return Center(child: Text('No conversion history available.', style: const TextStyle(color: Colors.blue),));
                      } else {
                       return ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                              ConversionItem item = snapshot.data![index]!;
                               return  GestureDetector(
                                 onTap: () async {
                                   // Get the GeminiService instance
                                   final geminiService = ref.read(geminiServiceProvider);

                                   // Re-extract and parse the data
                                   final result = await geminiService.extractTextFromImage(XFile(item.imagePath) as XFile);

                                   if (result[0] == "Error") {
                                     // Handle the error, maybe show a SnackBar
                                     _showSnackBar('Error: ${result[1]}');
                                   } else {
                                     Navigator.push(
                                       context,
                                       MaterialPageRoute(
                                         builder: (context) => TableDisplayPage(
                                           parsedData: [result], // Pass the re-extracted data
                                           images: [XFile(item.imagePath)],
                                         ),
                                       ),
                                     );
                                   }
                                 },
                                 child: Card(
                                  margin: const EdgeInsets.all(8.0),
                                  child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                SizedBox(
                                                  height: 60,
                                                  width: 60,
                                                    child: Image.file(File(item.imagePath), fit: BoxFit.cover,),
                                                  ),
                                                  Row(
                                                    children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.save_alt, color: Colors.blue,),
                                                          onPressed: () => _exportConversionToCsv(item),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(Icons.delete, color: Colors.blue,),
                                                          onPressed: () => _deleteConversion(item),
                                                        ),
                                                      ],
                                                  ),
                                               ],
                                            ),
                                             ConstrainedBox(
                                              constraints: const BoxConstraints(maxHeight: 80),
                                                child: Text('Extracted Text: ${item.extractedText}', style: const TextStyle(color: Colors.blue), overflow: TextOverflow.ellipsis,),
                                             ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                             },
                            );
                          }
                  },
                );
      },
    );
  }


   @override
  Widget build(BuildContext context) {
    final images = ref.watch(imagesProvider);
    final extractedText = ref.watch(extractedTextProvider);
    final isLoading = ref.watch(loadingStateProvider);

      return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(title: 'Image to Text Converter'),
       body: Padding(
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
                child: const Icon(Icons.add, size: 60, color: Colors.blue),
              ),
             const SizedBox(height: 16),
              if (images.isNotEmpty)
              Expanded(child: _buildImageGrid()),
              const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _extractTextFromImages,
              child: const Text('Extract Text', style: TextStyle(color: Colors.blue),),
            ),
            const SizedBox(height: 16),
            if (isLoading) LoadingIndicator(),
             Expanded(
              child: Align(
                 alignment: Alignment.bottomCenter,
                  child:  Padding(
                      padding: const EdgeInsets.only(bottom: 80.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                         child:  GestureDetector(
                            onVerticalDragUpdate: (details) {
                              if (details.delta.dy < -5) {
                                 _showHistoryBottomSheet(context);
                               }
                            },
                             child: const Text(
                             "Drag from bottom to see history",
                               style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w400, fontSize: 16),
                             ),
                            ),
                       ),
                   ),
                 ),
           ),
          ],
        ),
       ),
    );
  }
}