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

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  void _parseData() {
    final rawString = widget.parsedData[0] as String;

    // Check if the text is Markdown
    if (_isMarkdownText(rawString)) {
      _isMarkdown = true;
    } else {
      _parseCsvTable(rawString);
    }
  }

  bool _isMarkdownText(String text) {
    // Detect Markdown by checking common Markdown syntax
    const markdownKeywords = [
      '#',
      '-',
      '*',
      '`',
      '[',
      ']',
      '(',
      ')',
      '```',
      '**',
      '_'
    ];
    return markdownKeywords.any((keyword) => text.contains(keyword));
  }

  void _parseCsvTable(String rawString) {
    List<String> lines = rawString.split('\n');
    List<dynamic> headers = [];
    List<Map<dynamic, dynamic>> table = [];
    bool foundHeader = false;

    for (String line in lines) {
      line = line.trim();

      if (line.isEmpty ||
          line.startsWith('---') ||
          line.startsWith('Type: Table') ||
          line.startsWith('```csv') ||
          line.startsWith('```')) {
        continue;
      }

      if (!foundHeader && line.contains(',')) {
        headers = _parseCsvRow(line);
        foundHeader = true;
        continue;
      }

      if (foundHeader && line.contains(',')) {
        List<dynamic> row = _parseCsvRow(line);
        Map<dynamic, dynamic> rowData = {};
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
    return matches
        .map((match) => match.group(1) ?? match.group(2) ?? "")
        .toList();
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
    } catch (e) {
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
    } catch (e) {
      _showSnackBar('Error saving file: $e');
    }
  }


  void _showSnackBar(String message) {
    if (_scaffoldKey.currentContext == null) return;
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isMarkdown
            ? Column(
                children: [
                  Expanded(
                    child: _isMarkdown
                        ? Markdown(
                            data: widget.parsedData[0],
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(fontSize: 16, height: 1.5),
                              blockquote: const TextStyle(color: Colors.blue),
                              code: const TextStyle(
                                  color: Colors.red,
                                  backgroundColor: Colors.black12),
                            ),
                          )
                        : const Center(
                            child: Text(
                              "No Data",
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                  ),
                  if (_isMarkdown)
                    ElevatedButton(
                      onPressed: () => _exportToFile(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                      child: const Text('Export to File',
                          style: TextStyle(color: Colors.white)),
                    ),
                ],
              )
            : Column(
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
              ),
      ),
    );
  }
}
