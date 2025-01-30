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
import 'package:flutter_markdown/flutter_markdown.dart';

class TableDisplayPage extends ConsumerStatefulWidget {
  final List<dynamic> parsedData;
  final List<XFile> images;

  const TableDisplayPage(
      {super.key, required this.parsedData, required this.images});

  @override
  ConsumerState<TableDisplayPage> createState() => _TableDisplayPageState();
}

class _TableDisplayPageState extends ConsumerState<TableDisplayPage> {
  List<dynamic> _headers = [];
  List<Map<dynamic, dynamic>> _tableData = [];
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isMarkdown = false;
  bool _responsestatus = true;

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  void _parseData() {
     try{
       final rawString = widget.parsedData[0] as String;
      if (rawString.startsWith('Type: Table') || rawString.contains('```csv')) {
        // It's likely a CSV inside a Markdown block
        _parseCsvTable(rawString);
        _isMarkdown = false; // CSV has priority in this case
      } else if (_isMarkdownText(rawString)) {
        // Check for Markdown structure
        _isMarkdown = true;
      } else {
        _parseCsvTable(rawString);
      }
     } catch(e, st){
        print('Error Parsing Data: $e\n$st');
        _showSnackBar('Error parsing data for display, Please try again.');
        setState(() {
           _responsestatus = false;
        });
     }
  }

  bool _isMarkdownText(String text) {
    // Detect Markdown by checking its structure rather than just keywords
    final markdownRegex = RegExp(
      r'(^#{1,6}\s|^\*|^\-|^\d+\.\s|```|`[^`]*`|\[[^\]]+\]\([^)]+\))',
      multiLine: true,
    );
    return markdownRegex.hasMatch(text);
  }

  void _parseCsvTable(String rawString) {
     try{
       final csvBlockRegex = RegExp(r'```csv\s*([\s\S]*?)\s*```');
       final match = csvBlockRegex.firstMatch(rawString);

       if (match != null) {
         final csvContent = match.group(1)!;
         List<String> lines = csvContent.split('\n');
         List<dynamic> headers = [];
         List<Map<dynamic, dynamic>> table = [];
         bool foundHeader = false;

         for (String line in lines) {
           line = line.trim();

           if (line.isEmpty) continue;

           if (!foundHeader) {
             headers = _parseCsvRow(line);
             foundHeader = true;
             continue;
           }

           List<dynamic> row = _parseCsvRow(line);
           Map<dynamic, dynamic> rowData = {};
           for (int i = 0; i < headers.length; i++) {
             rowData[headers[i]] = i < row.length ? row[i] : "";
           }
           if(rowData.length == headers.length){
            _responsestatus = true;
          }
         }
          _headers = headers;
          _tableData = table;
      } else {
          // Handle plain CSV without Markdown block
          List<String> lines = rawString.split('\n');
          _headers = [];
          _tableData = [];

          for (String line in lines) {
            line = line.trim();

            if (line.isEmpty || line.startsWith('---')) continue;

            if (_headers.isEmpty && line.contains(',')) {
              _headers = _parseCsvRow(line);
              continue;
            }

           if (_headers.isNotEmpty && line.contains(',')) {
             List<dynamic> row = _parseCsvRow(line);
              Map<dynamic, dynamic> rowData = {};
              for (int i = 0; i < _headers.length; i++) {
                  rowData[_headers[i]] = i < row.length ? row[i] : "";
                }
             _tableData.add(rowData);
           }
         }
      }
      } catch(e, st) {
         print('Error Parsing CSV Table: $e\n$st');
        _showSnackBar('Error parsing csv table.');
        setState(() {
          _responsestatus = false;
         });
       }
  }

