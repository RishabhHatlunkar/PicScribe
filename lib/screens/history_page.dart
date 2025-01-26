import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pixelsheet/models/conversion_item.dart';
import 'package:pixelsheet/widgets/custom_app_bar.dart';
import 'package:pixelsheet/services/csv_service.dart';
import 'package:pixelsheet/providers/providers.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({ super.key });
  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  late Future<List<ConversionItem>> _historyItems;
   final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

    Future<void> _loadHistory() async {
      final databaseService = ref.read(databaseServiceProvider);
     _historyItems =  databaseService.getConversions();
  }

  Future<void> _exportConversionToCsv(ConversionItem item) async {
    List<List<dynamic>> csvData = [
      ['Image Path', 'Extracted Text', 'Timestamp', 'Instruction'],
      [
        item.imagePath,
        item.extractedText,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(item.timestamp),
        item.instruction,
      ]
    ];

    try {
      String message = await CsvService.exportToCsv(csvData, 'conversion_${item.id}');
     _showSnackBar(message);
    } catch (e) {
      _showSnackBar( 'Error saving CSV: $e');
    }
  }
      Future<void> _deleteConversion(ConversionItem item) async {
  final databaseService = ref.read(databaseServiceProvider);
   try {
      await databaseService.deleteConversion(item.id!); // Use the database service to delete
       setState(() {
         _loadHistory();
      });
       _showSnackBar('Conversion deleted!');
    } catch (e) {
      _showSnackBar('Error during deletion: $e');
    }
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
      appBar: CustomAppBar(title: 'Conversion History'),
      body: FutureBuilder<List<ConversionItem>>(
        future: _historyItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blue,));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.blue),));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No conversion history available.', style: TextStyle(color: Colors.blue),));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                ConversionItem item = snapshot.data![index];
                return Card(
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
                             Text('Extracted Text: ${item.extractedText}', style: const TextStyle(color: Colors.blue)),
                            Text('Instruction: ${item.instruction}', style: const TextStyle(color: Colors.blue)),
                           ],
                      ),
                     ),
                );
             },
            );
          }
        },
      ),
    );
  }
}