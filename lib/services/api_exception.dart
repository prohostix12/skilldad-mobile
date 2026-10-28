/// Thrown by the service layer with a message straight from the API
/// response (e.g. "Invalid email or password", "User already exists") so
/// the UI can show the platform's own error text rather than a generic one.
class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