  List<dynamic> _parseCsvRow(String row) {
    try{
        final regex = RegExp(r'(?:\"([^\"]*)\")|([^,]+)|(?<=,)(?=,)|(?<=,)$');
        return regex.allMatches(row).map((match) => match.group(1) ?? match.group(2) ?? "").toList();
    } catch (e, st) {
        print('Error Parsing CSV Row: $e\n$st');
        _showSnackBar('Error parsing csv row.');
        return [];
    }
  }

  String _convertTableToCsv(List<Map<dynamic, dynamic>> table) {
    if (table.isEmpty) return "";
    List<dynamic> headers = table.first.keys.toList();
    StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln(headers.map((header) => '"$header"').join(','));
    for (var row in table) {
      csvBuffer
          .writeln(headers.map((header) => '"${row[header] ?? ""}"').join(','));
    }
    return csvBuffer.toString();
  }

  List<DataColumn> _buildColumns(List<dynamic> headers) {
    return headers
        .map((header) => DataColumn(
            label: Text(header.toString(),
                style: const TextStyle(color: Colors.blue))))
        .toList();
  }

  List<DataRow> _buildRows(List<Map<dynamic, dynamic>> extractedTexts) {
    List<dynamic> headers = extractedTexts.first.keys.toList();
    return extractedTexts.map((map) {
      List<DataCell> cells =
          headers.map((header) => DataCell(Text(map[header] ?? ""))).toList();
      return DataRow(cells: cells);
    }).toList();
  }

   Future<void> _exportToCsv(BuildContext context) async {
    if (_tableData.isEmpty) {
      _showSnackBar('No table data to export.');
      return;
    }
    String csv = _convertTableToCsv(_tableData);
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'table_data_$timestamp';
      final Uint8List bytes = Uint8List.fromList(csv.codeUnits);

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
    } catch (e, st) {
      print('Error saving CSV: $e\n$st');
      _showSnackBar('Error saving CSV: $e');
    }
  }

  Future<void> _exportToFile(BuildContext context) async {
    if (widget.parsedData.isEmpty || widget.parsedData[0] == "Error") {
      _showSnackBar('No text to export.');
      return;
    }

    try {
      final String rawText = widget.parsedData[0] as String;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'extracted_text_$timestamp';

      // Convert text to UTF-8 bytes
      final Uint8List bytes = Uint8List.fromList(rawText.codeUnits);

      // Save the file using FileSaver's saveAs() to trigger the system picker
      final String? savedPath = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: bytes,
        ext: 'txt',
        mimeType: MimeType.text,
      );

      if (savedPath != null) {
        _showSnackBar('File saved successfully to: $savedPath');
      } else {
        _showSnackBar('Save operation canceled.');
      }
    } catch (e, st) {
      print('Error saving file: $e\n$st');
       _showSnackBar('Error saving file: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted || _scaffoldKey.currentContext == null) return;
    ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(
      SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.blue))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(title: 'Extracted Data'),
      body: _responsestatus? Padding(
        padding: const EdgeInsets.all(16.0),
        child: _tableData.isNotEmpty
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _tableData.isNotEmpty
                  ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: _buildColumns(_headers),
                    rows: _buildRows(_tableData),
                  ),
                ),
              )
                  : const Center(
                child: Text(
                  "No Data",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),
            if (_tableData.isNotEmpty)
              ElevatedButton(
                onPressed: () => _exportToCsv(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue),
                child: const Text('Export to CSV',
                    style: TextStyle(color: Colors.white)),
              ),
          ],
        )
            : Column(
          children: [
            Expanded(
              child: Markdown(
                data: widget.parsedData[0],
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 16, height: 1.5),
                  blockquote: const TextStyle(color: Colors.blue),
                  code: const TextStyle(
                      color: Colors.red,
                      backgroundColor: Colors.black12),
                ),
              )
            ),
              ElevatedButton(
                onPressed: () => _exportToFile(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue),
                child: const Text('Export to File',
                    style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ): const Center(child: Text("Response Error Please Try Again...", style: TextStyle(color: Colors.red),),)
    );
  }
}