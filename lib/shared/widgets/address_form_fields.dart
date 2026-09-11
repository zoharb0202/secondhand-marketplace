import 'package:flutter/material.dart';
import '../../core/services/location_service.dart';

class AddressFormControllers {
  final TextEditingController label;
  final TextEditingController street;
  final TextEditingController city;
  final TextEditingController apartment;
  final TextEditingController floor;
  final TextEditingController instructions;

  AddressFormControllers({String initialLabel = 'בית'})
    : label = TextEditingController(text: initialLabel),
      street = TextEditingController(),
      city = TextEditingController(),
      apartment = TextEditingController(),
      floor = TextEditingController(),
      instructions = TextEditingController();

  void dispose() {
    label.dispose();
    street.dispose();
    city.dispose();
    apartment.dispose();
    floor.dispose();
    instructions.dispose();
  }
}

class AddressFormFields extends StatelessWidget {
  final AddressFormControllers controllers;

  const AddressFormFields({super.key, required this.controllers});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: controllers.label,
          decoration: const InputDecoration(
            labelText: 'שם הכתובת *',
            hintText: 'לדוגמה: בית, עבודה',
          ),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'נא למלא שדה זה' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controllers.street,
          decoration: const InputDecoration(labelText: 'רחוב ומספר *'),
          validator: AddressValidation.validateStreet,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controllers.city,
          decoration: const InputDecoration(labelText: 'עיר *'),
          validator: (value) => (value == null || value.trim().length < 2)
              ? 'נא להזין שם עיר תקין'
              : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controllers.apartment,
                decoration: const InputDecoration(labelText: 'דירה'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controllers.floor,
                decoration: const InputDecoration(labelText: 'קומה'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controllers.instructions,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'הערות לכתובת (אופציונלי)',
            hintText: 'קוד כניסה, קומה, הערות לאיסוף...',
          ),
        ),
      ],
    );
  }
}
