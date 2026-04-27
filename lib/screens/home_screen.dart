import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'profile_screen.dart';
import 'detail_plan_screen.dart';
import 'weather_detail_screen.dart';
import 'add_plan_screen.dart';
import '../helpers/database_helper.dart';
import '../helpers/weather_helper.dart';
import '../helpers/location_helper.dart';
import '../helpers/notification_helper.dart';
import 'travel_utilities_screen.dart';
import 'game_screen.dart';
import 'kesan_screen.dart';

// Brand colors
const Color _navy = Color(0xFF1A3557);
const Color _teal = Color(0xFF2ABFBF);
const Color _cream = Color(0xFFF5F0E8);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _currentAvatarPath;
  String _currentUsername = 'Guest';

  @override
  void initState() {
    super.initState();
    _loadInitialAvatar();
  }

  Future<void> _loadInitialAvatar() async {
    final db = DatabaseHelper();
    final session = await db.getCurrentSession();
    if (session != null) {
      final username = session['username'] ?? 'Guest';
      final avatar = await db.getUserAvatar(username);
      if (mounted) {
        setState(() {
          _currentUsername = username;
          _currentAvatarPath = avatar;
        });
      }
    }
  }

  void _onAvatarChanged(String? newPath) {
    setState(() => _currentAvatarPath = newPath);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeView(avatarPath: _currentAvatarPath, username: _currentUsername),
          const ConverterView(),
          const GameScreen(),
          const FeedbackView(),
          ProfileScreen(onAvatarChanged: _onAvatarChanged),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: _navy,
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sync_alt_outlined),
              activeIcon: Icon(Icons.sync_alt),
              label: 'Tools',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.quiz_outlined),
              activeIcon: Icon(Icons.quiz_rounded),
              label: 'Game',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Kesan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── HomeView ──────────────────────────────────────────────────────────────────

class HomeView extends StatefulWidget {
  final String? avatarPath;
  final String username;

