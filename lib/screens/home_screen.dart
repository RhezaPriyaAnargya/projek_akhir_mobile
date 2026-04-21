import 'package:flutter/material.dart';
import 'profile_screen.dart'; 
import 'detail_plan_screen.dart';
import 'add_plan_screen.dart'; 
import '../helpers/database_helper.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const HomeView(),      
    const ConverterView(), 
    const FeedbackView(),  
    const ProfileScreen(), 
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, 
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.sync_alt), label: 'Tools'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Kesan'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// ============================================================================
// --- TAB 1: DASHBOARD VIEW (BERANDA UTAMA) ---
// ============================================================================
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _plans = [];
  String _username = 'Guest';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _refreshPlans();
  }

  Future<void> _loadUserData() async {
    final session = await _dbHelper.getCurrentSession();
    if (session != null) {
      setState(() {
        _username = session['username'] ?? 'Guest';
      });
    }
  }
  
  Future<void> _refreshPlans() async {
    final data = await _dbHelper.getPlans();
    setState(() {
      _plans = data;
    });
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
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.blueAccent),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Belum ada notifikasi baru.')),
              );
            },
          )
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Halo, $_username!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('Siap menjelajah hari ini?', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
          child: const Row(
            children: [
              Icon(Icons.wb_sunny, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yogyakarta', style: TextStyle(fontSize: 10, color: Colors.blueAccent)),
                  Text('28°C Cerah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAIBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.lightBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trekker AI Assistant', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Biar AI yang merancang jadwal liburanmu secara otomatis.', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
          )
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lokasi Saat Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          height: 150, width: double.infinity,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade400)),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text('(Integrasi Google Maps API di sini)', style: TextStyle(color: Colors.grey)),
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
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Rencana Perjalanan Saya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Icon(Icons.search, color: Colors.grey), 
          ],
        ),
        const SizedBox(height: 12),
        
        _plans.isEmpty 
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Belum ada rencana perjalanan.\nKetuk tombol + untuk mulai!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          : ListView.builder(
              shrinkWrap: true, 
              physics: const NeverScrollableScrollPhysics(), 
              itemCount: _plans.length,
              itemBuilder: (context, index) {
                final plan = _plans[index];
                return _buildTripCard(plan);
              },
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
        
        if (result == true) {
          _refreshPlans();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.flight_takeoff, color: Colors.blueAccent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(plan['date'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(plan['location'], style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// --- TAB 2: CONVERTER VIEW ---
// ============================================================================
class ConverterView extends StatelessWidget {
  const ConverterView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Tools')),
      body: const Center(child: Text('Fitur Konversi Mata Uang & Waktu')),
    );
  }
}

// ============================================================================
// --- TAB 3: FEEDBACK VIEW ---
// ============================================================================
class FeedbackView extends StatelessWidget {
  const FeedbackView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saran & Kesan TPM')),
      body: const Center(child: Text('Halaman Input Saran & Kesan Kuliah TPM')),
    );
  }
}