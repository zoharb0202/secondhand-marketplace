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
      final callable = functions.httpsCallable(
        'seedDemoCatalog',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      var remaining = 1;
      var rounds = 0;
      while (remaining > 0 && rounds < 8) {
        rounds++;
        final result = await callable.call();
        final data = Map<String, dynamic>.from(result.data as Map);
        remaining = (data['remaining'] as num?)?.toInt() ?? 0;
        if (!mounted) return;
        setState(() {
          _result =
              '${data['products']} מוצרים, ${data['sellers']} מוכרים · '
              '${remaining > 0 ? 'עוד $remaining תמונות בטעינה…' : 'כל התמונות נטענו'}';
        });
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
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
              : const Text('טען את קטלוג הדמו'),
        ),
        if (_result != null)
          Padding(padding: const EdgeInsets.all(8.0), child: Text(_result!)),
      ],
    );
  }
}
