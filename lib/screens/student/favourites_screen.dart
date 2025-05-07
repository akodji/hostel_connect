import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hostel_detail_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hostel_connect/services/connectivity_service.dart';

final supabase = Supabase.instance.client;

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> _favoriteHostels = [];
  bool _isLoading = true;
  bool _isOnline = true;
  late ConnectivityService _connectivityService;
  List<Map<String, dynamic>> _pendingRemovals = [];

  @override
  void initState() {
    super.initState();
    _connectivityService = ConnectivityService();
    _initConnectivity();
    _loadFavorites();
  }

  Future<void> _initConnectivity() async {
    await _connectivityService.initialize();
    _isOnline = _connectivityService.isConnected;
    
    _connectivityService.connectivityStream.listen((isConnected) {
      setState(() {
        _isOnline = isConnected;
      });
      
      if (isConnected) {
        _syncPendingActions();
        _loadFavorites(); // Refresh data when back online
      }
    });
  }

  Future<void> _syncPendingActions() async {
    // Process any pending removals
    if (_pendingRemovals.isNotEmpty) {
      await _processPendingRemovals();
    }
  }

  Future<void> _processPendingRemovals() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    List<Map<String, dynamic>> failedRemovals = [];
    
    for (final removal in _pendingRemovals) {
      try {
        await supabase
            .from('favorites')
            .delete()
            .match({'user_id': userId, 'hostel_id': removal['hostel_id']});
      } catch (error) {
        print('Error syncing removal: $error');
        failedRemovals.add(removal);
      }
    }
    
    // Update pending removals with only failed ones
    _pendingRemovals = failedRemovals;
    await _savePendingRemovals();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final userId = supabase.auth.currentUser?.id;
    
    // Load pending removals
    await _loadPendingRemovals();

    if (_isOnline) {
      // Online mode: Load from Supabase
      try {
        if (userId == null) {
          setState(() {
            _isLoading = false;
            _favoriteHostels = [];
          });
          return;
        }

        final response = await supabase
            .from('favorites')
            .select('''
              id,
              hostel_id,
              hostels(
                id,
                name,
                image_url,
                price,
                location,
                available_rooms
              )
            ''')
            .eq('user_id', userId);

        List<Map<String, dynamic>> favoriteHostels = [];
        
        for (var item in response) {
          final hostel = item['hostels'];
          if (hostel != null) {
            final double rating = await _getHostelRating(hostel['id']);
            favoriteHostels.add({
              'id': hostel['id'],
              'name': hostel['name'],
              'image_url': hostel['image_url'],
              'price': hostel['price'],
              'location': hostel['location'],
              'rating': rating,
              'available_rooms': hostel['available_rooms'],
            });
          }
        }

        // Remove any hostels that are in pending removals
        favoriteHostels.removeWhere((hostel) => 
          _pendingRemovals.any((removal) => removal['hostel_id'] == hostel['id']));

        // Cache the fetched data
        await prefs.setString('cached_favorites', jsonEncode(favoriteHostels));
        
        setState(() {
          _favoriteHostels = favoriteHostels;
          _isLoading = false;
        });
      } catch (error) {
        print('Error loading favorites: $error');
        // If online fetch fails, try to load from cache
        await _loadFromCache();
      }
    } else {
      // Offline mode: Load from local storage
      await _loadFromCache();
    }
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cached_favorites');
    
    if (cachedData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedData);
        List<Map<String, dynamic>> favoriteHostels = 
            decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        
        // Remove any hostels that are in pending removals
        favoriteHostels.removeWhere((hostel) => 
          _pendingRemovals.any((removal) => removal['hostel_id'] == hostel['id']));
        
        setState(() {
          _favoriteHostels = favoriteHostels;
          _isLoading = false;
        });
      } catch (e) {
        print('Error parsing cached favorites: $e');
        setState(() {
          _favoriteHostels = [];
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _favoriteHostels = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPendingRemovals() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingData = prefs.getString('pending_removals');
    
    if (pendingData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(pendingData);
        _pendingRemovals = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      } catch (e) {
        print('Error parsing pending removals: $e');
        _pendingRemovals = [];
      }
    } else {
      _pendingRemovals = [];
    }
  }

  Future<void> _savePendingRemovals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_removals', jsonEncode(_pendingRemovals));
  }

  Future<double> _getHostelRating(int hostelId) async {
    if (!_isOnline) {
      // Try to get cached rating from the hostel object
      final hostel = _favoriteHostels.firstWhere(
        (h) => h['id'] == hostelId, 
        orElse: () => {'rating': 0.0}
      );
      return hostel['rating'] ?? 0.0;
    }
    
    try {
      final reviewsResponse = await supabase
          .from('reviews')
          .select('rating')
          .eq('hostel_id', hostelId);
      
      if (reviewsResponse.isEmpty) {
        return 0.0;
      }
      
      double totalRating = 0;
      for (var review in reviewsResponse) {
        totalRating += review['rating'] as double;
      }
      
      return totalRating / reviewsResponse.length;
    } catch (error) {
      print('Error getting hostel rating: $error');
      return 0.0;
    }
  }

  Future<void> _removeFavorite(int hostelId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    // Remove from local state immediately
    setState(() {
      _favoriteHostels.removeWhere((hostel) => hostel['id'] == hostelId);
    });
    
    // Update cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_favorites', jsonEncode(_favoriteHostels));
    
    if (_isOnline) {
      try {
        await supabase
            .from('favorites')
            .delete()
            .match({'user_id': userId, 'hostel_id': hostelId});
            
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites')),
        );
      } catch (error) {
        // Add to pending removals if online removal fails
        _addPendingRemoval(hostelId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Favorite will be removed when online')),
        );
      }
    } else {
      // Add to pending removals if offline
      _addPendingRemoval(hostelId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Favorite will be removed when back online')),
      );
    }
  }

  void _addPendingRemoval(int hostelId) {
    _pendingRemovals.add({'hostel_id': hostelId, 'timestamp': DateTime.now().toIso8601String()});
    _savePendingRemovals();
  }

  void _navigateToHostelDetail(int hostelId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostelDetailScreen(hostelId: hostelId),
      ),
    ).then((_) => _loadFavorites()); // Reload favorites when returning from detail screen
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Favorites',
          style: TextStyle(
            color: Color(0xFF324054),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF324054)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isOnline)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Icon(
                Icons.cloud_off,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          if (!_isOnline)
            Container(
              width: double.infinity,
              color: Colors.amber[100],
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are offline. Changes will be synced when you are back online.',
                      style: TextStyle(
                        color: Colors.amber[800],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _favoriteHostels.isEmpty
                    ? _buildEmptyState()
                    : _buildFavoritesList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No favorites yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add hostels to your favorites to see them here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favoriteHostels.length,
        itemBuilder: (context, index) {
          final hostel = _favoriteHostels[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () => _navigateToHostelDetail(hostel['id']),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hostel Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: hostel['image_url'] != null && _isOnline
                          ? Image.network(
                              hostel['image_url'],
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 160,
                                  color: Colors.grey[200],
                                  child: const Center(child: Icon(Icons.image, size: 40)),
                                );
                              },
                            )
                          : Container(
                              height: 160,
                              color: Colors.grey[200],
                              child: const Center(child: Icon(Icons.image, size: 40)),
                            ),
                    ),
                    // Hostel Details
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  hostel['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF324054),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.favorite, color: Colors.red),
                                onPressed: () => _removeFavorite(hostel['id']),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFF6C63FF),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  hostel['location'] ?? 'Unknown location',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF324054).withOpacity(0.7),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Color(0xFFFFA726),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hostel['rating'].toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF324054),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "GH₵${hostel['price']}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A6FE3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (hostel['available_rooms'] ?? 0) > 0
                                  ? const Color(0xFF2DCE89).withOpacity(0.1)
                                  : const Color(0xFFF75676).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (hostel['available_rooms'] ?? 0) > 0 ? "Available" : "Full",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: (hostel['available_rooms'] ?? 0) > 0
                                    ? const Color(0xFF2DCE89)
                                    : const Color(0xFFF75676),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}