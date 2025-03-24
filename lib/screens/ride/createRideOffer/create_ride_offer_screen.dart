import 'package:rideshare/models/ride_offer_model.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/providers/user_state.dart';
import 'package:rideshare/models/vehicle_model.dart';
import 'package:rideshare/screens/ride/createRideOffer/address_search_screen.dart';
import 'package:rideshare/screens/profile/add_vehicle_screen.dart';
import 'package:rideshare/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:geocoding/geocoding.dart';

// Define theme colors
const Color primaryPurple = Color(0xFF6A1B9A);
const Color lightPurple = Color(0xFF9C4DCC);
const Color accentPurple = Color(0xFFD1C4E9);
const Color backgroundWhite = Color(0xFFFAFAFA);

final List<String> weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class CreateRideOfferScreen extends StatefulWidget {
  final GlobalKey<RefreshIndicatorState>? refreshOffersIndicatorKey;

  const CreateRideOfferScreen({super.key, this.refreshOffersIndicatorKey});

  @override
  _CreateRideOfferScreenState createState() => _CreateRideOfferScreenState();
}

class _CreateRideOfferScreenState extends State<CreateRideOfferScreen> {
  TimeOfDay proposedLeaveTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay proposedBackTime = const TimeOfDay(hour: 17, minute: 0);
  List<int> proposedWeekdays = [1, 2, 3, 4, 5];

  // Driver location
  String? driverLocationName;
  LatLng? driverLocation;

  // Destination location
  String? destinationLocationName;
  LatLng? destinationLocation;

  double price = 0.0; // Dynamic price updated automatically
  VehicleModel? vehicle;
  String additionalDetails = '';
  bool isSubmitting = false;
  String? distance; // Store the calculated distance

  // For manually adding location
  final TextEditingController _manualLocationController = TextEditingController();
  final TextEditingController _manualDestinationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(); // Added for price display
  bool _showManualLocationInput = false;
  bool _showManualDestinationInput = false;

  @override
  void initState() {
    super.initState();
    _priceController.text = price.toStringAsFixed(2); // Initialize price display
  }

