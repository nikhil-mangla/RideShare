import 'package:rideshare/cloud_functions/firebase_function.dart';
import 'package:rideshare/models/types/requested_offer_status.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/providers/user_state.dart';
import 'package:rideshare/screens/chat/chat.dart';
import 'package:rideshare/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rideshare/models/ride_offer_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class RideOfferDetailScreen extends StatefulWidget {
  final UserState userState;
  final RideOfferModel rideOffer;
  final GlobalKey<RefreshIndicatorState>? refreshOffersKey; // Made optional

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
  String? destinationLocationAddress;

  // Updated theme colors to match HomeScreen
  final Color primaryPurple = const Color(0xFF6200EE);
  final Color secondaryPurple = const Color(0xFF9C27B0);
  final Color lightPurple = const Color(0xFFE1BEE7);
  final Color backgroundColor = Colors.white;
  final Color textDark = const Color(0xFF212121);
  final Color textLight = const Color(0xFF757575);

  void refreshOffers() {
    if (widget.refreshOffersKey != null) {
      widget.refreshOffersKey!.currentState?.show();
    } else {
      debugPrint('refreshOffersKey is null, no refresh triggered');
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
      debugPrint("Initializing data for ride offer ID: ${widget.rideOffer.id}");
      debugPrint("Driver ID: ${widget.rideOffer.driverId}");
      debugPrint("Driver location: ${widget.rideOffer.driverLocation}");
      debugPrint(
          "Driver location name: ${widget.rideOffer.driverLocationName}");

      // Get driver user info
      driverUser = await widget.userState
          .getStoredUserByEmail(widget.rideOffer.driverId);
      debugPrint(
          "Destination location: ${widget.rideOffer.destinationLocation}");
      debugPrint(
          "Destination name: ${widget.rideOffer.destinationLocationName}");

      // Get addresses from coordinates
      driverLocationAddress =
          await _getAddressFromLatLng(widget.rideOffer.driverLocation);
      destinationLocationAddress =
          await _getAddressFromLatLng(widget.rideOffer.destinationLocation);

      debugPrint("Driver address resolved to: $driverLocationAddress");
      debugPrint(
          "Destination address resolved to: $destinationLocationAddress");
    } catch (e) {
      debugPrint("Error initializing ride offer details: $e");
    } finally {
      setState(() => isRequesting = false);
    }
  }

  Future<String> _getAddressFromLatLng(LatLng? position) async {
    if (position == null) {
      return widget.rideOffer.driverLocationName ?? 'Unknown Location';
    }
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
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
    final UserModel? currentUser = userState.currentUser; // Null-safe access

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ride Details',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [secondaryPurple, primaryPurple],
              ),
            ),
          ),
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Please log in to view ride details',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Ride Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [secondaryPurple, primaryPurple],
            ),
          ),
        ),
        elevation: 0,
      ),
      body: isRequesting
          ? Center(child: CircularProgressIndicator(color: primaryPurple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(
                    title: 'Driver',
                    content: driverUser?.firstName ?? widget.rideOffer.driverId,
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16.0),
                  _buildInfoCard(
                    title: 'Schedule',
                    content: _buildScheduleContent(),
                    icon: Icons.schedule,
                  ),
                  const SizedBox(height: 16.0),
                  _buildInfoCard(
                    title: 'Location',
                    content:
                        driverLocationAddress ?? 'Location not resolved yet',
                    icon: Icons.location_on,
                  ),
                  const SizedBox(height: 16.0),
                  _buildInfoCard(
                    title: 'Destination',
                    content: destinationLocationAddress ??
                        'Destination not resolved yet',
                    icon: Icons.flag,
                  ),
                  const SizedBox(height: 16.0),
                  _buildInfoCard(
                    title: 'Price',
                    content: widget.rideOffer.price == 0.0
                        ? 'Free'
                        : widget.rideOffer.price.toStringAsFixed(2),
                    icon: Icons.attach_money,
                  ),
                  if (widget.rideOffer.additionalDetails.isNotEmpty) ...[
                    const SizedBox(height: 16.0),
                    _buildInfoCard(
                      title: 'Additional Details',
                      content: widget.rideOffer.additionalDetails,
                      icon: Icons.info_outline,
                    ),
                  ],
                  if (widget.rideOffer.driverId == currentUser.email) ...[
                    const SizedBox(height: 24.0),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.people_alt_outlined,
                                    color: primaryPurple),
                                const SizedBox(width: 8),
                                Text(
                                  'Requested Users',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                    color: primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16.0),
                            if (widget.rideOffer.requestedUserIds.isEmpty)
                              Text('No ride requests yet',
                                  style: TextStyle(color: textLight)),
                            ...widget.rideOffer.requestedUserIds.entries
                                .map((entry) {
                              String userId = entry.key;
                              RequestedOfferStatus status = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: secondaryPurple,
                                      child: Text(
                                        userId.split('@')[0][0].toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userId.split('@')[0],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: textDark,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                describeEnum(status),
                                                style: TextStyle(
                                                  color: Utils
                                                      .requestStatusToColor(
                                                          status),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Utils.requestStatusToIcon(status),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _buildActionButton(
                                          icon: Icons.check,
                                          color: Colors.green,
                                          onPressed: () => _handleAcceptRequest(
                                              userId, status),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildActionButton(
                                          icon: Icons.close,
                                          color: Colors.red,
                                          onPressed: () => _handleRejectRequest(
                                              userId, status),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32.0),
                  Center(
                    child:
                        buildRideOfferActions(context, userState, currentUser),
                  ),
                  const SizedBox(height: 24.0),
                ],
              ),
            ),
    );
  }

  String _buildScheduleContent() {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    List<String> scheduleParts = [];

    if (widget.rideOffer.proposedLeaveTime != null) {
      scheduleParts.add(
          "Departure: ${widget.rideOffer.proposedLeaveTime!.format(context)}");
    }

    if (widget.rideOffer.proposedBackTime != null) {
      scheduleParts
          .add("Return: ${widget.rideOffer.proposedBackTime!.format(context)}");
    }

    scheduleParts.add(
        "Days: ${widget.rideOffer.proposedWeekdays.map((i) => weekdays[i]).join(', ')}");

    return scheduleParts.join('\n');
  }

  Widget _buildInfoCard(
      {required String title,
      required String content,
      required IconData icon}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: secondaryPurple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                    color: secondaryPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                content,
                style: TextStyle(fontSize: 16.0, color: textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        constraints: const BoxConstraints(
          minHeight: 40,
          minWidth: 40,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _handleAcceptRequest(String userId, RequestedOfferStatus status) async {
    if (status == RequestedOfferStatus.ACCEPTED) {
      _showSnackBar('Ride request already accepted!', Duration(seconds: 1));
      return;
    }

    setState(() => isRequesting = true);
    final err = await widget.userState.currentUser!
        .acceptRideRequest(widget.rideOffer.id, userId);
    setState(() => isRequesting = false);

    if (err == null) {
      setState(() {
        widget.rideOffer.requestedUserIds[userId] =
            RequestedOfferStatus.ACCEPTED;
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
    final err = await widget.userState.currentUser!
        .rejectRideRequest(widget.rideOffer.id, userId);
    setState(() => isRequesting = false);

    if (err == null) {
      setState(() {
        widget.rideOffer.requestedUserIds[userId] =
            RequestedOfferStatus.REJECTED;
      });
      _showSnackBar('Ride request rejected!', Duration(seconds: 1));
    } else {
      _showSnackBar('Error: $err', Duration(seconds: 2));
    }
  }

  void _showSnackBar(String message, Duration duration) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: secondaryPurple,
      ),
    );
  }

  Widget buildMyRideOfferActions(
      BuildContext context, UserState userState, UserModel currentUser) {
    return ElevatedButton(
      onPressed: () async {
        setState(() => isRequesting = true);
        await FirebaseFunctions.deleteUserRideOfferByOfferId(
            currentUser, widget.rideOffer.id);
        setState(() => isRequesting = false);

        _showSnackBar('Ride offer deleted!', Duration(seconds: 1));
        Navigator.of(context).pop();
        refreshOffers();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 3,
      ),
      child: const Text(
        'Delete Ride',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget chatButton(UserModel currentUser) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.chat_bubble_outline),
      label: const Text(
        'Chat with Driver',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      onPressed: () async {
        if (driverUser == null) {
          _showSnackBar(
              'Driver information not available yet', Duration(seconds: 2));
          return;
        }

        setState(() => isRequesting = true);
        final chatRoom = await currentUser.requestChatWithUser(
            widget.userState, driverUser!);
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
      style: ElevatedButton.styleFrom(
        backgroundColor: secondaryPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 3,
      ),
    );
  }

  Widget buildOtherRideOfferActions(
      BuildContext context, UserState userState, UserModel currentUser) {
    final requestedOfferStatus =
        widget.rideOffer.requestedUserIds[currentUser.email];

    if (currentUser.requestedOfferIds.contains(widget.rideOffer.id)) {
      return Column(
        children: [
          chatButton(currentUser),
          const SizedBox(height: 16.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Utils.requestStatusToColor(requestedOfferStatus ?? RequestedOfferStatus.PENDING)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Utils.requestStatusToIcon(requestedOfferStatus ?? RequestedOfferStatus.PENDING),
                const SizedBox(width: 8),
                Text(
                  'Status: ${describeEnum(requestedOfferStatus ?? RequestedOfferStatus.PENDING)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                    color: Utils.requestStatusToColor(requestedOfferStatus ?? RequestedOfferStatus.PENDING),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: const Text(
              'Withdraw Request',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              setState(() => isRequesting = true);
              final err = await currentUser.withdrawRequestRide(
                  userState, widget.rideOffer.id);
              setState(() => isRequesting = false);

              if (err == null) {
                _showSnackBar('Ride request withdrawn!', Duration(seconds: 1));
                Navigator.of(context).pop();
              } else {
                _showSnackBar(
                    'Ride request withdraw failed! $err', Duration(seconds: 2));
              }
              refreshOffers();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        chatButton(currentUser),
        const SizedBox(height: 16.0),
        ElevatedButton.icon(
          icon: const Icon(Icons.directions_car),
          label: const Text(
            'Request Ride',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            setState(() => isRequesting = true);
            final err =
                await currentUser.requestRide(userState, widget.rideOffer);
            setState(() => isRequesting = false);

            if (err == null) {
              _showSnackBar('Ride request sent!', Duration(seconds: 1));
              Navigator.of(context).pop();
            } else {
              _showSnackBar('Ride request failed! $err', Duration(seconds: 2));
            }
            refreshOffers();
          },
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 3,
            backgroundColor: primaryPurple,
          ),
        ),
      ],
    );
  }

  Widget buildRideOfferActions(
      BuildContext context, UserState userState, UserModel currentUser) {
    return currentUser.email != widget.rideOffer.driverId
        ? buildOtherRideOfferActions(context, userState, currentUser)
        : buildMyRideOfferActions(context, userState, currentUser);
  }
}