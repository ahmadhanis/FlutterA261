import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user_model.dart';

class DatabaseControllerException implements Exception {
  const DatabaseControllerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sends registration data to the PHP API and returns the created user.
class DatabaseController {
  DatabaseController({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<UserModel> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // Send the form fields to the PHP API.
      final response = await _client
          .post(
            Uri.parse(
              '${ApiConfig.serverIpAddress}/budgetplus/registration.php',
            ),
            body: {
              'name': name.trim(),
              'email': email.trim(),
              'password': password,
            },
          )
          .timeout(const Duration(seconds: 15));

      // PHP returns JSON, so convert the response text into a Dart map.
      final result = jsonDecode(response.body);
      if (result is! Map<String, dynamic>) {
        throw const DatabaseControllerException(
          'The server returned an invalid response.',
        );
      }

      // Show the error message sent by PHP when registration failed.
      if (response.statusCode != 201 || result['success'] != true) {
        throw DatabaseControllerException(
          result['message']?.toString() ?? 'Registration failed.',
        );
      }

      // Convert the returned account data into the app's UserModel.
      final userData = result['user'];
      if (userData is! Map<String, dynamic>) {
        throw const DatabaseControllerException(
          'The server did not return account details.',
        );
      }

      return UserModel.fromJson(userData);
    } catch (error) {
      // Keep useful PHP validation errors. Give other errors one clear message.
      if (error is DatabaseControllerException) rethrow;

      throw const DatabaseControllerException(
        'Could not complete registration. Check that Apache is running and the '
        'server address is correct.',
      );
    }
  }

  void dispose() => _client.close();
}
