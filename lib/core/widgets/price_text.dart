import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget priceText(
  double amount, {
  required TextStyle? style,
  TextAlign? textAlign,
  int decimals = 0,
  bool symbolFirst = false,
}) {
  final numeral = amount.toStringAsFixed(decimals);
  final symbolStyle = (style ?? const TextStyle()).copyWith(
    fontFamily: GoogleFonts.ibmPlexSansHebrew().fontFamily,
  );
  final numeralSpan = TextSpan(text: numeral, style: style);
  final symbolSpan = TextSpan(
    text: symbolFirst ? '₪' : ' ₪',
    style: symbolStyle,
  );
  return Text.rich(
    TextSpan(
      children: symbolFirst
          ? [symbolSpan, numeralSpan]
          : [numeralSpan, symbolSpan],
    ),
    textAlign: textAlign,
  );
}
