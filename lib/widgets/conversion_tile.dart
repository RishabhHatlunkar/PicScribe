import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pixelsheet/models/conversion_item.dart';

class ConversionTile extends StatelessWidget {
  final ConversionItem item;
  final VoidCallback onExport;

  const ConversionTile({Key? key, required this.item, required this.onExport})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Image Path: ${item.imagePath}'),
            Text('Extracted Text: ${item.extractedText}'),
            Text(
                'Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(item.timestamp)}'),
            ElevatedButton(
              onPressed: onExport,
              child: Text('Export to CSV'),
            ),
          ],
        ),
      ),
    );
  }
}