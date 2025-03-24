import 'package:rideshare/models/types/requested_offer_status.dart';
import 'package:rideshare/providers/user_state.dart';
import 'package:rideshare/screens/ride/exploreRides/ride_offer_detail_screen.dart';
import 'package:rideshare/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rideshare/models/ride_offer_model.dart';
import 'package:rideshare/models/user_model.dart';

class UpcomingRides extends StatefulWidget {
  final UserState userState;
  final Function() fetchAllOffers;
  final Function(int) changePageIndex;

  const UpcomingRides(
      {super.key,
      required this.userState,
      required this.fetchAllOffers,
      required this.changePageIndex});

  @override
  UpcomingRidesState createState() => UpcomingRidesState();
}

class UpcomingRidesState extends State<UpcomingRides> {
  GlobalKey<RefreshIndicatorState> refreshMyRequestedOfferIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  List<RideOfferModel> myRequestedOffers = [];
  Map<String, UserModel?> drivers = {};

  Future<void> fetchMyRequestedOffers() async {
    await widget.fetchAllOffers();
  }

  void getMyRequestedOffers() {
    final requestedOffers = widget.userState.storedOffers.entries
        .where((offer) =>
            widget.userState.currentUser!.requestedOfferIds.contains(offer.key))
        .map((offer) => offer.value)
        .toList();
    setState(() {
      myRequestedOffers = requestedOffers;
    });

    // Fetch driver information for each offer
    for (var offer in requestedOffers) {
      getDriverInfo(offer.driverId);
    }
  }

  Future<void> getDriverInfo(String driverId) async {
    if (driverId == widget.userState.currentUser!.email) {
      setState(() {
        drivers[driverId] = widget.userState.currentUser!;
      });
      return;
    }

    UserModel? fetchedDriver;
    if (widget.userState.storedUsers.containsKey(driverId)) {
      fetchedDriver = widget.userState.storedUsers[driverId];
    } else {
      fetchedDriver = await widget.userState.getStoredUserByEmail(driverId);
    }

    setState(() {
      drivers[driverId] = fetchedDriver;
    });
  }

  @override
  void initState() {
    super.initState();
    getMyRequestedOffers();
  }

  String getDriverName(String driverId) {
    if (driverId == widget.userState.currentUser!.email) {
      return 'You';
    }

    if (drivers.containsKey(driverId) && drivers[driverId] != null) {
      return drivers[driverId]!.fullName;
    }

    return 'Loading...';
  }

  @override
  Widget build(BuildContext context) {
    if (myRequestedOffers.isEmpty) {
      // Show a message when there are no upcoming ride offers
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: fetchMyRequestedOffers,
              icon: const Icon(Icons.refresh, color: Colors.blue),
              iconSize: 32,
            ),
            const Text(
              'No upcoming rides',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                widget.changePageIndex(1);
              },
              child: const Text('Explore Rides'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      key: refreshMyRequestedOfferIndicatorKey,
      onRefresh: fetchMyRequestedOffers,
      child: ListView.builder(
        itemCount: myRequestedOffers.length,
        itemBuilder: (context, index) {
          final rideOffer = myRequestedOffers[index];
          final requestedOfferStatus =
              rideOffer.requestedUserIds[widget.userState.currentUser!.email]!;

          if (requestedOfferStatus == RequestedOfferStatus.INVALID) {
            return ListTile(
              title: const Text('Offer not available'),
              subtitle: const Text('This offer is deleted by the user.'),
              trailing: const Icon(Icons.error, color: Colors.orange),
              onTap: () {
                widget.userState.currentUser!
                    .withdrawRequestRide(widget.userState, rideOffer.id);
              },
            );
          }

          return ListTile(
            title: Text(
              getDriverName(rideOffer.driverId),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Utils.getShortLocationName(rideOffer.driverLocationName)),
                Text(
                  '${rideOffer.proposedLeaveTime!.format(context)} - ${rideOffer.proposedBackTime!.format(context)}',
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  describeEnum(requestedOfferStatus),
                  style: TextStyle(
                    color: Utils.requestStatusToColor(requestedOfferStatus),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Utils.requestStatusToIcon(requestedOfferStatus),
              ],
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RideOfferDetailScreen(
                    userState: widget.userState,
                    rideOffer: rideOffer,
                    refreshOffersKey: refreshMyRequestedOfferIndicatorKey,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
