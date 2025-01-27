import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pixelsheet/providers/providers.dart';
import 'package:pixelsheet/widgets/custom_app_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pixelsheet/services/csv_service.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:easy_folder_picker/FolderPicker.dart';

class TableDisplayPage extends ConsumerStatefulWidget {
  final List<dynamic> parsedData;
  final List<XFile> images;

  const TableDisplayPage({super.key, required this.parsedData, required this.images});

  @override
  ConsumerState<TableDisplayPage> createState() => _TableDisplayPageState();
}

class _TableDisplayPageState extends ConsumerState<TableDisplayPage> {
  List<dynamic> _headers = [];
  List<Map<dynamic, dynamic>> _tableData = [];
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _parseData();
  }


//1. Parse DATA 
//===================================================================================================================
  void _parseData() {
    final rawString = widget.parsedData[0] as String;
    _parseCsvTable(rawString);
  }

  void _parseCsvTable(String rawString)
  {
    // Step 1: Split the string into lines
  List<String> lines = rawString.split('\n');

  // Step 2: Initialize variables
  List<dynamic> headers = [];
  List<Map<dynamic, dynamic>> table = [];
  bool foundHeader = false;

  // Step 3: Parse lines
  for (String line in lines) {
    line = line.trim();

    // Skip irrelevant lines
    if (line.isEmpty || line.startsWith('---') || line.startsWith('Type: Table') || line.startsWith('```csv') || line.startsWith('```')) {
      continue;
    }

    // Identify headers
    if (!foundHeader && line.contains(',')) {
      headers = _parseCsvRow(line);
      foundHeader = true;
      continue;
    }

    // Parse rows
    if (foundHeader && line.contains(',')) {
      List<dynamic> row = _parseCsvRow(line);
      Map<dynamic, dynamic> rowData = {};

      // Match row values with headers
      for (int i = 0; i < headers.length; i++) {
        rowData[headers[i]] = i < row.length ? row[i] : "";
      }

      table.add(rowData);
    }
  }
    _headers = headers;
    _tableData = table;
  }

  List<dynamic> _parseCsvRow(String row) {
  RegExp regex = RegExp(r'(?:\"([^\"]*)\")|([^,]+)|(?<=,)(?=,)|(?<=,)$');
  Iterable<RegExpMatch> matches = regex.allMatches(row);
  return matches.map((match) => match.group(1) ?? match.group(2) ?? "").toList();
}

String convertTableToCsv(List<Map<dynamic, dynamic>> table) {
  if (table.isEmpty) return "";

  // Step 1: Extract headers
  List<dynamic> headers = table.first.keys.toList();

  // Step 2: Generate CSV rows
  StringBuffer csvBuffer = StringBuffer();

  // Add headers to CSV
  csvBuffer.writeln(headers.map((header) => '"$header"').join(','));

  // Add rows to CSV
  for (var row in table) {
    csvBuffer.writeln(headers.map((header) => '"${row[header] ?? ""}"').join(','));
  }

  return csvBuffer.toString();
}

  String _convertTableToCsv(List<Map<dynamic, dynamic>> table) {
      if (table.isEmpty) return "";

      // Step 1: Extract headers
      List<dynamic> headers = table.first.keys.toList();

     // Step 2: Generate CSV rows
      StringBuffer csvBuffer = StringBuffer();

      // Add headers to CSV
      csvBuffer.writeln(headers.map((header) => '"$header"').join(','));

      // Add rows to CSV
      for (var row in table) {
        csvBuffer.writeln(headers.map((header) => '"${row[header] ?? ""}"').join(','));
      }

      return csvBuffer.toString();
  }

//======================================================TO PARSE THE DATA ========================================================





