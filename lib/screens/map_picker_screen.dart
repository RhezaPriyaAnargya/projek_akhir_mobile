import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../helpers/location_helper.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final bool viewOnly;

  const MapPickerScreen({
    super.key,
    this.initialLocation,
    this.viewOnly = false,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng _markerPosition = const LatLng(-7.797068, 110.370529);
  final double _zoom = 15;
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _nearbyPlaces = [];
  bool _isLoadingPlaces = false;
  double _radiusKm = 2.0;
  Map<String, dynamic>? _selectedPlace;

  final List<String> _overpassServers = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _markerPosition = widget.initialLocation!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _useCurrentLocation();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final position = await LocationHelper.getCurrentLocation();
    if (position != null && mounted) {
      final latLng = LocationHelper.positionToLatLng(position);
      setState(() => _markerPosition = latLng);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _mapController.move(latLng, _zoom);
        await _fetchNearbyTouristPlaces(
          latLng,
          radiusMeters: (_radiusKm * 1000).toInt(),
        );
      }
    }
  }

  Future<void> _fetchNearbyTouristPlaces(
    LatLng center, {
    int radiusMeters = 2000,
  }) async {
    setState(() {
      _isLoadingPlaces = true;
      _nearbyPlaces = [];
      _selectedPlace = null;
    });

    // Hitung bounding box dari radius
    final double latOffset = radiusMeters / 111000;
    final double lonOffset =
        radiusMeters /
        (111000 * (3.14159 / 180 * center.latitude).abs().clamp(0.01, 1.0));

    final minLat = center.latitude - latOffset;
    final maxLat = center.latitude + latOffset;
    final minLon = center.longitude - lonOffset;
    final maxLon = center.longitude + lonOffset;

    // ✅ Kategori wisata yang dicari satu per satu lalu digabung
    final List<Map<String, String>> searchTargets = [
      {'q': 'museum', 'label': 'Museum', 'type': 'museum'},
      {'q': 'candi', 'label': 'Candi / Kuil', 'type': 'temple'},
      {'q': 'taman wisata', 'label': 'Taman Wisata', 'type': 'park'},
      {'q': 'objek wisata', 'label': 'Objek Wisata', 'type': 'attraction'},
      {'q': 'kebun binatang', 'label': 'Kebun Binatang', 'type': 'zoo'},
      {'q': 'pantai', 'label': 'Pantai', 'type': 'beach_resort'},
      {'q': 'air terjun', 'label': 'Air Terjun', 'type': 'viewpoint'},
      {'q': 'monumen', 'label': 'Monumen', 'type': 'monument'},
      {'q': 'keraton', 'label': 'Istana / Keraton', 'type': 'palace'},
      {'q': 'benteng', 'label': 'Benteng', 'type': 'fort'},
    ];

    final List<Map<String, dynamic>> allPlaces = [];
    final Set<String> addedNames = {}; // hindari duplikat

    try {
      for (final target in searchTargets) {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?format=json'
          '&q=${Uri.encodeComponent(target['q']!)}'
          '&viewbox=$minLon,$maxLat,$maxLon,$minLat'
          '&bounded=1'
          '&limit=5'
          '&addressdetails=1'
          '&extratags=1',
        );

        final response = await http
            .get(url, headers: {'User-Agent': 'com.solotrek.app'})
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List data = json.decode(response.body);

          for (final e in data) {
            final name = e['display_name']?.toString().split(',').first ?? '';
            if (name.isEmpty || addedNames.contains(name)) continue;

            // ✅ Filter: buang hasil yang jelas bukan wisata
            final osmType = e['type'] ?? '';
            final osmClass = e['class'] ?? '';
            const blacklistTypes = [
              'parking',
              'fuel',
              'atm',
              'bank',
              'toilets',
              'road',
              'residential',
              'path',
              'footway',
              'administrative',
              'postcode',
              'suburb',
            ];
            if (blacklistTypes.contains(osmType)) continue;
            if (osmClass == 'highway' || osmClass == 'boundary') continue;

            addedNames.add(name);
            allPlaces.add({
              'name': name,
              'type': target['type']!,
              'category_label': target['label']!,
              'lat': double.parse(e['lat']),
              'lon': double.parse(e['lon']),
              'address': e['address'] != null
                  ? '${e['address']['road'] ?? ''} ${e['address']['city'] ?? e['address']['town'] ?? ''}'
                        .trim()
                  : '',
              'opening_hours': e['extratags']?['opening_hours'] ?? '',
              'phone': e['extratags']?['phone'] ?? '',
              'website': e['extratags']?['website'] ?? '',
              'description': e['extratags']?['description'] ?? '',
            });
          }
        }

        // ✅ Delay antar request agar tidak kena rate limit Nominatim
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Urutkan berdasarkan jarak
      final distanceCalc = Distance();
      allPlaces.sort((a, b) {
        final da = distanceCalc(center, LatLng(a['lat'], a['lon']));
        final db = distanceCalc(center, LatLng(b['lat'], b['lon']));
        return da.compareTo(db);
      });

      if (mounted) {
        setState(() {
          _nearbyPlaces = allPlaces.take(20).toList();
          _isLoadingPlaces = false;
        });

        if (_nearbyPlaces.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak ada tempat wisata ditemukan di area ini.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPlaces = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat: $e')));
      }
    }
  }

  String _getDistanceLabel(Map<String, dynamic> place) {
    final distanceCalc = Distance();
    final meters = distanceCalc(
      _markerPosition,
      LatLng(place['lat'], place['lon']),
    );
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _onPlaceTapped(Map<String, dynamic> place) {
    setState(() => _selectedPlace = place);
    _mapController.move(LatLng(place['lat'], place['lon']), _zoom);
  }

  void _showNearbyPlacesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.place, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wisata Terdekat (${_nearbyPlaces.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // ✅ Tampilkan radius aktif
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Radius ${_radiusKm.toInt()} km',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _nearbyPlaces.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Tidak ada tempat wisata ditemukan',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: _nearbyPlaces.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 70),
                      itemBuilder: (_, i) {
                        final place = _nearbyPlaces[i];
                        final distance = _getDistanceLabel(place);
                        return ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _iconForType(place['type']),
                              color: Colors.teal,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            place['name'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                place['category_label'] ?? 'Objek Wisata',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.circle,
                                size: 4,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                distance,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            // ✅ Pindah ke lokasi tempat wisata & tampilkan info panel
                            final loc = LatLng(place['lat'], place['lon']);
                            _mapController.move(loc, _zoom);
                            setState(() => _selectedPlace = place);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMapTap(LatLng location) {
    // Tutup info panel dulu jika ada
    if (_selectedPlace != null) {
      setState(() => _selectedPlace = null);
      return;
    }
    if (widget.viewOnly) return;
    setState(() => _markerPosition = location);
    _fetchNearbyTouristPlaces(
      location,
      radiusMeters: (_radiusKm * 1000).toInt(),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'museum':
        return Icons.museum;
      case 'viewpoint':
        return Icons.landscape;
      case 'theme_park':
        return Icons.attractions;
      case 'zoo':
        return Icons.pets;
      case 'artwork':
        return Icons.palette;
      case 'gallery':
        return Icons.photo;
      case 'aquarium':
        return Icons.water;
      case 'park':
        return Icons.park;
      case 'nature_reserve':
        return Icons.forest;
      case 'garden':
        return Icons.local_florist;
      case 'beach_resort':
        return Icons.beach_access;
      case 'water_park':
        return Icons.pool;
      case 'castle':
        return Icons.castle;
      case 'monument':
        return Icons.account_balance;
      case 'ruins':
      case 'archaeological_site':
        return Icons.location_city;
      case 'temple':
        return Icons.temple_buddhist;
      case 'fort':
      case 'palace':
        return Icons.fort;
      default:
        return Icons.place;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'museum':
        return 'Museum';
      case 'viewpoint':
        return 'Spot Pemandangan';
      case 'theme_park':
        return 'Taman Hiburan';
      case 'zoo':
        return 'Kebun Binatang';
      case 'artwork':
        return 'Karya Seni';
      case 'gallery':
        return 'Galeri';
      case 'aquarium':
        return 'Akuarium';
      case 'picnic_site':
        return 'Area Piknik';
      case 'information':
        return 'Pusat Informasi';
      default:
        return 'Objek Wisata';
    }
  }

  String _labelForLeisure(String type) {
    switch (type) {
      case 'park':
        return 'Taman';
      case 'nature_reserve':
        return 'Cagar Alam';
      case 'garden':
        return 'Kebun';
      case 'beach_resort':
        return 'Pantai';
      case 'water_park':
        return 'Waterpark';
      default:
        return 'Area Rekreasi';
    }
  }

  String _labelForHistoric(String type) {
    switch (type) {
      case 'castle':
        return 'Kastil';
      case 'monument':
        return 'Monumen';
      case 'ruins':
        return 'Reruntuhan';
      case 'archaeological_site':
        return 'Situs Arkeologi';
      case 'memorial':
        return 'Memorial';
      case 'temple':
        return 'Candi / Kuil';
      case 'fort':
        return 'Benteng';
      case 'palace':
        return 'Istana / Keraton';
      default:
        return 'Situs Bersejarah';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.viewOnly ? 'Peta Lokasi' : 'Pilih Lokasi'),
        actions: [
          if (_isLoadingPlaces)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          if (!widget.viewOnly)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.pop(context, _markerPosition),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _markerPosition,
              initialZoom: _zoom,
              onTap: (tapPosition, point) => _onMapTap(point),
              // ✅ viewOnly tetap bisa zoom & geser, marker tidak bisa dipindah
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.scrollWheelZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.solotrek.app',
              ),
              MarkerLayer(
                markers: [
                  // Marker utama
                  // ✅ Ganti marker utama di MarkerLayer menjadi GestureDetector
                  Marker(
                    point: _markerPosition,
                    width: 80,
                    height: 80,
                    child: GestureDetector(
                      onTap: () {
                        if (_nearbyPlaces.isEmpty) {
                          // Jika belum ada data, fetch dulu
                          _fetchNearbyTouristPlaces(
                            _markerPosition,
                            radiusMeters: (_radiusKm * 1000).toInt(),
                          );
                        } else {
                          // Jika sudah ada data, langsung tampilkan sheet
                          _showNearbyPlacesSheet();
                        }
                      },
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ),
                  // ✅ Marker tempat wisata dengan GestureDetector
                  ..._nearbyPlaces.map(
                    (place) => Marker(
                      point: LatLng(place['lat'], place['lon']),
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () => _onPlaceTapped(place),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _selectedPlace == place
                                    ? Colors.teal
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.teal,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _iconForType(place['type']),
                                color: _selectedPlace == place
                                    ? Colors.white
                                    : Colors.teal,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ✅ Slider radius (hanya jika bukan viewOnly)
          if (!widget.viewOnly)
            Positioned(
              top: 16,
              left: 16,
              right: 80,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radar, size: 18, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        '${_radiusKm.toInt()} km',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Slider(
                          value: _radiusKm,
                          min: 1,
                          max: 20,
                          divisions: 19,
                          activeColor: Colors.teal,
                          onChanged: (val) => setState(() => _radiusKm = val),
                          onChangeEnd: (val) {
                            _fetchNearbyTouristPlaces(
                              _markerPosition,
                              radiusMeters: (val * 1000).toInt(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ✅ Info panel seperti Google Maps saat marker diklik
          if (_selectedPlace != null)
            Positioned(
              bottom: widget.viewOnly ? 16 : 90,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _iconForType(_selectedPlace!['type']),
                              color: Colors.teal,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedPlace!['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _selectedPlace!['category_label'],
                                  style: TextStyle(
                                    color: Colors.teal.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => _selectedPlace = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      // Jarak
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_walk,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getDistanceLabel(_selectedPlace!),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      // Alamat
                      if (_selectedPlace!['address'].isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _selectedPlace!['address'],
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Jam buka
                      if (_selectedPlace!['opening_hours'].isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _selectedPlace!['opening_hours'],
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Telepon
                      if (_selectedPlace!['phone'].isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedPlace!['phone'],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                      // Deskripsi
                      if (_selectedPlace!['description'].isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _selectedPlace!['description'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // FAB current location (hanya jika bukan viewOnly)
          if (!widget.viewOnly)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: _useCurrentLocation,
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }
}
