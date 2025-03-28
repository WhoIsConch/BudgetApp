/*
  I have all of these in a separate file because I thought I was going to 
  end up using them in multiple places. It turns out, I wasn't. At least
  not for now. At least it's good organization, right?
*/

import 'package:flutter/services.dart';

String? validateAmount(value) {
  /*
  Used in a TextFormField, validateAmount ensures only positive numbers can be
  input in a text field. DecimalTextInputFormatter is also typically used with
  this validator which generally makes this validator useless, but if someone
  bypasses the input formatter somehow, this is a reasonable failsafe. 
  */
  double? amount = double.tryParse(value);

  if ([null, 0].contains(amount)) {
    return "Please enter a valid amount";
  }

  // Make sure the amount entered isn't too small or too high
  if (amount! < 0) {
    return "Please enter a positive amount";
  } else if (amount > 100000000) {
    // Enforce a hard limit because it would probably mess up the UI to put in a
    // number too big
    // If some hyper rich guy likes using my app for some reason and requests I
    // allow him to input transactions that are more than 100 million dollars
    // I might fix it
    return "No way you have that much money";
  }
  return null;
}

String? validateTitle(value) {
  /* 
  Ensure the transaction title input by a user is less than the maximum length.
  Also makes sure the title isn't empty. 
  */
  if (value == null || value.isEmpty) {
    return "Please enter a title";
  } else if (value.length > 50) {
    return "Title must be less than 50 characters";
  }
  return null;
}

class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // The following regex ensures the number input is a string that can only
    // contain digits and a single dot. If there is a dot present, it only
    // allows up to two digits after it.
    final RegExp regex = RegExp(r'^\d+\.?\d{0,2}$');

    if (regex.hasMatch(text)) {
      // A regex match would mean the number is a valid number formatted as
      // `xxx.xx`, `xxx`, or `xxx.x`, or similar.
      if (newValue.text[0] == "0" ||
          (newValue.text[0] == "0" && oldValue.text == "0")) {
        return TextEditingValue(text: newValue.text.substring(1));
      }
      return newValue;
    } else if (newValue.text.isEmpty) {
      return const TextEditingValue(text: "0");
    } else {
      return oldValue;
    }
  }
}
