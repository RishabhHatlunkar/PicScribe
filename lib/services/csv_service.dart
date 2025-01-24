import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';

class CsvService {
  static Future<String> exportToCsv(List<List<dynamic>> data, String baseFileName) async {
    String csv = const ListToCsvConverter().convert(data);
       // Convert String to Uint8List
        final Uint8List bytes = Uint8List.fromList(csv.codeUnits);

    final String? outputFile = await FileSaver.instance.saveFile(
          name: '$baseFileName.csv',
           bytes: bytes,
          ext: 'csv',
          mimeType: MimeType.csv,
        );
     if(outputFile == null)
       {
         throw Exception("No file path was provided.");
       }
     final File file = File(outputFile);
     await file.writeAsString(csv);

        return 'CSV file saved successfully to $outputFile';
    }
}