//2. BUild Columns and Rows ======================================================================================================

  List<DataColumn> _buildColumns(List<dynamic> headers) {
      List<DataColumn> columns = [];
       for(var header in headers){
         columns.add(DataColumn(label: Text(header.toString(), style: const TextStyle(color: Colors.blue),)));
      }
     return columns;
   }
  // function to dynamically build rows
  List<DataRow> _buildRows(List<Map<dynamic, dynamic>> extractedTexts) {
      List<DataRow> rows = [];
     // Extract headers from the first map to ensure consistent order
      List<dynamic> headers = extractedTexts.first.keys.toList();

       // Convert each map to a list of cells
      List<List<dynamic>> _listCells = extractedTexts.map((map) {
        return headers.map((header) => map[header] ?? "").toList();
      }).toList();

      //Loop to add each row
      for (int i=0; i < _listCells.length ;i++){
        List<DataCell> cells = [];
        //loop to add each ceel of a single row
        for(int j=0; j< _listCells[i].length; j++){
          cells.add(DataCell(Text(_listCells[i][j])));
        }  
        if(headers.length==cells.length){
          rows.add(DataRow(cells: cells));
        }
        print('Row: {$i} = ');
        print(cells.length);
      }
      return rows;
    }


//==============================================================================================================================



//3. Export to CSV ===============================================================================================================
  Future<void> _exportToCsv(BuildContext context) async {
  if (widget.parsedData.isEmpty || widget.parsedData[0] == "Error") {
    _showSnackBar('No text extracted to export.');
    return;
  }

  String csv = _convertTableToCsv(_tableData);
  try {
    // Generate a unique file name
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String fileName = 'table_data_$timestamp';

    // Convert CSV string to bytes
    final Uint8List bytes = Uint8List.fromList(csv.codeUnits);

    // Save the file using FileSaver's saveAs() to trigger the system picker
    final String? savedPath = await FileSaver.instance.saveAs(
      name: fileName,
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );

    if (savedPath != null) {
      _showSnackBar('CSV file saved successfully to: $savedPath');
    } else {
      _showSnackBar('Save operation canceled.');
    }
  } catch (e) {
    _showSnackBar('Error saving CSV: $e');
  }
}


    Future<String> _pickDirectory(BuildContext context) async {
    Directory? directory = Directory(FolderPicker.rootPath);

    var status = await Permission.manageExternalStorage.status;
      if (status.isRestricted) {
        status = await Permission.manageExternalStorage.request();
      }

      if (status.isDenied) {
        status = await Permission.manageExternalStorage.request();
      }
      if (status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green,
          content: Text('Please add permission for app to manage external storage'),
        ));
      }
    Directory? newDirectory = await FolderPicker.pick(
        allowFolderCreation: true,
        context: context,
        rootDirectory: directory,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))));

    return newDirectory!.path;
  }
//===============================================================================================================================
 
 void _showSnackBar(String message) {
       if(_scaffoldKey.currentContext == null) return;
       ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(
              content: Text(message, style: const TextStyle(color: Colors.blue),)));
  }


  @override
  Widget build(BuildContext context) {
     return Scaffold(
       key: _scaffoldKey,
      appBar: CustomAppBar(title: 'Extracted Table'),
       body: Padding(
          padding: const EdgeInsets.all(16.0),
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                      Expanded(
                          child: _tableData.isNotEmpty ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                               child: SingleChildScrollView(
                                 child: DataTable(
                                    columns:  _buildColumns(_headers),
                                      rows: _buildRows(_tableData),
                                     ),
                               ),
                              ) :  widget.parsedData.isNotEmpty && widget.parsedData[0] == "Error" ? Center(child: Text(widget.parsedData[0][1] , style: const TextStyle(color: Colors.blue),)) : const Center(child: Text("No Data", style: TextStyle(color: Colors.blue),)),
                        ),
                      if(widget.parsedData.isNotEmpty && widget.parsedData[0][0] != "Error" && _tableData.isNotEmpty) ElevatedButton(
                          onPressed: () {
                             _exportToCsv(context);
                            },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            child: const Text('Export to CSV', style: TextStyle(color: Colors.white),),
                        ),
                  ],
             ),
         ),
    );
  }
}


