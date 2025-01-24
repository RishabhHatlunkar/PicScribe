import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixelsheet/providers/providers.dart';

class ApiKeyDialog extends ConsumerStatefulWidget {
  final Function(String) onApiKeySaved;

  const ApiKeyDialog({Key? key, required this.onApiKeySaved}) : super(key: key);

  @override
  ConsumerState<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends ConsumerState<ApiKeyDialog> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureText = true;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter Gemini API Key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureText,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
              errorText: _errorMessage,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            String apiKey = _apiKeyController.text.trim();
            if (_isValidApiKey(apiKey)) {
              widget.onApiKeySaved(apiKey);
              Navigator.pop(context);
            } else {
              setState(() {
                _errorMessage = 'Invalid API Key format.';
              });
            }
          },
          child: Text('Save'),
        ),
      ],
    );
  }

  bool _isValidApiKey(String apiKey) {
    return apiKey.isNotEmpty && apiKey.length > 30;
  }
}