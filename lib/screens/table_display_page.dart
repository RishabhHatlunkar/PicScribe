import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

class TableDisplayPage extends StatelessWidget {
  final List<dynamic> parsedData;
  final List<XFile> images;

  const TableDisplayPage(
      {Key? key, required this.parsedData, required this.images})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Extracted Data',
          style: TextStyle(color: Colors.blue),
        ),
      ),
      body: ListView.builder(
        itemCount: parsedData.length,
        itemBuilder: (context, index) {
          final item = parsedData[index];
          final type = item[0];
          final data = item[1];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.file(
                  File(images[index].path),
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              if (type == 'Table') ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: List<DataColumn>.generate(
                      data[0].length,
                          (int colIndex) => DataColumn(
                        label: Text(data[0][colIndex].toString()),
                      ),
                    ),
                    rows: List<DataRow>.generate(
                      data.length - 1,
                          (int rowIndex) => DataRow(
                        cells: List<DataCell>.generate(
                          data[0].length, // Use header row length for cell count
                              (int cellIndex) => DataCell(
                            Text(data[rowIndex + 1][cellIndex].toString()),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else if (type == 'Text') ...[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: MarkdownBody(data: data),
                ),
              ],
              const Divider(),
            ],
          );
        },
      ),
    );
  }
}