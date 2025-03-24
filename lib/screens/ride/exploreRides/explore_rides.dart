import 'package:rideshare/models/ride_offer_model.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/providers/user_state.dart';
import 'package:rideshare/screens/ride/createRideOffer/create_ride_offer_screen.dart';
import 'package:rideshare/screens/ride/exploreRides/ride_offer_detail_screen.dart';
import 'package:rideshare/screens/ride/exploreRides/rides_filter/filter_sort_enum.dart';
import 'package:flutter/material.dart';
import 'package:rideshare/widgets/ride_offer_card.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

// Define theme colors
const Color primaryPurple = Color(0xFF6A1B9A);
const Color lightPurple = Color(0xFF9C4DCC);
const Color accentPurple = Color(0xFFD1C4E9);
const Color backgroundWhite = Color(0xFFFAFAFA);

class ExploreRidesScreen extends StatefulWidget {
  final UserState userState;
  const ExploreRidesScreen({super.key, required this.userState});

  @override
  State<ExploreRidesScreen> createState() => _ExploreRidesScreenState();
}

class _ExploreRidesScreenState extends State<ExploreRidesScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  List<RideOfferModel> offers = [];
  List<RideOfferCard>? rideOfferCards;
  late AnimationController _animationController;

  LatLng? currentLocation;
  final Set<Marker> _markers = {};
  GlobalKey<RefreshIndicatorState> refreshOffersIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    currentLocation = widget.userState.currentLocation;
    _initializeOffers();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeOffers() async {
    if (widget.userState.storedOffers.isEmpty) {
      await _handleRefresh(widget.userState.currentUser!);
    } else {
      setState(() {
        offers = widget.userState.storedOffers.values.toList();
        _updateRideOfferCards();
      });
    }
  }

  void _updateRideOfferCards() {
    rideOfferCards = offers
        .map((offer) => RideOfferCard(
              userState: widget.userState,
              rideOffer: offer,
              currentLocation: currentLocation,
              refreshOffersIndicatorKey: refreshOffersIndicatorKey,
            ))
        .toList();
    _addMarkers();
  }

  void _addMarkers() async {
    _markers.clear();
    for (int i = 0; i < offers.length; i++) {
      LatLng location = offers[i].driverLocation;
      String address = await _getAddressFromLatLng(location);
      Marker marker = Marker(
        markerId: MarkerId(i.toString()),
        position: location,
        infoWindow: InfoWindow(
          title: offers[i].driverId,
          snippet: address,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RideOfferDetailScreen(
                userState: widget.userState,
                rideOffer: offers[i],
              ),
            ),
          );
        },
      );
      _markers.add(marker);
    }
    setState(() {});
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

  void _onMapCreated(GoogleMapController controller) {}

  Future<void> _handleRefresh(UserModel user) async {
    try {
      await widget.userState.fetchAllOffers();
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          currentLocation = LatLng(position.latitude, position.longitude);
        });
      } catch (locationError) {
        debugPrint('Location error: $locationError');
        await widget.userState.showLocationPermissionDialog(context);
      }

      setState(() {
        offers = widget.userState.storedOffers.values.toList();
        _updateRideOfferCards();
      });

      if (refreshOffersIndicatorKey.currentState != null) {
        refreshOffersIndicatorKey.currentState!.show();
      }
    } catch (e) {
      debugPrint('Error refreshing offers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing offers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleView() {
    setState(() {
      if (_selectedIndex == 0) {
        _selectedIndex = 1;
        _animationController.forward();
      } else {
        _selectedIndex = 0;
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final UserModel currentUser = userState.currentUser!;
    offers = userState.storedOffers.values.toList();
    final primary = Color(0xFF6200EE);
    final secondary = Color(0xFF9C27B0);

    return Scaffold(
      backgroundColor: backgroundWhite,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [secondary, primary],
            ),
          ),
        ),
        title: const Text(
          'Explore Rides',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return IconButton(
              onPressed: _toggleView,
              icon: AnimatedCrossFade(
                firstChild: const Icon(Icons.map_outlined, color: Colors.white),
                secondChild: const Icon(Icons.list_alt, color: Colors.white),
                crossFadeState: _selectedIndex == 0
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateRideOfferScreen(
                    refreshOffersIndicatorKey: refreshOffersIndicatorKey,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add_circle, color: Colors.white),
            tooltip: 'Create Ride Offer',
          ),
        ],
      ),
      body: rideOfferCards == null
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryPurple),
              ),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedIndex == 0
                  ? RefreshIndicator(
                      key: refreshOffersIndicatorKey,
                      onRefresh: () => _handleRefresh(currentUser),
                      color: primaryPurple,
                      child: RideOfferList(
                        userState: userState,
                        rideOfferCards: rideOfferCards!,
                        refreshOffersIndicatorKey: refreshOffersIndicatorKey,
                        currentLocation: currentLocation,
                      ),
                    )
                  : CustomMapWidget(
                      markers: _markers,
                      initialCameraPosition: CameraPosition(
                        target: currentLocation ??
                            const LatLng(43.7720940, -79.3453741),
                        zoom: currentLocation != null ? 12.0 : 20.0,
                      ),
                      onMapCreated: _onMapCreated,
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => refreshOffersIndicatorKey.currentState!.show(),
        backgroundColor: primaryPurple,
        tooltip: 'Refresh Rides',
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}

class RideOfferList extends StatefulWidget {
  final UserState userState;
  final List<RideOfferCard> rideOfferCards;
  final GlobalKey<RefreshIndicatorState> refreshOffersIndicatorKey;
  final LatLng? currentLocation;

  const RideOfferList({
    super.key,
    required this.userState,
    required this.rideOfferCards,
    required this.refreshOffersIndicatorKey,
    required this.currentLocation,
  });

  @override
  State<RideOfferList> createState() => _RideOfferListState();
}

class _RideOfferListState extends State<RideOfferList> {
  RideOfferFilter? _selectedFilter;
  RideOfferSortBy? _selectedSort;
  late List<RideOfferCard> displayOffers;

  @override
  void initState() {
    super.initState();
    displayOffers = List.from(widget.rideOfferCards);
    _selectedFilter = RideOfferFilter.All; // Default to showing all rides
  }

  void _handleFilterChanged(RideOfferFilter value) {
    if (_selectedFilter == value) return;
    setState(() {
      _selectedFilter = value;
      print('Filter changed to: $_selectedFilter');
    });
  }

  void _handleSortChanged(RideOfferSortBy value) {
    if (_selectedSort == value) return;
    setState(() {
      _selectedSort = value;
    });
    switch (value) {
      case RideOfferSortBy.distance:
        _sortOffersByShortestPath();
        break;
      case RideOfferSortBy.leaveTime:
        _sortOffersByLeaveTime();
        break;
      case RideOfferSortBy.backTime:
        _sortOffersByBackTime();
        break;
      case RideOfferSortBy.price:
        _sortOffersByPrice();
        break;
      default:
        _rebuildOffers(List.from(widget.rideOfferCards));
    }
  }

  Map<String, double> _dijkstra(LatLng start, List<RideOfferCard> offers) {
    Map<String, Map<String, double>> graph = {};
    List<LatLng> nodes = [
      start,
      ...offers.map((offer) => offer.rideOffer.driverLocation)
    ];
    for (int i = 0; i < nodes.length; i++) {
      graph[nodes[i].toString()] = {};
      for (int j = 0; j < nodes.length; j++) {
        if (i != j) {
          double distance = Geolocator.distanceBetween(
            nodes[i].latitude,
            nodes[i].longitude,
            nodes[j].latitude,
            nodes[j].longitude,
          );
          graph[nodes[i].toString()]![nodes[j].toString()] = distance;
        }
      }
    }

    Map<String, double> distances = {start.toString(): 0};
    Map<String, bool> visited = {};
    List<String> unvisited = nodes.map((node) => node.toString()).toList();

    while (unvisited.isNotEmpty) {
      String currentNode = unvisited.reduce((a, b) =>
          (distances[a] ?? double.infinity) < (distances[b] ?? double.infinity)
              ? a
              : b);

      if (distances[currentNode] == null) break;

      unvisited.remove(currentNode);
      visited[currentNode] = true;

      for (var neighbor in graph[currentNode]!.keys) {
        if (visited[neighbor] == true) continue;

        double newDist = (distances[currentNode] ?? double.infinity) +
            graph[currentNode]![neighbor]!;
        if (newDist < (distances[neighbor] ?? double.infinity)) {
          distances[neighbor] = newDist;
        }
      }
    }

    return distances;
  }

  void _sortOffersByShortestPath() {
    if (widget.currentLocation == null) return;
    Map<String, double> distances =
        _dijkstra(widget.currentLocation!, widget.rideOfferCards);
    List<RideOfferCard> sortedOffers = List.from(widget.rideOfferCards);
    sortedOffers.sort((a, b) {
      double distA =
          distances[a.rideOffer.driverLocation.toString()] ?? double.infinity;
      double distB =
          distances[b.rideOffer.driverLocation.toString()] ?? double.infinity;
      return distA.compareTo(distB);
    });
    _rebuildOffers(sortedOffers);
  }

  void _sortOffersByLeaveTime() {
    List<RideOfferCard> sortedOffers = List.from(widget.rideOfferCards);
    sortedOffers.sort((a, b) {
      TimeOfDay? timeA = a.rideOffer.proposedLeaveTime;
      TimeOfDay? timeB = b.rideOffer.proposedLeaveTime;
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return -1;
      if (timeB == null) return 1;
      int minutesA = timeA.hour * 60 + timeA.minute;
      int minutesB = timeB.hour * 60 + timeB.minute;
      return minutesA.compareTo(minutesB);
    });
    _rebuildOffers(sortedOffers);
  }

  void _sortOffersByBackTime() {
    List<RideOfferCard> sortedOffers = List.from(widget.rideOfferCards);
    sortedOffers.sort((a, b) {
      TimeOfDay? timeA = a.rideOffer.proposedBackTime;
      TimeOfDay? timeB = b.rideOffer.proposedBackTime;
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return -1;
      if (timeB == null) return 1;
      int minutesA = timeA.hour * 60 + timeA.minute;
      int minutesB = timeB.hour * 60 + timeB.minute;
      return minutesA.compareTo(minutesB);
    });
    _rebuildOffers(sortedOffers);
  }

  void _sortOffersByPrice() {
    List<RideOfferCard> sortedOffers = List.from(widget.rideOfferCards);
    sortedOffers.sort((a, b) => a.rideOffer.price.compareTo(b.rideOffer.price));
    _rebuildOffers(sortedOffers);
  }

  void _rebuildOffers(List<RideOfferCard> offers) {
    setState(() {
      displayOffers = offers;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('Building RideOfferList with filter: $_selectedFilter');
    return widget.rideOfferCards.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.directions_car_outlined,
                  size: 80,
                  color: lightPurple,
                ),
                const SizedBox(height: 16),
                Text(
                  'No rides available',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: primaryPurple,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pull down to refresh or create a new ride',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      widget.refreshOffersIndicatorKey.currentState!.show(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          )
        : Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ModernRidesFilter(
                  onFilterChanged: _handleFilterChanged,
                  onSortChanged: _handleSortChanged,
                  selectedFilter: _selectedFilter,
                  selectedSort: _selectedSort,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: displayOffers.length + 1,
                  itemBuilder: (context, index) {
                    if (index < displayOffers.length) {
                      if (_selectedFilter == RideOfferFilter.byMe &&
                          displayOffers[index].rideOffer.driverId !=
                              widget.userState.currentUser!.email) {
                        return Container();
                      }
                      if (_selectedFilter == RideOfferFilter.others &&
                          displayOffers[index].rideOffer.driverId ==
                              widget.userState.currentUser!.email) {
                        return Container();
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: displayOffers[index],
                        ),
                      );
                    }
                    return Container(
                      padding: const EdgeInsets.all(24.0),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(
                            Icons.keyboard_double_arrow_down,
                            color: lightPurple,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'END OF LIST',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: lightPurple,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pull down to refresh',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }
}

class CustomMapWidget extends StatefulWidget {
  final Set<Marker> markers;
  final CameraPosition initialCameraPosition;
  final void Function(GoogleMapController) onMapCreated;

  const CustomMapWidget({
    required this.markers,
    required this.initialCameraPosition,
    required this.onMapCreated,
    super.key,
  });

  @override
  State<CustomMapWidget> createState() => _CustomMapWidgetState();
}

class _CustomMapWidgetState extends State<CustomMapWidget> {
  late CameraPosition cameraPosition;

  @override
  void initState() {
    super.initState();
    cameraPosition = widget.initialCameraPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: widget.onMapCreated,
          mapType: MapType.normal,
          initialCameraPosition: cameraPosition,
          markers: widget.markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: true,
        ),
        Positioned(
          bottom: 24,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.my_location, color: primaryPurple),
              onPressed: () {
                // This would implement re-centering to user location
              },
            ),
          ),
        ),
        if (widget.markers.isEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, color: lightPurple, size: 32),
                  SizedBox(height: 8),
                  Text(
                    "No ride offers in this area",
                    style: TextStyle(
                      color: primaryPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ModernRidesFilter extends StatelessWidget {
  final Function(RideOfferFilter) onFilterChanged;
  final Function(RideOfferSortBy) onSortChanged;
  final RideOfferFilter? selectedFilter;
  final RideOfferSortBy? selectedSort;

  const ModernRidesFilter({
    super.key,
    required this.onFilterChanged,
    required this.onSortChanged,
    this.selectedFilter,
    this.selectedSort,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildFilterChip(
                context,
                RideOfferFilter.All,
                'All Rides',
                Icons.all_inclusive,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                RideOfferFilter.byMe,
                'My Rides',
                Icons.person,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                RideOfferFilter.others,
                'Others',
                Icons.people,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Sort by:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentPurple),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<RideOfferSortBy>(
                      value: selectedSort,
                      hint: const Text('Sort rides'),
                      icon: const Icon(Icons.sort, color: primaryPurple),
                      style: const TextStyle(color: primaryPurple),
                      isExpanded: true,
                      items:
                          RideOfferSortBy.values.map((RideOfferSortBy value) {
                        String label;
                        IconData icon;
                        switch (value) {
                          case RideOfferSortBy.DEFAULT:
                          case RideOfferSortBy.distance:
                            label = 'Distance';
                            icon = Icons.near_me;
                            break;
                          case RideOfferSortBy.leaveTime:
                            label = 'Departure Time';
                            icon = Icons.departure_board;
                            break;
                          case RideOfferSortBy.backTime:
                            label = 'Return Time';
                            icon = Icons.keyboard_return;
                            break;
                          case RideOfferSortBy.price:
                            label = 'Price';
                            icon = Icons.attach_money;
                            break;
                        }
                        return DropdownMenuItem<RideOfferSortBy>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(icon, size: 18, color: primaryPurple),
                              const SizedBox(width: 8),
                              Text(label),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (RideOfferSortBy? newValue) {
                        if (newValue != null) {
                          onSortChanged(newValue);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    RideOfferFilter filter,
    String label,
    IconData icon,
  ) {
    final bool isSelected = selectedFilter == filter;

    return Expanded(
      child: InkWell(
        onTap: () => onFilterChanged(filter),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryPurple : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? primaryPurple : accentPurple,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : primaryPurple,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : primaryPurple,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
