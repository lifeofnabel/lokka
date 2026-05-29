class ValidationUtils {
  const ValidationUtils._();

  static bool isNotBlank(String value) => value.trim().isNotEmpty;
}