  const HomeView({super.key, this.avatarPath, this.username = 'Guest'});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final MapController _homeMapController = MapController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _filteredPlans = [];
  String _searchQuery = '';
  WeatherData? _weatherData;
  bool _isLoadingWeather = true;
  LatLng _currentLocation = LocationHelper.defaultLocation;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshPlans();
    _loadWeather();
    _loadCurrentLocation();
    _loadUnreadCount();
  }

  @override
  void dispose() {
    _homeMapController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationHelper.getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  Future<void> _loadCurrentLocation() async {
    final position = await LocationHelper.getCurrentLocation();
    if (position != null && mounted) {
      final latLng = LocationHelper.positionToLatLng(position);
      setState(() => _currentLocation = latLng);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _homeMapController.move(latLng, 15);
    }
  }

  Future<void> _refreshPlans() async {
    final data = await _dbHelper.getPlans();
    if (mounted) {
      setState(() {
        _plans = data;
        _filteredPlans = data;
        _searchQuery = '';
      });
    }
  }

  Future<void> _loadWeather() async {
    setState(() => _isLoadingWeather = true);
    try {
      final weather = await WeatherHelper.getWeatherByCity('Yogyakarta');
      if (mounted)
        setState(() {
          _weatherData = weather;
          _isLoadingWeather = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  void _filterPlans(String query) {
    setState(() {
      _searchQuery = query;
      _filteredPlans = query.isEmpty
          ? _plans
          : _plans.where((plan) {
              final q = query.toLowerCase();
              return plan['title'].toString().toLowerCase().contains(q) ||
                  plan['location'].toString().toLowerCase().contains(q) ||
                  plan['date'].toString().toLowerCase().contains(q);
            }).toList();
    });
  }

  void _showNotificationPanel() async {
    await NotificationHelper.markAllAsRead();
    setState(() => _unreadCount = 0);
    final notifications = await NotificationHelper.getInAppNotifications();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationBottomSheet(
        notifications: notifications,
        onClearAll: () async {
          await NotificationHelper.clearAllInApp();
          if (mounted) setState(() => _unreadCount = 0);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/icon/app_icon.png', width: 28, height: 28),
            const SizedBox(width: 8),
            const Text(
              'SoloTrek',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
                onPressed: _showNotificationPanel,
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _teal,
        elevation: 4,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPlanScreen()),
          );
          if (result == true) {
            _refreshPlans();
            _loadUnreadCount();
          }
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreetingAndWeather(),
            const SizedBox(height: 20),
            _buildAIBanner(),
            const SizedBox(height: 20),
            _buildMapSection(),
            const SizedBox(height: 20),
            _buildMyPlansList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingAndWeather() {
    final avatarPath = widget.avatarPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${widget.username}! 👋',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Siap menjelajah hari ini?',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _teal, width: 2),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: _navy,
                backgroundImage:
                    avatarPath != null && File(avatarPath).existsSync()
                    ? FileImage(File(avatarPath)) as ImageProvider
                    : null,
                child: avatarPath == null || !File(avatarPath).existsSync()
                    ? const Icon(Icons.person, size: 24, color: Colors.white)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Weather card
        _isLoadingWeather
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _navy.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const SizedBox(
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _teal,
                    ),
                  ),
                ),
              )
            : GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WeatherDetailScreen(
                      city: _weatherData?.city ?? 'Yogyakarta',
                    ),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _navy.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        WeatherHelper.getWeatherEmoji(
                          _weatherData?.icon ?? '01d',
                        ),
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _weatherData?.city ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _teal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_weatherData?.temperature.toStringAsFixed(1)}°C',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _navy,
                              ),
                            ),
                            Text(
                              _weatherData?.description ?? 'Loading...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildAIBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, Color(0xFF254878)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trekker AI Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Biar AI yang merancang jadwal liburanmu secara otomatis.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lokasi Saat Ini',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _navy,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FlutterMap(
              mapController: _homeMapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.solotrek.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _navy,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _navy.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyPlansList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            onChanged: _filterPlans,
            decoration: InputDecoration(
              hintText: 'Cari rencana perjalanan...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: _teal),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () => _filterPlans(''),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.grey.shade400,
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),

        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Rencana Perjalanan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_filteredPlans.length} hasil',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        _filteredPlans.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.luggage_rounded,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Belum ada rencana perjalanan.\nKetuk tombol + untuk mulai!'
                            : 'Tidak ada rencana yang cocok\ndengan "$_searchQuery"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredPlans.length,
                itemBuilder: (context, index) =>
                    _buildTripCard(_filteredPlans[index]),
              ),
      ],
    );
  }

  Widget _buildTripCard(Map<String, dynamic> plan) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailPlanScreen(plan: plan)),
        );
        if (result == true) _refreshPlans();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.flight_takeoff_rounded,
                color: _navy,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan['title'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 11,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        plan['date'],
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 11,
                        color: _teal,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          plan['location'],
                          style: const TextStyle(
                            color: _teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Notification Bottom Sheet ─────────────────────────────────────────────────

class _NotificationBottomSheet extends StatefulWidget {
  final List<NotifItem> notifications;
  final VoidCallback onClearAll;

  const _NotificationBottomSheet({
    required this.notifications,
    required this.onClearAll,
  });

  @override
  State<_NotificationBottomSheet> createState() =>
      _NotificationBottomSheetState();
}

class _NotificationBottomSheetState extends State<_NotificationBottomSheet> {
  late List<NotifItem> _notifs;

  @override
  void initState() {
    super.initState();
    _notifs = widget.notifications;
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notifikasi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    if (_notifs.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          widget.onClearAll();
                          setState(() => _notifs = []);
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Hapus Semua',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: _notifs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 56,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada notifikasi',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _notifs.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 70,
                          color: Colors.grey.shade100,
                        ),
                        itemBuilder: (context, index) {
                          final notif = _notifs[index];
                          final isReminder = notif.id.startsWith('reminder');
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isReminder
                                    ? Colors.orange.shade50
                                    : _navy.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isReminder
                                    ? Icons.alarm_rounded
                                    : Icons.flight_takeoff_rounded,
                                color: isReminder ? Colors.orange : _navy,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              notif.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _navy,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  notif.body,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _timeAgo(notif.time),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ConverterView extends StatelessWidget {
  const ConverterView({super.key});

  @override
  Widget build(BuildContext context) => const TravelUtilitiesScreen();
}

class FeedbackView extends StatelessWidget {
  const FeedbackView({super.key});

  @override
  Widget build(BuildContext context) => const KesanScreen();
}
