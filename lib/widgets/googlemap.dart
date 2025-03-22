import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> {
  late GoogleMapController mapController;
  LatLng? _currentLocation;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _checkLocationPermissions();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // Optionally animate camera to current location when map is created
    if (_currentLocation != null) {
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 16.0),
        ),
      );
    }
  }

  Future<void> _checkLocationPermissions() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location service is disabled.');
        return;
      }

      // Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission is denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission is permanently denied.');
        return;
      }

      // Get initial position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Set initial location
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      // Get address from coordinates
      _currentAddress = await _getAddressFromLatLng(_currentLocation!);

      // Listen to location updates
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _updateAddress(); // Update address when position changes
        });
        
        // Animate camera to new position
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentLocation!, zoom: 16.0),
          ),
        );
      });
    } catch (e) {
      debugPrint('Error while handling location: $e');
    }
  }

  Future<String> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      Placemark place = placemarks[0];
      return '${place.street}, ${place.locality}, ${place.country}';
    } catch (e) {
      debugPrint('Error getting address: $e');
      return 'Unknown Location';
    }
  }

  Future<void> _updateAddress() async {
    if (_currentLocation != null) {
      String newAddress = await _getAddressFromLatLng(_currentLocation!);
      setState(() {
        _currentAddress = newAddress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation!,
                    zoom: 16.0,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                // Adding a position indicator with address
                if (_currentAddress != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      color: Colors.white.withOpacity(0.8),
                      child: Text(
                        'Current Location: $_currentAddress',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}