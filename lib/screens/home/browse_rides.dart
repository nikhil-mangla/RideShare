import 'package:flutter/material.dart';
import 'package:rideshare/providers/user_state.dart';
import 'package:rideshare/models/ride_offer_model.dart';
import 'package:rideshare/models/types/requested_offer_status.dart';
import 'package:rideshare/screens/ride/exploreRides/ride_offer_detail_screen.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class BrowseRides extends StatefulWidget {
  final UserState userState;
  final Function fetchAllOffers;
  final VoidCallback? onRideRequested;

  const BrowseRides({
    super.key,
    required this.userState,
    required this.fetchAllOffers,
    this.onRideRequested,
  });

  @override
  State<BrowseRides> createState() => _BrowseRidesState();
}

class _BrowseRidesState extends State<BrowseRides> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();
  List<RideOfferModel> matchingRides = [];
  bool isSearching = false;
  String? errorMessage;
  String? successMessage; 
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  Future<LatLng?> _getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
      return null;
    } catch (e) {
      setState(() {
        errorMessage = 'Error finding location: $e';
      });
      return null;
    }
  }

  double _calculateDistance(LatLng start1, LatLng end1, LatLng start2, LatLng end2) {
    final double startDistance = Geolocator.distanceBetween(
      start1.latitude,
      start1.longitude,
      start2.latitude,
      start2.longitude,
    ) / 1000;

    final double endDistance = Geolocator.distanceBetween(
      end1.latitude,
      end1.longitude,
      end2.latitude,
      end2.longitude,
    ) / 1000;

    return (startDistance + endDistance) / 2;
  }

  Future<void> searchRides() async {
    setState(() {
      isSearching = true;
      matchingRides.clear();
      errorMessage = null;
      successMessage = null; // Clear success message on new search
    });

    String startLocationText = _startController.text.trim();
    String dropLocationText = _dropController.text.trim();

    if (startLocationText.isEmpty || dropLocationText.isEmpty) {
      setState(() {
        errorMessage = 'Please enter both starting and dropping locations';
        isSearching = false;
      });
      return;
    }

    LatLng? startLatLng = await _getCoordinatesFromAddress(startLocationText);
    LatLng? dropLatLng = await _getCoordinatesFromAddress(dropLocationText);

    if (startLatLng == null || dropLatLng == null) {
      setState(() {
        errorMessage = 'Could not find one or both locations';
        isSearching = false;
      });
      return;
    }

    for (var offer in widget.userState.storedOffers.values) {
      if (offer.driverLocation == null || offer.destinationLocation == null) {
        continue;
      }

      double distance = _calculateDistance(
        startLatLng,
        dropLatLng,
        offer.driverLocation,
        offer.destinationLocation,
      );

      if (distance <= 5.0) {
        matchingRides.add(offer);
      }
    }

    setState(() => isSearching = false);
  }

  Future<void> _refreshRides() async {
    await widget.fetchAllOffers();
    if (_startController.text.isNotEmpty && _dropController.text.isNotEmpty) {
      await searchRides();
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _refreshRides,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _startController,
                decoration: InputDecoration(
                  labelText: 'Starting Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dropController,
                decoration: InputDecoration(
                  labelText: 'Dropping Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.location_off),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: searchRides,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6200EE),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Search Rides'),
              ),
              const SizedBox(height: 20),
              if (errorMessage != null)
                Center(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              if (successMessage != null)
                Center(
                  child: Text(
                    successMessage!,
                    style: const TextStyle(color: Colors.green, fontSize: 16),
                  ),
                ),
              if (isSearching)
                const Center(child: CircularProgressIndicator())
              else if (matchingRides.isEmpty && _startController.text.isNotEmpty)
                const Center(
                  child: Text(
                    'No rides available within 5km radius',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: matchingRides.length,
                  itemBuilder: (context, index) {
                    final ride = matchingRides[index];
                    final isRequested = widget.userState.currentUser?.requestedOfferIds.contains(ride.id) ?? false;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '${ride.driverLocationName} to ${ride.destinationLocationName ?? 'Unknown Destination'}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Driver ID: ${ride.driverId}'),
                            if (ride.proposedLeaveTime != null)
                              Text('Leave: ${ride.proposedLeaveTime!.format(context)}'),
                            Text('Price: \$${ride.price.toStringAsFixed(2)}'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: isRequested ? null : () => _requestRide(ride),
                          child: Text(isRequested ? 'Requested' : 'Request'),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RideOfferDetailScreen(
                                userState: widget.userState,
                                rideOffer: ride,
                                refreshOffersKey: _refreshIndicatorKey,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestRide(RideOfferModel ride) async {
    if (widget.userState.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to request a ride')),
      );
      return;
    }

    setState(() {
      errorMessage = null;
      successMessage = null; // Clear previous messages
    });

    final user = widget.userState.currentUser!;
    final updatedRequestedIds = List<String>.from(user.requestedOfferIds)..add(ride.id);
    final updatedUser = UserModel(
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      showFullName: user.showFullName ?? true,
      createdAt: user.createdAt,
      profileImage: user.profileImage,
      vehicle: user.vehicle,
      myOfferIds: user.myOfferIds,
      requestedOfferIds: updatedRequestedIds,
      chatRoomIds: user.chatRoomIds,
    );

    final updatedRequestedUserIds = Map<String, RequestedOfferStatus>.from(ride.requestedUserIds)
      ..[user.email] = RequestedOfferStatus.PENDING;
    final updatedRide = RideOfferModel(
      id: ride.id,
      createdAt: ride.createdAt,
      driverId: ride.driverId,
      vehicleId: ride.vehicleId,
      proposedLeaveTime: ride.proposedLeaveTime,
      proposedBackTime: ride.proposedBackTime,
      requestedUserIds: updatedRequestedUserIds,
      proposedWeekdays: ride.proposedWeekdays,
      driverLocationName: ride.driverLocationName,
      driverLocation: ride.driverLocation,
      destinationLocation: ride.destinationLocation,
      destinationLocationName: ride.destinationLocationName,
      price: ride.price,
      additionalDetails: ride.additionalDetails,
    );

    try {
      await widget.userState.setCurrentUser(updatedUser);
      await widget.userState.setStoredOffer(ride.id, updatedRide);
      await widget.fetchAllOffers();

      setState(() {
        successMessage = 'Ride request sent for ${ride.driverLocationName}';
      });

      if (widget.onRideRequested != null) {
        widget.onRideRequested!();
      }

      // Optionally clear the message after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            successMessage = null;
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ride request sent for ${ride.driverLocationName}')),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to request ride: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to request ride: $e')),
      );
    }
  }
}