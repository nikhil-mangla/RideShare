import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Place {
  String? streetNumber;
  String? street;
  String? city;
  String? state;
  String? postalCode;

  Place({
    this.streetNumber,
    this.street,
    this.city,
    this.state,
    this.postalCode,
  });

  @override
  String toString() {
    return '$streetNumber, $street, $city, $state, $postalCode';
  }
}

class Suggestion {
  final String placeId;
  final String description;

  Suggestion(this.placeId, this.description);

  @override
  String toString() {
    return 'Suggestion(description: $description, placeId: $placeId)';
  }
}

class PlaceApiProvider {
  final Client client = Client();
  final String sessionToken;
  final String? apiKey;

  PlaceApiProvider(this.sessionToken)
      : apiKey = dotenv.env['API_KEY'] {
    if (apiKey == null) {
      throw Exception('API_KEY is not set in .env file');
    }
  }

  Future<List<Suggestion>> fetchSuggestions(
      String input, String lang, String country) async {
    try {
      final request = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&types=address&language=$lang&components=country:$country&key=$apiKey&sessiontoken=$sessionToken');
      final response = await client.get(request);

      debugPrint('API Request: $request');
      debugPrint('API Response: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'OK') {
          return result['predictions']
              .map<Suggestion>(
                  (p) => Suggestion(p['place_id'], p['description']))
              .toList();
        }
        if (result['status'] == 'ZERO_RESULTS') {
          return [];
        }
        if (result['status'] == 'OVER_QUERY_LIMIT') {
          await Future.delayed(Duration(seconds: 1));
          return fetchSuggestions(input, lang, country);
        }
        throw Exception(result['error_message']);
      } else {
        throw Exception('Failed to fetch suggestion: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
      rethrow; 
    }
  }

  Future<Place> getPlaceDetailFromId(String placeId) async {
    try {
      final request = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=address_component&key=$apiKey&sessiontoken=$sessionToken');
      final response = await client.get(request);

      debugPrint('Place Details Response: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'OK') {
          final components =
              result['result']['address_components'] as List<dynamic>;
          final place = Place();
          for (var c in components) {
            final List type = c['types'];
            if (type.contains('street_number')) {
              place.streetNumber = c['long_name'];
            }
            if (type.contains('route')) {
              place.street = c['long_name'];
            }
            if (type.contains('locality')) {
              place.city = c['long_name'];
            }
            if (type.contains('administrative_area_level_1')) {
              place.state = c['long_name'];
            }
            if (type.contains('postal_code')) {
              place.postalCode = c['long_name'];
            }
          }
          return place;
        }
        throw Exception(result['error_message']);
      } else {
        throw Exception('Failed to fetch place details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching place details: $e');
      return Place(); // Return empty Place on error
    }
  }
}