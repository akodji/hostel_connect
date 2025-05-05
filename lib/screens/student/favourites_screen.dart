import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hostel_detail_screen.dart';

final supabase = Supabase.instance.client;

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> _favoriteHostels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _favoriteHostels = [];
        });
        return;
      }

      // Corrected join query - using the proper foreign key relationship
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

      setState(() {
        _favoriteHostels = favoriteHostels;
        _isLoading = false;
      });
    } catch (error) {
      print('Error loading favorites: $error');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading favorites: $error')),
      );
    }
  }

  Future<double> _getHostelRating(int hostelId) async {
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
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      await supabase
          .from('favorites')
          .delete()
          .match({'user_id': userId, 'hostel_id': hostelId});
      
      setState(() {
        _favoriteHostels.removeWhere((hostel) => hostel['id'] == hostelId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from favorites')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing favorite: $error')),
      );
    }
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteHostels.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
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
    return ListView.builder(
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
                    child: hostel['image_url'] != null
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
    );
  }
}