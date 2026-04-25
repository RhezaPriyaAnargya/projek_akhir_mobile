import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _currentAvatarPath; // avatar shared state
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

  // Dipanggil ProfileScreen saat avatar berubah
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
          HomeView(
            avatarPath: _currentAvatarPath,
            username: _currentUsername,
          ),
          const ConverterView(),
          const GameScreen(),
          const FeedbackView(),
          ProfileScreen(onAvatarChanged: _onAvatarChanged),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.sync_alt), label: 'Tools'),
          BottomNavigationBarItem(
              icon: Icon(Icons.quiz_outlined), label: 'Game'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline), label: 'Kesan'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// ─── HomeView ─────────────────────────────────────────────────────────────────

class HomeView extends StatefulWidget {
  final String? avatarPath;
  final String username;

  const HomeView({
    super.key,
    this.avatarPath,
    this.username = 'Guest',
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
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

  Future<void> _loadUnreadCount() async {
    final count = await NotificationHelper.getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  Future<void> _loadCurrentLocation() async {
    final position = await LocationHelper.getCurrentLocation();
    if (position != null && mounted) {
      setState(() {
        _currentLocation = LocationHelper.positionToLatLng(position);
      });
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
      if (mounted) setState(() {
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'SoloTrek',
          style: TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 24),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none,
                    color: Colors.blueAccent),
                onPressed: _showNotificationPanel,
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
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
            const SizedBox(height: 24),
            _buildAIBanner(),
            const SizedBox(height: 24),
            _buildMapPlaceholder(),
            const SizedBox(height: 24),
            _buildMyPlansList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingAndWeather() {
    // Gunakan avatarPath dari parent (realtime)
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
                    'Halo, ${widget.username}!',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text('Siap menjelajah hari ini?',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.blueAccent,
              backgroundImage:
                  avatarPath != null && File(avatarPath).existsSync()
                      ? FileImage(File(avatarPath)) as ImageProvider
                      : null,
              child: avatarPath == null || !File(avatarPath).existsSync()
                  ? const Icon(Icons.person, size: 25, color: Colors.white)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _isLoadingWeather
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const SizedBox(
                  height: 50,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            : GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WeatherDetailScreen(
                        city: _weatherData?.city ?? 'Yogyakarta'),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        WeatherHelper.getWeatherEmoji(
                            _weatherData?.icon ?? '01d'),
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_weatherData?.city ?? 'Unknown',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${_weatherData?.temperature.toStringAsFixed(1)}°C',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent)),
                            Text(_weatherData?.description ?? 'Loading...',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.blueAccent),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
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
          colors: [Colors.blueAccent, Colors.lightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.blueAccent.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trekker AI Assistant',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                    'Biar AI yang merancang jadwal liburanmu secara otomatis.',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                color: Colors.white24, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lokasi Saat Ini',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: FlutterMap(
              options:
                  MapOptions(initialCenter: _currentLocation, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.solotrek.app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: _currentLocation,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.blueAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.location_on,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ]),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            onChanged: _filterPlans,
            decoration: InputDecoration(
              hintText: 'Cari rencana perjalanan...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () => _filterPlans(''),
                      child: const Icon(Icons.close, color: Colors.grey))
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Rencana Perjalanan Saya',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_searchQuery.isNotEmpty)
              Text('${_filteredPlans.length} hasil',
                  style:
                      const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 12),
        _filteredPlans.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'Belum ada rencana perjalanan.\nKetuk tombol + untuk mulai!'
                        : 'Tidak ada rencana yang cocok\ndengan "$_searchQuery"',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
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
          MaterialPageRoute(
              builder: (context) => DetailPlanScreen(plan: plan)),
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
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child:
                  const Icon(Icons.flight_takeoff, color: Colors.blueAccent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan['title'],
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(plan['date'],
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(plan['location'],
                      style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─── Notification Bottom Sheet ────────────────────────────────────────────────

class _NotificationBottomSheet extends StatefulWidget {
  final List<NotifItem> notifications;
  final VoidCallback onClearAll;

  const _NotificationBottomSheet(
      {required this.notifications, required this.onClearAll});

  @override
  State<_NotificationBottomSheet> createState() =>
      _NotificationBottomSheetState();
}

class _NotificationBottomSheetState
    extends State<_NotificationBottomSheet> {
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
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Notifikasi',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_notifs.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          widget.onClearAll();
                          setState(() => _notifs = []);
                        },
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.redAccent),
                        label: const Text('Hapus Semua',
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _notifs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none,
                                size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('Belum ada notifikasi',
                                style: TextStyle(
                                    color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _notifs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 70),
                        itemBuilder: (context, index) {
                          final notif = _notifs[index];
                          final isReminder =
                              notif.id.startsWith('reminder');
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isReminder
                                    ? Colors.orange.shade50
                                    : Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isReminder
                                    ? Icons.alarm
                                    : Icons.flight_takeoff,
                                color: isReminder
                                    ? Colors.orange
                                    : Colors.blueAccent,
                                size: 22,
                              ),
                            ),
                            title: Text(notif.title,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(notif.body,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                Text(_timeAgo(notif.time),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400)),
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