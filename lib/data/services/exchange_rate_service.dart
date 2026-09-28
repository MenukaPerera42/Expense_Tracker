import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/currency_config.dart';

final exchangeRatesProvider = FutureProvider<Map<String, double>>((ref) async {
  try {
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse('https://open.er-api.com/v6/latest/LKR'));
    final response = await request.close();
    
    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      
      if (data['result'] == 'success') {
        final rates = data['rates'] as Map<String, dynamic>;
        return rates.map((key, value) => MapEntry(key, (value as num).toDouble()));
      }
    }
  } catch (e) {
    // Fallback to offline/hardcoded rates if API fails
  }
  
  // Fallback rates if API fails (approximate relative to 1 LKR)
  return {
    'LKR': 1.0,
    'USD': 0.003,     // 1 USD ~ 333 LKR
    'EUR': 0.0028,    // 1 EUR ~ 357 LKR
    'GBP': 0.0024,    // 1 GBP ~ 416 LKR
    'INR': 0.25,      // 1 INR ~ 4 LKR
  };
});
