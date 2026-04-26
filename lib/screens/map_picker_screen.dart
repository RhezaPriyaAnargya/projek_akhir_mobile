import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../helpers/location_helper.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng _markerPosition = const LatLng(-7.797068, 110.370529);
  final double _zoom = 15;
  final MapController _mapController = MapController();

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
      setState(() {
        _markerPosition = latLng;
      });
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _mapController.move(latLng, _zoom);
      }
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _markerPosition = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi'),
        actions: [
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
              onMapReady: () => print('=== onMapReady ==='),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.solotrek.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _markerPosition,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
