import 'package:rideshare/providers/user_state.dart';
import 'package:rideshare/screens/chat/chat_list.dart';
import 'package:rideshare/screens/home/upcoming_rides.dart';
import 'package:rideshare/screens/home/my_offers.dart';
import 'package:rideshare/widgets/notification_badge.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) changePageIndex;
  final UserState userState;

  const HomeScreen(
      {super.key, required this.userState, required this.changePageIndex});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool isLoadingOffers = false;
  late TabController _tabController;

  // Color scheme
  final Color primaryPurple = const Color(0xFF6200EE);
  final Color secondaryPurple = const Color(0xFF9C27B0);
  final Color lightPurple = const Color(0xFFE1BEE7);
  final Color background = Colors.white;
  final Color textDark = const Color(0xFF212121);
  final Color textLight = const Color(0xFF757575);

  Future<void> fetchAllOffers() async {
    setState(() {
      isLoadingOffers = true;
    });
    await widget.userState.fetchAllOffers();
    setState(() {
      isLoadingOffers = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.userState.storedOffers.isEmpty) fetchAllOffers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 160.0,
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: background,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [secondaryPurple, primaryPurple],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.directions_car_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'RideShare',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Find & share rides easily',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_rounded,
                            color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChatListScreen(userState: widget.userState),
                            ),
                          );
                        },
                      ),
                    ),
                    if (widget.userState.totalNotificationsCount != 0)
                      Positioned(
                        top: 7,
                        right: widget.userState.totalNotificationsCount > 9
                            ? 8
                            : 13,
                        child: NotificationBadge(
                          totalNotifications:
                              widget.userState.totalNotificationsCount,
                          forTotal: true,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: primaryPurple,
                  unselectedLabelColor: textLight,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  indicatorColor: primaryPurple,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  tabs: [
                    const Tab(text: 'UPCOMING RIDES'),
                    const Tab(text: 'MY OFFERS'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: isLoadingOffers
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryPurple),
                ),
              )
            : Container(
                color: Colors.grey[50],
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Upcoming Rides Tab
                    _buildTabContent(
                      RefreshIndicator(
                        color: primaryPurple,
                        onRefresh: fetchAllOffers,
                        child: UpcomingRides(
                          userState: widget.userState,
                          fetchAllOffers: fetchAllOffers,
                          changePageIndex: widget.changePageIndex,
                        ),
                      ),
                    ),
                    // My Offers Tab
                    _buildTabContent(
                      RefreshIndicator(
                        color: primaryPurple,
                        onRefresh: fetchAllOffers,
                        child: MyOffers(
                          userState: widget.userState,
                          fetchAllOffers: fetchAllOffers,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to create offer screen
          widget.changePageIndex(
              1); // Assuming 1 is the index for the create offer page
        },
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTabContent(Widget child) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
      ),
      child: child,
    );
  }
}

// Enhanced Persistent Header Delegate for TabBar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
