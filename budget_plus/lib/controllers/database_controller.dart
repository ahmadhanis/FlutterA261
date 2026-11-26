import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/budget_entry_model.dart';
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

  Future<UserModel> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      // Send the login form fields to the PHP API.
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.serverIpAddress}/budgetplus/login.php'),
            body: {'email': email.trim(), 'password': password},
          )
          .timeout(const Duration(seconds: 15));

      // PHP returns JSON with a success message and account details.
      final result = jsonDecode(response.body);
      if (result is! Map<String, dynamic>) {
        throw const DatabaseControllerException(
          'The server returned an invalid response.',
        );
      }

      if (response.statusCode != 200 || result['success'] != true) {
        throw DatabaseControllerException(
          result['message']?.toString() ?? 'Login failed.',
        );
      }

      final userData = result['user'];
      if (userData is! Map<String, dynamic>) {
        throw const DatabaseControllerException(
          'The server did not return account details.',
        );
      }

      return UserModel.fromJson(userData);
    } catch (error) {
      if (error is DatabaseControllerException) rethrow;

      throw const DatabaseControllerException(
        'Could not complete login. Check that Apache is running and the server '
        'address is correct.',
      );
    }
  }

  Future<void> addBudgetEntry({
    required int userId,
    required String title,
    required String type,
    required String category,
    required double amount,
    required DateTime transactionDate,
    required String description,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      // Multipart form data lets PHP receive both text fields and an image.
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.serverIpAddress}/budgetplus/addbudget.php'),
      );
      request.fields.addAll({
        'user_id': userId.toString(),
        'title': title.trim(),
        'type': type,
        'category': category,
        'amount': amount.toStringAsFixed(2),
        'transaction_date': _formatDateForApi(transactionDate),
        'description': description.trim(),
      });

      if (imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: imageName ?? 'receipt.jpg',
          ),
        );
      }

      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final result = jsonDecode(response.body);

      if (result is! Map<String, dynamic>) {
        throw const DatabaseControllerException(
          'The server returned an invalid response.',
        );
      }

      if (response.statusCode != 201 || result['success'] != true) {
        throw DatabaseControllerException(
          result['message']?.toString() ?? 'Could not save the entry.',
        );
      }
    } catch (error) {
      if (error is DatabaseControllerException) rethrow;

      throw const DatabaseControllerException(
        'Could not save the entry. Check that Apache is running and the server '
        'address is correct.',
      );
    }
  }

  Future<List<BudgetEntryModel>> getBudgetEntries(int userId) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.serverIpAddress}/budgetplus/getbudgetentries.php',
      ).replace(queryParameters: {'user_id': userId.toString()});
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      final result = jsonDecode(response.body);

      if (result is! Map<String, dynamic>) {
        throw const DatabaseControllerException(
          'The server returned an invalid response.',
        );
      }

      if (response.statusCode != 200 || result['success'] != true) {
        throw DatabaseControllerException(
          result['message']?.toString() ?? 'Could not load budget entries.',
        );
      }

      final entries = result['entries'];
      if (entries is! List) {
        throw const DatabaseControllerException(
          'The server returned an invalid entry list.',
        );
      }

      return entries
          .map(
            (entry) => BudgetEntryModel.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
    } catch (error) {
      if (error is DatabaseControllerException) rethrow;

      throw const DatabaseControllerException(
        'Could not load budget entries. Check that Apache is running and the '
        'server address is correct.',
      );
    }
  }

  Future<void> updateBudgetEntry({
    required int entryId,
    required int userId,
    required String title,
    required String type,
    required String category,
    required double amount,
    required DateTime transactionDate,
    required String description,
    required bool removeImage,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.serverIpAddress}/budgetplus/updatebudget.php'),
      );
      request.fields.addAll({
        'entry_id': entryId.toString(),
        'user_id': userId.toString(),
        'title': title.trim(),
        'type': type,
        'category': category,
        'amount': amount.toStringAsFixed(2),
        'transaction_date': _formatDateForApi(transactionDate),
        'description': description.trim(),
        'remove_image': removeImage ? '1' : '0',
      });

      if (imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: imageName ?? 'receipt.jpg',
          ),
        );
      }

      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final result = jsonDecode(response.body);

      if (result is! Map<String, dynamic>) {
        throw const DatabaseControllerException(
          'The server returned an invalid response.',
        );
      }

      if (response.statusCode != 200 || result['success'] != true) {
        throw DatabaseControllerException(
          result['message']?.toString() ?? 'Could not update the entry.',
        );
      }
    } catch (error) {
      if (error is DatabaseControllerException) rethrow;

      throw const DatabaseControllerException(
        'Could not update the entry. Check that Apache is running and the '
        'server address is correct.',
      );
    }
  }

  Future<void> deleteBudgetEntry({
    required int entryId,
    required int userId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(
              '${ApiConfig.serverIpAddress}/budgetplus/deletebudget.php',
            ),
            body: {
              'entry_id': entryId.toString(),
              'user_id': userId.toString(),
            },
          )
          .timeout(const Duration(seconds: 15));
      final result = jsonDecode(response.body);

      if (result is! Map<String, dynamic>) {
        throw const DatabaseControllerException(
          'The server returned an invalid response.',
        );
      }

      if (response.statusCode != 200 || result['success'] != true) {
        throw DatabaseControllerException(
          result['message']?.toString() ?? 'Could not delete the entry.',
        );
      }
    } catch (error) {
      if (error is DatabaseControllerException) rethrow;

      throw const DatabaseControllerException(
        'Could not delete the entry. Check that Apache is running and the '
        'server address is correct.',
      );
    }
  }

  void dispose() => _client.close();
}

String _formatDateForApi(DateTime dateTime) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');

  return '${dateTime.year}-${twoDigits(dateTime.month)}-'
      '${twoDigits(dateTime.day)} ${twoDigits(dateTime.hour)}:'
      '${twoDigits(dateTime.minute)}:${twoDigits(dateTime.second)}';
}
