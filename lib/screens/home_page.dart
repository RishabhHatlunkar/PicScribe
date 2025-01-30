import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pixelsheet/widgets/api_key_dialog.dart';
import 'package:pixelsheet/widgets/loading_indicator.dart';
// import 'package:pixelsheet/services/csv_service.dart';
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

class _HomePageState extends ConsumerState<HomePage> with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _instructionController = TextEditingController();
  File? _imageFile;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiKeyAndShowDialog();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkApiKeyAndShowDialog() async {
    try {
      final apiKeyAsync = ref.read(apiKeyProvider);
      final apiKey = apiKeyAsync.valueOrNull;
      if (apiKey == null) {
        _showApiKeyDialog();
      }
    } catch (e, st) {
      print('Error checking API key: $e\n$st');
       _showSnackBar('An error occurred while checking for the API Key.');
    }
  }


  Future<void> _pickImage(ImageSource source) async {
    try {
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
        ref.read(imagesProvider.notifier).state = [XFile(savedImage.path)];
      }
    } catch (e, st) {
        print('Error picking image: $e\n$st');
       _showSnackBar('Error selecting image. Please try again.');
    }
  }

  Future<void> _extractTextFromImages() async {
    final images = ref.read(imagesProvider);
    final apiKeyAsync = ref.read(apiKeyProvider);
    final geminiService = ref.read(geminiServiceProvider);
    final instruction = _instructionController.text;

    final apiKey = apiKeyAsync.valueOrNull;

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
      final result = await geminiService.extractTextFromImage(image, instruction);
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
          type: getType(result[0]),
          instruction: instruction,
        );
      await ref.read(saveConversionProvider(conversionItem).future);
      // Update the provider with the parsed data
        ref.read(parsedDataProvider.notifier).state = parsedData;

        if (_scaffoldKey.currentContext != null && mounted) {
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
     }
    catch (e, st) {
      print('Error extracting text: $e\n$st');
        _showSnackBar('Error extracting text: Please try again with another image.');
    } finally {
      if (mounted) {
        ref.read(loadingStateProvider.notifier).state = false;
      }
    }
      _imageFile = null;
      _instructionController.text = "";
  }



  void _showApiKeyDialog() {
    if (!mounted || _scaffoldKey.currentContext == null) return;
    showDialog(
      context: _scaffoldKey.currentContext!,
      builder: (context) {
        return ApiKeyDialog(
          onApiKeySaved: (apiKey) async {
            try {
              await ref.read(apiKeyProvider.notifier).saveApiKey(apiKey);
            } catch (e, st) {
              print('Error saving API key: $e\n$st');
              _showSnackBar('Error saving API key.');
            }
          },
        );
      },
    );
  }

  // Future<void> _exportToCsv() async {
  //   final extractedText = ref.read(extractedTextProvider);
  //   final images = ref.read(imagesProvider);

  //    if (extractedText.isEmpty) {
  //     _showSnackBar('No text extracted to export.');
  //     return;
  //   }
  //   List<List<dynamic>> csvData = [
  //     ['Image', 'Extracted Text']
  //   ];

  //     for (int i = 0; i < images.length; i++) {
  //       csvData.add([images[i].name, extractedText[i]]);
  //     }


  //   try {
  //     String message = await CsvService.exportToCsv(csvData, 'image_text');
  //      _showSnackBar(message);
  //   } catch (e, st) {
  //     print('Error exporting to CSV: $e\n$st');
  //     _showSnackBar('Error saving CSV: $e');
  //   }
  // }

  void _showSnackBar(String message) {
      if (!mounted || _scaffoldKey.currentContext == null) return;
      ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.blue))));
  }

  void _showImageSourceOptions() {
    if (!mounted || _scaffoldKey.currentContext == null) return;
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
    // final images = ref.watch(imagesProvider);
    final isLoading = ref.watch(loadingStateProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(0, 13, 101, 201),
        elevation: 0,
        title: const Text(
          'PicScribe 📜',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
      ),
      body: Container(
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade500,
              Colors.purple.shade500,
            ],
          ),
        ),
        child: isLoading
            ? Center(child: LoadingIndicator())
            : SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) => Transform.scale(
                      scale: _scaleAnimation.value,
                      child: GestureDetector(
                        onTapDown: (_) => _animationController.forward(),
                        onTapUp: (_) => _animationController.reverse(),
                        onTapCancel: () => _animationController.reverse(),
                        child: _buildImagePickerCard(size),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInstructionCard(),
                  const SizedBox(height: 24),
                  _buildExtractButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerCard(Size size) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: _showImageSourceOptions,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: size.height * 0.4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.7),
              ],
            ),
          ),
          child: _imageFile != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  _imageFile!,
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 16,
                  left: 16,
                  child: Text(
                    'Tap to change image',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 64,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap to add an image',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.7),
            ],
          ),
        ),
        child: TextField(
          controller: _instructionController,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            labelText: 'Additonal Instructions',
            labelStyle: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.blue.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.blue.shade900, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.blue.shade200),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.5),
          ),
          maxLines: null,
        ),
      ),
    );
  }

  Widget _buildExtractButton() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade600,
              Colors.purple.shade500,
            ],
          ),
        ),
        child: ElevatedButton(
          onPressed: _extractTextFromImages,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            'Extract Text',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

getType(result) {
    final rawString = result as String;
    print(rawString);
    var myType = "md";
    if (rawString.contains('Table')) {
      myType = "table"; // CSV has priority in this case
    }
    return myType;
}