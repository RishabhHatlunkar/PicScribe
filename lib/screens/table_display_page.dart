import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixelsheet/widgets/custom_app_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pixelsheet/services/csv_service.dart';
import 'package:file_saver/file_saver.dart';
import 'package:csv/csv.dart';

class TableDisplayPage extends ConsumerWidget {
  final List<String> extractedText;
   final List<XFile> images;

  const TableDisplayPage({super.key, required this.extractedText, required this.images});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
     return Scaffold(
        appBar: CustomAppBar(title: 'Extracted Table'),
        body: Padding(
            padding: const EdgeInsets.all(16.0),
             child: Column(
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                       Expanded(
                           child: extractedText.isNotEmpty ?  SingleChildScrollView( // Allow horizontal scrolling if needed
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                columns:  _buildColumns(extractedText[0]), // Generate columns dynamically
                                 rows: _buildRows(images, extractedText), // Generate rows dynamically
                                 ),
                               ) : const Center(child: Text("No Data")),
                       ),
                      if(extractedText.isNotEmpty) ElevatedButton(
                           onPressed: () {
                             _exportToCsv(context);
                             },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                                 child: const Text('Export to CSV', style: TextStyle(color: Colors.white),),
                             ),
                 ],
              )
        ),
    );
  }

  // function to dynamically build columns
  List<DataColumn> _buildColumns(String text) {
    if (text.isEmpty) return [];
      List<String> headers = text.split(" , ");
      List<DataColumn> columns = [
        const DataColumn(label: Text("Image Name", style: TextStyle(color: Colors.blue),)),
      ];
    for(var header in headers){
      columns.add(DataColumn(label: Text(header, style: const TextStyle(color: Colors.blue),)));
    }
     return columns;
   }
    // function to dynamically build rows
  List<DataRow> _buildRows(List<XFile> images, List<String> extractedTexts) {
        List<DataRow> rows = [];

      if(extractedTexts.isEmpty){
        return [];
      }
       List<String> headers = extractedTexts[0].split(" , ");

      for (int imageIndex=0; imageIndex< extractedTexts.length ;imageIndex++){
        List<String> values =  extractedTexts[imageIndex].split(" , ");
          List<DataCell> cells = [
             DataCell(Text(images[imageIndex].name, style: const TextStyle(color: Colors.blue),)),
           ];
          for(var value in values){
           cells.add(DataCell(Text(value, style: const TextStyle(color: Colors.blue),)));
         }
         rows.add(DataRow(cells: cells));
      }

     return rows;
   }
   Future<void> _exportToCsv(BuildContext context) async {
    if (extractedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('No text extracted to export.', style: TextStyle(color: Colors.blue),)));
      return;
    }

    List<List<dynamic>> csvData = [
      ['Image', 'Extracted Text']
    ];

    for (int i = 0; i < images.length; i++) {
      csvData.add([images[i].name, extractedText[i]]);
    }

    try {
      String message = await CsvService.exportToCsv(csvData, 'table_data');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.blue),)));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving CSV: $e', style: const TextStyle(color: Colors.blue),)));
    }
  }
}