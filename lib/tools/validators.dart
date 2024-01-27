String? validateAmount(value) {
  if (value == null || value.isEmpty) {
    return "Please enter an amount";
  } else if (double.tryParse(value) == null && value != "-") {
    return "Please enter a valid amount";
  }
  double intValue = double.parse(value);
  if (intValue > 100000000) {
    return "No way you spent that much money";
  }
  return null;
}

String? validateTitle(value) {
  if (value == null || value.isEmpty) {
    return "Please enter a title";
  } else if (value.length > 50) {
    return "Title must be less than 50 characters";
  }
  return null;
}