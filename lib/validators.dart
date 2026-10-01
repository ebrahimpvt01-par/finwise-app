String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Password must contain at least one capital letter';
  }
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/~`;]').hasMatch(value)) {
    return 'Password must contain at least one special character';
  }
  return null;
}