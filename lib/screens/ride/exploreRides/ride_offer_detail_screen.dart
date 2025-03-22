import 'package:corider/cloud_functions/firebase_function.dart';
import 'package:corider/models/types/requested_offer_status.dart';
import 'package:corider/models/user_model.dart';
import 'package:corider/providers/user_state.dart';
import 'package:corider/screens/chat/chat.dart';
import 'package:corider/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:corider/models/ride_offer_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class RideOfferDetailScreen extends StatefulWidget {
  final UserState userState;
  final RideOfferModel rideOffer;
  final GlobalKey? refreshOffersKey;

  const RideOfferDetailScreen({
    super.key,
    required this.userState,
    required this.rideOffer,
    this.refreshOffersKey,
  });

  @override
  RideOfferDetailScreenState createState() => RideOfferDetailScreenState();
}

class RideOfferDetailScreenState extends State<RideOfferDetailScreen> {
  bool isRequesting = false;
  UserModel? driverUser;
  String? driverLocationAddress;

  void refreshOffers() {
    if (widget.refreshOffersKey is GlobalKey<RefreshIndicatorState>) {
      final refreshOffersIndicatorKey =
          widget.refreshOffersKey as GlobalKey<RefreshIndicatorState>;
      refreshOffersIndicatorKey.currentState?.show();
    } else {
      debugPrint('widget.refreshOffersKey is not of type GlobalKey<RefreshIndicatorState>');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isRequesting = true);
    
    try {
      // Debug information to help diagnose issues
      debugPrint("Initializing data for ride offer ID: ${widget.rideOffer.id}");
      debugPrint("Driver ID: ${widget.rideOffer.driverId}");
      debugPrint("Driver location: ${widget.rideOffer.driverLocation}");
      debugPrint("Driver location name: ${widget.rideOffer.driverLocationName}");
      
      // Get driver user info
      driverUser = await widget.userState.getStoredUserByEmail(widget.rideOffer.driverId);
      
      // Get address from coordinates
      driverLocationAddress = await _getAddressFromLatLng(widget.rideOffer.driverLocation);
      
      debugPrint("Driver address resolved to: $driverLocationAddress");
    } catch (e) {
      debugPrint("Error initializing ride offer details: $e");
    } finally {
      setState(() => isRequesting = false);
    }
  }

