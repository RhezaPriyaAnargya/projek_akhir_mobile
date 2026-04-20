import 'package:flutter/material.dart';
import 'profile_screen.dart'; // Import halaman profil yang sudah dibuat

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Daftar halaman yang akan ditampilkan sesuai index tab
  static final List<Widget> _pages = <Widget>[
    const HomeView(),      // Tab 1: Dashboard
    const ConverterView(), // Tab 2: Konversi (Uang & Waktu)
    const FeedbackView(),  // Tab 3: Saran & Kesan
    const ProfileScreen(), // Tab 4: Profil & Logout
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
        type: BottomNavigationBarType.fixed, // Agar label terlihat semua
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

// --- TAB 1: DASHBOARD VIEW (PLACEHOLDER) ---
class HomeView extends StatelessWidget {
  const HomeView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SoloTrek Beranda')),
      body: const Center(child: Text('Halaman Utama Travel Planner')),
    );
  }
}

// --- TAB 2: CONVERTER VIEW (MATA UANG & WAKTU) ---
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

// --- TAB 3: FEEDBACK VIEW (SARAN & KESAN TPM) ---
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