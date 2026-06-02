import '../models/user_model.dart';
import '../services/local_storage_service.dart';

abstract class AuthRepository {
  Future<User> login(String email, String password);
  Future<void> logout();
  User? getCurrentUser();
}

class MockAuthRepository implements AuthRepository {
  final LocalStorageService _storage;
  User? _currentUser;

  MockAuthRepository(this._storage) {
    _currentUser = _storage.getUser();
  }

  @override
  User? getCurrentUser() => _currentUser;

  @override
  Future<User> login(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Basic Input Validation
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw Exception('Email or mobile number cannot be empty.');
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final isMobile = RegExp(r'^[0-9+()-\s]{8,15}$');

    if (!emailRegex.hasMatch(trimmedEmail) && !isMobile.hasMatch(trimmedEmail)) {
      throw Exception('Please enter a valid email address or phone number.');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters long.');
    }

    // Success Mock Response
    final user = User(
      id: 'usr_98324',
      email: trimmedEmail,
      name: trimmedEmail.split('@')[0].toUpperCase(),
      token: 'jwt_mock_token_xyz_12345',
    );

    _currentUser = user;
    await _storage.saveUser(user);
    return user;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
    await _storage.clearUser();
  }
}
