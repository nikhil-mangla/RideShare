import 'package:corider/providers/user_state.dart';
import 'package:corider/screens/chat/chat_list.dart';
import 'package:corider/screens/home/upcoming_rides.dart';
import 'package:corider/screens/home/my_offers.dart';
import 'package:corider/widgets/notification_badge.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) changePageIndex;
  final UserState userState;
  
  const HomeScreen({
    super.key, 
    required this.userState, 
    required this.changePageIndex
  });
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool isLoadingOffers = false;
  late TabController _tabController;
  
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
    // Theme colors
    final primary = Color(0xFF6200EE);
    final secondary = Color(0xFF9C27B0);
    final accent = Color(0xFFE1BEE7);
    final background = Colors.white;
    final textDark = Color(0xFF212121);
    final textLight = Color(0xFF757575);
    
    return Scaffold(
      backgroundColor: background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 140.0,
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
                      colors: [secondary, primary],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to RideShare',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Find & share rides easily',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
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
                    IconButton(
                      icon: Icon(Icons.chat_bubble_rounded, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatListScreen(userState: widget.userState),
                          ),
                        );
                      },
                    ),
                    if (widget.userState.totalNotificationsCount != 0)
                      Positioned(
                        top: 7,
                        right: widget.userState.totalNotificationsCount > 9 ? 0 : 5,
                        child: NotificationBadge(
                          totalNotifications: widget.userState.totalNotificationsCount,
                          forTotal: true,
                        ),
                      ),
                  ],
                ),
                // Profile icon removed as requested
              ],
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: primary,
                  unselectedLabelColor: textLight,
                  indicatorColor: primary,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: 'UPCOMING RIDES'),
                    Tab(text: 'MY OFFERS'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: isLoadingOffers
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  // Upcoming Rides Tab
                  RefreshIndicator(
                    color: primary,
                    onRefresh: fetchAllOffers,
                    child: UpcomingRides(
                      userState: widget.userState,
                      fetchAllOffers: fetchAllOffers,
                      changePageIndex: widget.changePageIndex,
                    ),
                  ),
                  // My Offers Tab
                  RefreshIndicator(
                    color: primary,
                    onRefresh: fetchAllOffers,
                    child: MyOffers(
                      userState: widget.userState,
                      fetchAllOffers: fetchAllOffers,
                    ),
                  ),
                ],
              ),
      ),
     
    );
  }
}

// Persistent Header Delegate for TabBar
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
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}