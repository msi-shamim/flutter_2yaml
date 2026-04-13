/// A plain Dart class — not a widget. Should be skipped by the analyzer.
class UserRepository {
  final String baseUrl;

  UserRepository({required this.baseUrl});

  Future<void> fetchUser(String id) async {
    // fetch logic
  }
}
