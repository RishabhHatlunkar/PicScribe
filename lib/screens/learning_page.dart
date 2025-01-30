import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pixelsheet/models/learning_item.dart';
import 'package:pixelsheet/widgets/custom_app_bar.dart';
import 'package:pixelsheet/providers/providers.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LearningPage extends ConsumerStatefulWidget {
  const LearningPage({ super.key });

  @override
  ConsumerState<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends ConsumerState<LearningPage> {
  late Future<List<LearningItem>> _learningItems;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
     _loadLearningItems();
  }

   Future<void> _loadLearningItems() async {
     final databaseService = ref.read(databaseServiceProvider);
     _learningItems = databaseService.getLearningItems();
  }

   Future<void> _deleteLearningItem(LearningItem item, List<LearningItem> data) async {
    final databaseService = ref.read(databaseServiceProvider);
    final int index = data.indexOf(item);

     LearningItem deletedItem = item; // Store the deleted item for undo

    setState(() {
      if(data.isNotEmpty) {
           _learningItems = Future.value(List<LearningItem>.from(data)..removeAt(index));
         }
    });
      if(_scaffoldKey.currentContext != null)
      {
        ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
            content: const Text('Learning Item Deleted!', style: TextStyle(color: Colors.blue)),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                final db = await databaseService.database;
                db.insert('learning_items', deletedItem.toMap());

                 setState(() {
                    _loadLearningItems();
                });
                _showSnackBar('Learning Item Restored!');
               },
            ),
           ),
         );
      }
     try {
       await databaseService.deleteLearningItem(item.id!);
    } catch (e) {
      print('Error deleting item from database $e');
      _showSnackBar('Error deleting item from database $e');
    }
  }
   void _pushLearningAddPage() {
    if(_scaffoldKey.currentContext == null) return;
     Navigator.push(
          _scaffoldKey.currentContext!,
          MaterialPageRoute(builder: (context) => const LearningAddPage()),
         ).then((value) {
           if (value != null && value == true) {
              setState(() {
                _loadLearningItems();
               });
             }
         });
    }

    // void _pushLearningDetailPage(LearningItem item) {
    //   if(_scaffoldKey.currentContext == null) return;
    //     Navigator.push(
    //           _scaffoldKey.currentContext!,
    //         MaterialPageRoute(builder: (context) => LearningDetailPage(learningItem: item,)),
    //        ).then((value) {
    //            if (value != null && value == true) {
    //              setState(() {
    //                 _loadLearningItems();
    //               });
    //             }
    //          });
    // }
    void _showSnackBar(String message) {
       if (_scaffoldKey.currentContext == null) return;
       ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
              content: Text(message, style: const TextStyle(color: Colors.blue),)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       key: _scaffoldKey,
      appBar: const CustomAppBar(title: 'Learning'),
      body: FutureBuilder<List<LearningItem>>(
          future: _learningItems,
          builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator(color: Colors.blue,));
           } else if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.blue),));
           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
             return  Stack(
                  alignment: Alignment.bottomRight, // Place the button at the bottom right corner
                  children: [
                    const Center(child: Text('No learning data available.', style: TextStyle(color: Colors.blue),)),
                     Positioned(
                      bottom: 90.0, // Align the button 90px above the bottom
                      right: 16.0,  // align the button 16 px right
                     child: ElevatedButton(
                       onPressed: () {
                         _pushLearningAddPage();
                        },
                         style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.blue,
                          shape: const CircleBorder(),
                         padding: const EdgeInsets.all(16.0),
                      ),
                       child: const Icon(Icons.add, color: Colors.white,),
                     ),
                   ),
                 ],
               );
           } else {
            return Stack(
              alignment: Alignment.bottomRight,
              children: [
                    ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                      LearningItem item = snapshot.data![index];
                      return  Card(
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
                                           IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.blue,),
                                             onPressed: () {
                                               if(snapshot.hasData) {
                                                 _deleteLearningItem(item, snapshot.data!);
                                                }
                                            },
                                         ),
                                       ],
                                     ),
                                   Text('Description: ${item.description}', style: const TextStyle(color: Colors.blue)),
                                 ],
                               ),
                             ),
                         );
                      },
                    ),
                 Positioned(
                    bottom: 90.0,
                    right: 16.0,
                   child: ElevatedButton(
                       onPressed: () {
                         _pushLearningAddPage();
                       },
                         style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.blue,
                          shape: const CircleBorder(),
                         padding: const EdgeInsets.all(16.0),
                      ),
                       child: const Icon(Icons.add, color: Colors.white,),
                     ),
                  ),
              ],
            );
           }
        },
      ),
    );
  }
}

