import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AddSampleProductsButton extends StatefulWidget {
  const AddSampleProductsButton({super.key});

  @override
  State<AddSampleProductsButton> createState() =>
      _AddSampleProductsButtonState();
}

class _AddSampleProductsButtonState extends State<AddSampleProductsButton> {
  bool _isLoading = false;
  String? _result;

  Future<void> _addProducts() async {
    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('addSampleProducts');
      final result = await callable.call();

      final data = result.data as Map<String, dynamic>;
      setState(() {
        _result = 'הצלחה! הועלו ${data['uploadCount']} מוצרים';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'שגיאה: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _addProducts,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('הוסף מוצרים לדוגמא (200+)'),
        ),
        if (_result != null)
          Padding(padding: const EdgeInsets.all(8.0), child: Text(_result!)),
      ],
    );
  }
}
