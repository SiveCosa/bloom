import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/event/event_location.dart';

enum LocationModalState { search, details }

class LocationSelectionModal extends StatefulWidget {
  final EventLocation? initialLocation;
  const LocationSelectionModal({super.key, this.initialLocation});

  @override
  State<LocationSelectionModal> createState() => _LocationSelectionModalState();
}

class _LocationSelectionModalState extends State<LocationSelectionModal> {
  LocationModalState _currentState = LocationModalState.search;
  
  // Search State Variables
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  List<EventLocation> _recentLocations = [];
  bool _isSearching = false;

  // Details State Variables
  EventLocation? _selectedLocation;
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _aptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecentLocations();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _displayNameController.text = widget.initialLocation!.displayName;
      _aptController.text = widget.initialLocation!.apartmentInfo ?? '';
      _currentState = LocationModalState.details;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _displayNameController.dispose();
    _aptController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final recentList = prefs.getStringList('recent_locations') ?? [];
    setState(() {
      _recentLocations = recentList
          .map((item) => EventLocation.fromMap(jsonDecode(item)))
          .toList();
    });
  }

  Future<void> _saveRecentLocation(EventLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    // Remove if exists to put it at the top
    _recentLocations.removeWhere((loc) => loc.formattedAddress == location.formattedAddress);
    _recentLocations.insert(0, location);
    if (_recentLocations.length > 10) {
      _recentLocations = _recentLocations.sublist(0, 10);
    }
    await prefs.setStringList(
        'recent_locations', _recentLocations.map((loc) => jsonEncode(loc.toMap())).toList());
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _fetchPlacesAutocomplete(query);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _fetchPlacesAutocomplete(String query) async {
    setState(() => _isSearching = true);
    
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'africa-south1')
          .httpsCallable('googleMapsProxy')
          .call({
        'endpoint': 'autocomplete',
        'params': {'input': query},
      });

      final data = result.data as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        setState(() {
          _searchResults = data['predictions'];
        });
      } else {
        debugPrint('Google Maps Proxy Error: ${data['status']} - ${data['error_message']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Maps Error: ${data['error_message'] ?? data['status']}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Places API Exception: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _fetchPlaceDetails(String placeId) async {
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'africa-south1')
          .httpsCallable('googleMapsProxy')
          .call({
        'endpoint': 'details',
        'params': {'place_id': placeId},
      });

      final data = result.data as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        final details = data['result'];
        final lat = details['geometry']['location']['lat'];
        final lng = details['geometry']['location']['lng'];
        
        setState(() {
          _selectedLocation = EventLocation(
            latitude: lat,
            longitude: lng,
            formattedAddress: details['formatted_address'],
            displayName: details['name'],
          );
          _displayNameController.text = details['name'];
          _currentState = LocationModalState.details;
        });
      } else {
        debugPrint('Google Maps Proxy Error: ${data['status']} - ${data['error_message']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Maps Error: ${data['error_message'] ?? data['status']}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Place Details API Exception: $e');
    }
  }

  Future<void> _useCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    setState(() => _isSearching = true);
    try {
      Position position = await Geolocator.getCurrentPosition();
      
      final result = await FirebaseFunctions.instanceFor(region: 'africa-south1')
          .httpsCallable('googleMapsProxy')
          .call({
        'endpoint': 'geocode',
        'params': {'latlng': '${position.latitude},${position.longitude}'},
      });

      final data = result.data as Map<String, dynamic>;
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final resultData = data['results'][0];
        setState(() {
          _selectedLocation = EventLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            formattedAddress: resultData['formatted_address'],
            displayName: resultData['formatted_address'].split(',')[0],
          );
          _displayNameController.text = _selectedLocation!.displayName;
          _currentState = LocationModalState.details;
        });
      } else {
        debugPrint('Google Maps Proxy Error: ${data['status']} - ${data['error_message']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Geocoding Error: ${data['error_message'] ?? data['status']}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Current Location Exception: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _handleSave() async {
    if (_selectedLocation == null) return;
    
    final finalLocation = EventLocation(
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      formattedAddress: _selectedLocation!.formattedAddress,
      displayName: _displayNameController.text.isNotEmpty 
          ? _displayNameController.text 
          : _selectedLocation!.displayName,
      apartmentInfo: _aptController.text.isNotEmpty ? _aptController.text : null,
    );

    await _saveRecentLocation(finalLocation);
    if (!mounted) return;
    Navigator.pop(context, finalLocation);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF191B1D),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_currentState == LocationModalState.details)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _handleSave,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Color(0xFF6C8EEF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Body
              Expanded(
                child: _currentState == LocationModalState.search
                    ? _buildSearchView()
                    : _buildDetailsView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchView() {
    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            height: 50,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Place name or address',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white54,
                          size: 16,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          )
        else if (_searchController.text.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final prediction = _searchResults[index];
                return _buildSearchResultItem(
                  title: prediction['structured_formatting']['main_text'],
                  subtitle: prediction['structured_formatting']['secondary_text'] ?? '',
                  onTap: () => _fetchPlaceDetails(prediction['place_id']),
                );
              },
            ),
          )
        else
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.gps_fixed, color: Colors.white70, size: 22),
                    ),
                    title: const Text(
                      'Use current location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    onTap: _useCurrentLocation,
                  ),
                ),
                if (_recentLocations.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(10, 24, 10, 16),
                    child: Text(
                      'Recent Places',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._recentLocations.map((loc) => _buildSearchResultItem(
                    title: loc.displayName,
                    subtitle: loc.formattedAddress,
                    icon: Icons.history,
                    onTap: () {
                      setState(() {
                        _selectedLocation = loc;
                        _displayNameController.text = loc.displayName;
                        _aptController.text = loc.apartmentInfo ?? '';
                        _currentState = LocationModalState.details;
                      });
                    },
                  )),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResultItem({
    required String title,
    required String subtitle,
    IconData icon = Icons.location_on_outlined,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: 80.0,
        alignment: Alignment.center,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsView() {
    if (_selectedLocation == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Location Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedLocation!.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedLocation!.formattedAddress,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _currentState = LocationModalState.search;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 24),
  
          _buildTextField(
            controller: _displayNameController,
            hint: 'Location name',
            label: 'Display name',
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _aptController,
            hint: 'ex: Apt 34B',
            label: 'Apt / Suit / Floor',
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