class LearningAddPage extends ConsumerStatefulWidget {
    const LearningAddPage({ super.key });
  @override
  ConsumerState<LearningAddPage> createState() => _LearningAddPageState();
}

class _LearningAddPageState extends ConsumerState<LearningAddPage> {
    File? _image;
    final TextEditingController _descriptionController = TextEditingController();
    final _scaffoldKey = GlobalKey<ScaffoldState>();

    Future<void> _getImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);

     setState(() async {
        if (pickedFile != null) {
            final appDir = await getApplicationDocumentsDirectory();
            final fileName = basename(pickedFile.path);
            final savedImage = File(join(appDir.path, fileName));

            await File(pickedFile.path).copy(savedImage.path);
            _image =  savedImage;
        } else {
          print('No image selected.');
       }
    });
  }


  Future<void> _saveLearningItem() async {
    if (_image == null) {
         _showSnackBar('Please select an image.');
      return;
    }

    if (_descriptionController.text.isEmpty) {
         _showSnackBar('Please add a description.');
      return;
    }

    try {
      final databaseService = ref.read(databaseServiceProvider);
      await databaseService.insertLearningItem(
        LearningItem(
          imagePath: _image!.path,
          description: _descriptionController.text,
        ),
      );
        _showSnackBar('Learning item saved successfully!');

      // Clear the form
      setState(() {
        _image = null;
        _descriptionController.clear();
      });
       if(_scaffoldKey.currentContext != null){
            Navigator.pop(_scaffoldKey.currentContext!, true);
       }
    } catch (e) {
        _showSnackBar('Error saving: $e');
     }
   }

  @override
   void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
  void _showSnackBar(String message) {
      if (_scaffoldKey.currentContext == null) return;
       ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
              content: Text(message, style: const TextStyle(color: Colors.blue),)));
  }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
         key: _scaffoldKey,
        appBar: const CustomAppBar(title: 'Add Learning Data'),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_image != null)
                Image.file(
                 _image!,
                 height: 150,
                  width: 150,
                  fit: BoxFit.cover,
                )
              else
                const Text('No image selected', style: TextStyle(color: Colors.blue)),
              const SizedBox(height: 16),
               TextField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.blue),
                  decoration: const InputDecoration(
                   labelText: 'Description',
                   labelStyle: TextStyle(color: Colors.blue),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue)
                    ),
                   focusedBorder: OutlineInputBorder(
                     borderSide: BorderSide(color: Colors.blue)
                   ),
                 ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
               onPressed: _saveLearningItem,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue,),
                 child: const Text('Save Learning Item', style: TextStyle(color: Colors.white),),
             ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.blue,
          onPressed: () {
             showDialog(
              context: context,
               builder: (BuildContext context) {
                return AlertDialog(
                    title: const Text("Choose Image Source", style: TextStyle(color: Colors.blue),),
                    actions: [
                      TextButton(
                        child: const Text("Camera", style: TextStyle(color: Colors.blue)),
                        onPressed: () {
                           Navigator.of(context).pop();
                           _getImage(ImageSource.camera);
                         },
                   ),
                     TextButton(
                       child: const Text("Gallery", style: TextStyle(color: Colors.blue)),
                        onPressed: () {
                        Navigator.of(context).pop();
                         _getImage(ImageSource.gallery);
                       },
                    ),
                 ],
               );
              },
           );
           },
         child: const Icon(Icons.camera_alt, color: Colors.white,),
      ),
    );
  }
}
// detail screen for learning item
class LearningDetailPage extends ConsumerWidget{
  final LearningItem learningItem;
  const LearningDetailPage({super.key, required this.learningItem});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    return Scaffold(
      appBar:  const CustomAppBar(title: 'Learning Detail'),
       body: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
              children: [
               SizedBox(
                height: 200,
                width: 200,
                  child: Image.file(File(learningItem.imagePath), fit: BoxFit.cover,)
               ),
                 const SizedBox(height: 16),
                 Text('Description: ${learningItem.description}', style: const TextStyle(color: Colors.blue, fontSize: 16)),
             ],
            ),
         ),
       );
    }
}