  @override
  void dispose() {
    _manualLocationController.dispose();
    _manualDestinationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _showTimePicker(bool forStart) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: forStart ? proposedLeaveTime : proposedBackTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      setState(() {
        if (forStart) {
          proposedLeaveTime = selectedTime;
        } else {
          proposedBackTime = selectedTime;
        }
        _updateDynamicPrice(); // Recalculate price when time changes
      });
    }
  }

  Future<Tuple2<String, LatLng>?> selectLocation() async {
    return await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressSearchScreen()),
    );
  }

  Future<void> _submitManualLocation(bool isDriverLocation) async {
    final text = isDriverLocation
        ? _manualLocationController.text
        : _manualDestinationController.text;

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name'), duration: Duration(seconds: 1)),
      );
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(text);
      if (locations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not found'), duration: Duration(seconds: 2)),
        );
        return;
      }

      final LatLng coordinate = LatLng(locations.first.latitude, locations.first.longitude);

      setState(() {
        if (isDriverLocation) {
          driverLocationName = text;
          driverLocation = coordinate;
          _showManualLocationInput = false;
          _manualLocationController.clear();
        } else {
          destinationLocationName = text;
          destinationLocation = coordinate;
          _showManualDestinationInput = false;
          _manualDestinationController.clear();
        }
        if (driverLocation != null && destinationLocation != null) {
          distance = Utils.getDistanceByTwoLocation(driverLocation!, destinationLocation!);
          print('Driver Location: ${driverLocation!.latitude}, ${driverLocation!.longitude}');
          print('Destination Location: ${destinationLocation!.latitude}, ${destinationLocation!.longitude}');
          print('Calculated Distance: $distance');
          _updateDynamicPrice(); // Update price when locations change
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location: $e'), duration: Duration(seconds: 2)),
      );
    }
  }

  // Dynamic pricing model
  void _updateDynamicPrice() {
    if (distance == null || driverLocation == null || destinationLocation == null) {
      setState(() {
        price = 0.0;
        _priceController.text = price.toStringAsFixed(2);
      });
      return;
    }

    // Extract distance value (e.g., "15.23 km" -> 15.23)
    double distanceKm = double.parse(distance!.split(' ')[0]);

    // Base price: $1 per km
    double basePrice = distanceKm * 1.0;

    // Time factor: Estimate duration (assume average speed of 40 km/h)
    double estimatedDurationHours = distanceKm / 40.0; // Time in hours
    double timeFactor = estimatedDurationHours * 10.0; // $10 per hour

    // Traffic factor: Simulate (1.0 = normal, 1.5 = heavy traffic)
    double trafficMultiplier = _getTrafficMultiplier();
    double trafficFactor = basePrice * (trafficMultiplier - 1.0);

    // Demand factor: Simulate (1.0 = normal, 2.0 = high demand)
    double demandMultiplier = _getDemandMultiplier();
    double demandFactor = basePrice * (demandMultiplier - 1.0);

    // Total price
    double dynamicPrice = basePrice + timeFactor + trafficFactor + demandFactor;
    dynamicPrice = dynamicPrice.clamp(5.0, 1000.0); // Min $5, Max $1000

    setState(() {
      price = dynamicPrice;
      _priceController.text = price.toStringAsFixed(2); // Update UI
    });

    print('Dynamic Price Breakdown:');
    print('Base Price: \$${basePrice.toStringAsFixed(2)}');
    print('Time Factor: \$${timeFactor.toStringAsFixed(2)}');
    print('Traffic Factor: \$${trafficFactor.toStringAsFixed(2)} (Multiplier: $trafficMultiplier)');
    print('Demand Factor: \$${demandFactor.toStringAsFixed(2)} (Multiplier: $demandMultiplier)');
    print('Total Price: \$${price.toStringAsFixed(2)}');
  }

  // Simulate traffic multiplier (replace with real API data later)
  double _getTrafficMultiplier() {
    // Placeholder: Assume heavier traffic during peak hours (7-9 AM, 5-7 PM)
    int hour = proposedLeaveTime.hour;
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      return 1.5; // Heavy traffic
    }
    return 1.0; // Normal traffic
  }

  // Simulate demand multiplier (replace with real backend data later)
  double _getDemandMultiplier() {
    // Placeholder: Higher demand during weekdays and peak hours
    bool isWeekday = proposedWeekdays.any((day) => day >= 1 && day <= 5);
    int hour = proposedLeaveTime.hour;
    if (isWeekday && ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19))) {
      return 1.8; // High demand
    }
    return 1.0; // Normal demand
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final UserModel currentUser = userState.currentUser!;

    if (currentUser.vehicle != null && vehicle == null) {
      setState(() {
        vehicle = currentUser.vehicle;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Ride Offer'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9C27B0), Color(0xFF6200EE)],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: backgroundWhite,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Selection Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Schedule',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryPurple),
                        ),
                        const SizedBox(height: 16.0),
                        Row(
                          children: [
                            const Icon(Icons.departure_board, color: lightPurple),
                            const SizedBox(width: 8.0),
                            const Text('Departure:'),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentPurple,
                                  foregroundColor: primaryPurple,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () => _showTimePicker(true),
                                child: Text(proposedLeaveTime.format(context)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          children: [
                            const Icon(Icons.keyboard_return, color: lightPurple),
                            const SizedBox(width: 8.0),
                            const Text('Return:'),
                            const SizedBox(width: 24.0),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentPurple,
                                  foregroundColor: primaryPurple,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () => _showTimePicker(false),
                                child: Text(proposedBackTime.format(context)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        const Text(
                          'Days of Week',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryPurple),
                        ),
                        const SizedBox(height: 8.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [for (int i = 0; i < 7; i++) _buildDaySelector(i)],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),

                // Location Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Locations',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryPurple),
                        ),
                        const SizedBox(height: 16.0),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: lightPurple),
                            const SizedBox(width: 8.0),
                            const Text('Pickup Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        if (_showManualLocationInput)
                          _buildManualLocationInput(true)
                        else if (driverLocationName == null)
                          _buildLocationSelectionButtons(true)
                        else
                          _buildSelectedLocationDisplay(driverLocationName!, true),
                        const SizedBox(height: 16.0),
                        const Divider(),
                        const SizedBox(height: 16.0),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red),
                            const SizedBox(width: 8.0),
                            const Text('Destination:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        if (_showManualDestinationInput)
                          _buildManualLocationInput(false)
                        else if (destinationLocationName == null)
                          _buildLocationSelectionButtons(false)
                        else
                          _buildSelectedLocationDisplay(destinationLocationName!, false),
                        if (distance != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              'Distance: $distance',
                              style: const TextStyle(fontSize: 16, color: primaryPurple, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),

                // Vehicle and Price Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ride Details',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryPurple),
                        ),
                        const SizedBox(height: 16.0),
                        Row(
                          children: [
                            const Icon(Icons.directions_car, color: lightPurple),
                            const SizedBox(width: 8.0),
                            const Text('Vehicle:'),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        vehicle == null
                            ? ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add Vehicle'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () => {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => AddVehiclePage(vehicle: currentUser.vehicle)),
                                  ),
                                  setState(() {
                                    vehicle = currentUser.vehicle;
                                  }),
                                },
                              )
                            : Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[100]),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Utils.getColorFromValue(vehicle!.color!),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(vehicle!.fullName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => AddVehiclePage(vehicle: vehicle)),
                                        ),
                                      },
                                    ),
                                  ],
                                ),
                              ),
                        const SizedBox(height: 16.0),
                        const Divider(),
                        const SizedBox(height: 16.0),
                        Row(
                          children: [
                           
                            const SizedBox(width: 8.0),
                            const Text('Price per ride:'),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        TextFormField(
                          controller: _priceController, 
                          decoration: InputDecoration(
                            
                            
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d{0,2})?$'))],
                          onChanged: (value) {
                            setState(() {
                              price = double.tryParse(value) ?? price; // Allow manual override
                            });
                          },
                        ),
                        const SizedBox(height: 16.0),
                        const Divider(),
                        const SizedBox(height: 16.0),
                        Row(
                          children: [
                            const Icon(Icons.description, color: lightPurple),
                            const SizedBox(width: 8.0),
                            const Text('Additional Details:'),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        TextFormField(
                          decoration: InputDecoration(
                            hintText: 'Any other information riders should know...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          maxLines: 3,
                          onChanged: (value) {
                            setState(() {
                              additionalDetails = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: isSubmitting
                      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryPurple)))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            elevation: 3,
                          ),
                          onPressed: () async {
                            setState(() {
                              isSubmitting = true;
                            });

                            if (driverLocationName == null || driverLocation == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select your pickup location'), backgroundColor: Colors.red),
                              );
                              setState(() {
                                isSubmitting = false;
                              });
                              return;
                            }

                            if (destinationLocationName == null || destinationLocation == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select your destination'), backgroundColor: Colors.red),
                              );
                              setState(() {
                                isSubmitting = false;
                              });
                              return;
                            }

                            if (vehicle == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select your vehicle'), backgroundColor: Colors.red),
                              );
                              setState(() {
                                isSubmitting = false;
                              });
                              return;
                            }

                            final rideOffer = RideOfferModel(
                              createdAt: DateTime.now(),
                              driverId: currentUser.email,
                              proposedLeaveTime: proposedLeaveTime,
                              proposedBackTime: proposedBackTime,
                              proposedWeekdays: proposedWeekdays,
                              driverLocationName: driverLocationName!,
                              driverLocation: driverLocation!,
                              destinationLocationName: destinationLocationName!,
                              destinationLocation: destinationLocation!,
                              vehicleId: vehicle!.id,
                              price: price,
                              additionalDetails: additionalDetails,
                            );

                            try {
                              await currentUser.createRideOffer(userState, rideOffer);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ride offer created successfully!'), backgroundColor: Colors.green),
                              );
                              Navigator.pop(context);
                              widget.refreshOffersIndicatorKey?.currentState?.show();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error creating ride offer: $e'), backgroundColor: Colors.red),
                              );
                              setState(() {
                                isSubmitting = false;
                              });
                            }
                          },
                          child: const Text('CREATE RIDE OFFER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector(int dayIndex) {
    final isSelected = proposedWeekdays.contains(dayIndex);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (proposedWeekdays.length > 1) {
              proposedWeekdays.remove(dayIndex);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('At least one day must be selected'), duration: Duration(seconds: 1)),
              );
            }
          } else {
            proposedWeekdays.add(dayIndex);
          }
          _updateDynamicPrice(); // Recalculate price when days change
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? primaryPurple : Colors.transparent,
          border: Border.all(color: isSelected ? primaryPurple : Colors.grey, width: 1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            weekdays[dayIndex][0],
            style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelectionButtons(bool isDriverLocation) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.map),
            label: const Text('Select on Map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              selectLocation().then((selectedLocation) {
                if (selectedLocation != null) {
                  setState(() {
                    if (isDriverLocation) {
                      driverLocationName = selectedLocation.item1;
                      driverLocation = selectedLocation.item2;
                    } else {
                      destinationLocationName = selectedLocation.item1;
                      destinationLocation = selectedLocation.item2;
                    }
                    if (driverLocation != null && destinationLocation != null) {
                      distance = Utils.getDistanceByTwoLocation(driverLocation!, destinationLocation!);
                      print('Driver Location: ${driverLocation!.latitude}, ${driverLocation!.longitude}');
                      print('Destination Location: ${destinationLocation!.latitude}, ${destinationLocation!.longitude}');
                      print('Calculated Distance: $distance');
                      _updateDynamicPrice(); // Update price when locations change
                    }
                  });
                }
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit_location_alt),
            label: const Text('Enter Manually'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: primaryPurple)),
            ),
            onPressed: () {
              setState(() {
                if (isDriverLocation) {
                  _showManualLocationInput = true;
                } else {
                  _showManualDestinationInput = true;
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildManualLocationInput(bool isDriverLocation) {
    return Column(
      children: [
        TextField(
          controller: isDriverLocation ? _manualLocationController : _manualDestinationController,
          decoration: InputDecoration(
            hintText: isDriverLocation ? 'Enter pickup location name' : 'Enter destination name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[100],
          ),
          autofocus: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.red)),
                ),
                onPressed: () {
                  setState(() {
                    if (isDriverLocation) {
                      _showManualLocationInput = false;
                      _manualLocationController.clear();
                    } else {
                      _showManualDestinationInput = false;
                      _manualDestinationController.clear();
                    }
                  });
                },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => _submitManualLocation(isDriverLocation),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedLocationDisplay(String locationName, bool isDriverLocation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[100]),
      child: Row(
        children: [
          Icon(Icons.location_on, color: isDriverLocation ? lightPurple : Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(locationName, style: const TextStyle(fontWeight: FontWeight.w500))),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () {
              selectLocation().then((selectedLocation) {
                if (selectedLocation != null) {
                  setState(() {
                    if (isDriverLocation) {
                      driverLocationName = selectedLocation.item1;
                      driverLocation = selectedLocation.item2;
                    } else {
                      destinationLocationName = selectedLocation.item1;
                      destinationLocation = selectedLocation.item2;
                    }
                    if (driverLocation != null && destinationLocation != null) {
                      distance = Utils.getDistanceByTwoLocation(driverLocation!, destinationLocation!);
                      print('Driver Location: ${driverLocation!.latitude}, ${driverLocation!.longitude}');
                      print('Destination Location: ${destinationLocation!.latitude}, ${destinationLocation!.longitude}');
                      print('Calculated Distance: $distance');
                      _updateDynamicPrice(); // Update price when locations change
                    }
                  });
                }
              });
            },
          ),
        ],
      ),
    );
  }
}