  Future<String> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Create a more robust address format that handles nulls
        List<String> addressParts = [];
        
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }
        
        if (addressParts.isEmpty) {
          return widget.rideOffer.driverLocationName ?? 'Unknown Location';
        }
        
        return addressParts.join(', ');
      } else {
        return widget.rideOffer.driverLocationName ?? 'Unknown Location';
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      return widget.rideOffer.driverLocationName ?? 'Unknown Location';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final UserModel currentUser = userState.currentUser!;
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Offer Details'),
      ),
      body: isRequesting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver Details:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Driver: ${driverUser?.firstName ?? widget.rideOffer.driverId}',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Ride Offer Details:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Proposed Leave Time: \n${widget.rideOffer.proposedLeaveTime != null ? 
                      widget.rideOffer.proposedLeaveTime!.format(context) : 'Not specified'}',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Proposed Back Time: \n${widget.rideOffer.proposedBackTime != null ? 
                      widget.rideOffer.proposedBackTime!.format(context) : 'Not specified'}',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Availability: \n${widget.rideOffer.proposedWeekdays.map((i) => weekdays[i]).join(', ')}',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Location: \n${driverLocationAddress ?? 'Location not resolved yet'}',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Coordinates: \n(${widget.rideOffer.driverLocation.latitude}, ${widget.rideOffer.driverLocation.longitude})',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Price: \n${widget.rideOffer.price == 0.0 ? 'Free' : widget.rideOffer.price}',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Additional Details: \n${widget.rideOffer.additionalDetails ?? 'No additional details'}',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  if (widget.rideOffer.driverId == currentUser.email) ...[
                    const SizedBox(height: 16.0),
                    const Text(
                      'Requested Users:',
                      style: TextStyle(fontSize: 16.0),
                    ),
                    const SizedBox(height: 8.0),
                    ...widget.rideOffer.requestedUserIds.entries.map((entry) {
                      String userId = entry.key;
                      RequestedOfferStatus status = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(userId.split('@')[0]),
                            Row(
                              children: [
                                Text(describeEnum(status)),
                                Utils.requestStatusToIcon(status),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () => _handleAcceptRequest(userId, status),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Icon(Icons.check),
                            ),
                            ElevatedButton(
                              onPressed: () => _handleRejectRequest(userId, status),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 32.0),
                  Center(
                    child: buildRideOfferActions(context, userState, currentUser),
                  ),
                ],
              ),
            ),
    );
  }

  void _handleAcceptRequest(String userId, RequestedOfferStatus status) async {
    if (status == RequestedOfferStatus.ACCEPTED) {
      _showSnackBar('Ride request already accepted!', Duration(seconds: 1));
      return;
    }

    setState(() => isRequesting = true);
    final err = await widget.userState.currentUser!.acceptRideRequest(widget.rideOffer.id, userId);
    setState(() => isRequesting = false);

    if (err == null) {
      setState(() {
        widget.rideOffer.requestedUserIds[userId] = RequestedOfferStatus.ACCEPTED;
      });
      _showSnackBar('Ride request accepted!', Duration(seconds: 1));
    } else {
      _showSnackBar('Error: $err', Duration(seconds: 2));
    }
  }

  void _handleRejectRequest(String userId, RequestedOfferStatus status) async {
    if (status == RequestedOfferStatus.REJECTED) {
      _showSnackBar('Ride request already rejected!', Duration(seconds: 1));
      return;
    }

    setState(() => isRequesting = true);
    final err = await widget.userState.currentUser!.rejectRideRequest(widget.rideOffer.id, userId);
    setState(() => isRequesting = false);

    if (err == null) {
      setState(() {
        widget.rideOffer.requestedUserIds[userId] = RequestedOfferStatus.REJECTED;
      });
      _showSnackBar('Ride request rejected!', Duration(seconds: 1));
    } else {
      _showSnackBar('Error: $err', Duration(seconds: 2));
    }
  }

  void _showSnackBar(String message, Duration duration) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: duration),
    );
  }

  Widget buildMyRideOfferActions(BuildContext context, UserState userState, UserModel currentUser) {
    return ElevatedButton(
      onPressed: () async {
        setState(() => isRequesting = true);
        await FirebaseFunctions.deleteUserRideOfferByOfferId(currentUser, widget.rideOffer.id);
        setState(() => isRequesting = false);
        
        _showSnackBar('Ride offer deleted!', Duration(seconds: 1));
        Navigator.of(context).pop();
        refreshOffers();
      },
      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
      child: const Text('Delete Ride'),
    );
  }

  Widget chatButton(UserModel currentUser) {
    return ElevatedButton(
      onPressed: () async {
        if (driverUser == null) {
          _showSnackBar('Driver information not available yet', Duration(seconds: 2));
          return;
        }
        
        setState(() => isRequesting = true);
        final chatRoom = await currentUser.requestChatWithUser(widget.userState, driverUser!);
        setState(() => isRequesting = false);

        if (chatRoom != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                userState: widget.userState,
                room: chatRoom,
              ),
            ),
          );
        } else {
          _showSnackBar('Chat request failed!', Duration(seconds: 2));
        }
      },
      child: const Text('Chat'),
    );
  }

  Widget buildOtherRideOfferActions(BuildContext context, UserState userState, UserModel currentUser) {
    final requestedOfferStatus = widget.rideOffer.requestedUserIds[currentUser.email];

    if (currentUser.requestedOfferIds.contains(widget.rideOffer.id)) {
      return Column(
        children: [
          chatButton(currentUser),
          const SizedBox(height: 8.0),
          Text(
            'Ride ${describeEnum(requestedOfferStatus!)}!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.0,
              color: Utils.requestStatusToColor(requestedOfferStatus),
            ),
          ),
          const SizedBox(height: 8.0),
          ElevatedButton(
            onPressed: () async {
              setState(() => isRequesting = true);
              final err = await currentUser.withdrawRequestRide(userState, widget.rideOffer.id);
              setState(() => isRequesting = false);
              
              if (err == null) {
                _showSnackBar('Ride request withdrawn!', Duration(seconds: 1));
              } else {
                _showSnackBar('Ride request withdraw failed! $err', Duration(seconds: 2));
              }
              refreshOffers();
            },
            child: const Text('Withdraw Request'),
          ),
        ],
      );
    }

    return Column(
      children: [
        chatButton(currentUser),
        const SizedBox(height: 16.0),
        ElevatedButton(
          onPressed: () async {
            setState(() => isRequesting = true);
            final err = await currentUser.requestRide(userState, widget.rideOffer);
            setState(() => isRequesting = false);
            
            if (err == null) {
              _showSnackBar('Ride request sent!', Duration(seconds: 1));
            } else {
              _showSnackBar('Ride request failed! $err', Duration(seconds: 2));
            }
            refreshOffers();
          },
          child: const Text('Request Ride'),
        ),
      ],
    );
  }

  Widget buildRideOfferActions(BuildContext context, UserState userState, UserModel currentUser) {
    return currentUser.email != widget.rideOffer.driverId
        ? buildOtherRideOfferActions(context, userState, currentUser)
        : buildMyRideOfferActions(context, userState, currentUser);
  }
}