import 'package:rideshare/providers/place_api_provider.dart';
import 'package:rideshare/widgets/address_search.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:tuple/tuple.dart';

class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  _AddressSearchScreenState createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _controller = TextEditingController();
  String _streetNumber = '';
  String _street = '';
  String _city = '';
  String _province = '';
  String _postalCode = '';
  bool _isSaveLoading = false;
  bool _isLocationLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Fetch current location using Geolocator and convert to address using Geocoding
  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        setState(() {
          _isLocationLoading = false;
        });
        return;
      }

      // Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          setState(() {
            _isLocationLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location permission permanently denied')),
        );
        setState(() {
          _isLocationLoading = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Reverse geocode to get address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      Placemark place = placemarks[0];

      // Construct a full address string
      String fullAddress = [
        place.subThoroughfare ?? '',
        place.thoroughfare ?? '',
        place.locality ?? '',
        place.administrativeArea ?? '',
        place.postalCode ?? '',
      ].where((e) => e.isNotEmpty).join(', ');

      // Update state with address details
      setState(() {
        _controller.text = fullAddress;
        _streetNumber = place.subThoroughfare ?? '';
        _street = place.thoroughfare ?? '';
        _city = place.locality ?? '';
        _province = place.administrativeArea ?? '';
        _postalCode = place.postalCode ?? '';
        _isLocationLoading = false;
      });

      //  setState(() {
      //   _controller.text = "Bennett University";
      //   _streetNumber = "Plot 8-11";
      //   _street = "Techzone 2";
      //   _city = "Greater Noida";
      //   _province = "Uttar Pradesh";
      //   _postalCode = "201301";
      //   _isLocationLoading = false;
      // });
    } catch (e) {
      debugPrint('Error fetching location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location: $e')),
      );
      setState(() {
        _isLocationLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Address'),
      ),
      body: Container(
        margin: const EdgeInsets.only(left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _controller,
                readOnly: true,
                onTap: () async {
                  // Generate a new token for address search
                  final sessionToken = const Uuid().v4();
                  final Suggestion? result = await showSearch(
                    context: context,
                    delegate: AddressSearch(sessionToken),
                  );
                  if (result != null) {
                    final placeDetails = await PlaceApiProvider(sessionToken)
                        .getPlaceDetailFromId(result.placeId);
                    setState(() {
                      _controller.text = result.description;
                      _streetNumber = placeDetails.streetNumber ?? '';
                      _street = placeDetails.street ?? '';
                      _city = placeDetails.city ?? '';
                      _province = placeDetails.province ?? '';
                      _postalCode = placeDetails.postalCode ?? '';
                    });
                  }
                },
                decoration: const InputDecoration(
                  icon: Icon(
                    Icons.search,
                    color: Colors.black,
                  ),
                  hintText: "Enter your address",
                  border: UnderlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            Text('Street Number: $_streetNumber'),
            Text('Street: $_street'),
            Text('City: $_city'),
            Text('Province: $_province'),
            Text('Postal Code: $_postalCode'),
            const SizedBox(height: 20.0),
            Center(
              child: Column(
                children: [
                  _isLocationLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _fetchCurrentLocation,
                          child: const Text('Get Current Location'),
                        ),
                  const SizedBox(height: 10.0),
                  _isSaveLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: () async {
                            if (_controller.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Please enter or fetch an address'),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _isSaveLoading = true;
                            });
                            try {
                              List<Location> locations =
                                  await locationFromAddress(_controller.text);
                              final Tuple2<String, LatLng> text2location =
                                  Tuple2(
                                _controller.text,
                                LatLng(
                                  locations.first.latitude,
                                  locations.first.longitude,
                                ),
                              );
                              setState(() {
                                _isSaveLoading = false;
                              });
                              Navigator.pop(context, text2location);
                            } catch (e) {
                              debugPrint('Error saving address: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error saving address: $e'),
                                ),
                              );
                              setState(() {
                                _isSaveLoading = false;
                              });
                            }
                          },
                          child: const Text('Save'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
