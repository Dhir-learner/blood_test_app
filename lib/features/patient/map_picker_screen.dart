import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng _selectedLocation = const LatLng(51.5, -0.09); // Default: London (Placeholder)
  String _selectedAddress = "Unknown Address";
  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _isLoading = true;

  // Nominatim's usage policy requires an identifying User-Agent with contact info.
  static const _nominatimHeaders = {
    'User-Agent': 'BloodTestApp/1.0 (dhirthakar8503@gmail.com)',
  };
  
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // A cached fix returns immediately. Asking for a live one registers GPS
      // and NMEA listeners, which can block until the OS answers — that hangs
      // the app on emulators and indoors, so it is only a fallback and is
      // given a hard time limit.
      final cached = await Geolocator.getLastKnownPosition();
      final position = cached ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );

      if (!mounted) return;
      setState(() => _selectedLocation = LatLng(position.latitude, position.longitude));
      // On first load the map isn't built yet; it will open at initialCenter instead.
      if (_mapReady) _mapController.move(_selectedLocation, 15.0);
      _reverseGeocode(_selectedLocation);
    } catch (e) {
      debugPrint("Error getting location: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final response = await http.get(
        Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'format': 'json',
          'lat': '${location.latitude}',
          'lon': '${location.longitude}',
        }),
        headers: _nominatimHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _selectedAddress = data['display_name'] ?? "Unknown Address";
        });
      }
    } catch (e) {
      debugPrint("Error reverse geocoding: $e");
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        return;
      }
      setState(() {
        _isSearching = true;
      });
      try {
        // Uri.https encodes the query, so characters like & or # can't inject parameters.
        final response = await http.get(
          Uri.https('nominatim.openstreetmap.org', '/search', {
            'format': 'json',
            'q': query,
            'limit': '5',
          }),
          headers: _nominatimHeaders,
        );
        if (response.statusCode == 200 && mounted) {
          setState(() => _searchResults = json.decode(response.body));
        }
      } catch (e) {
        debugPrint("Search error: $e");
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _selectSearchResult(dynamic result) {
    final lat = double.parse(result['lat']);
    final lon = double.parse(result['lon']);
    final address = result['display_name'];

    setState(() {
      _selectedLocation = LatLng(lat, lon);
      _selectedAddress = address;
      _searchResults = [];
      _searchController.text = address;
      FocusScope.of(context).unfocus();
    });
    _mapController.move(_selectedLocation, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Location"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // Now returning a map with both coordinates and the human readable address
              Navigator.pop(context, {
                'location': _selectedLocation,
                'address': _selectedAddress,
              });
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 15.0,
                    onMapReady: () => _mapReady = true,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLocation = point;
                        _searchResults = [];
                        FocusScope.of(context).unfocus();
                      });
                      _reverseGeocode(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.bloodtestapp',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation,
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
                // Search Bar Overlay
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 5,
                            )
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: "Search for address...",
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                      });
                                    },
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 5.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 5)
                            ],
                          ),
                          constraints: const BoxConstraints(maxHeight: 250),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              return ListTile(
                                leading: const Icon(Icons.location_city),
                                title: Text(
                                  result['display_name'] ?? 'Unknown',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectSearchResult(result),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                // Address Bar Outline at Bottom
                 Positioned(
                  bottom: 80,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text(
                      _selectedAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
