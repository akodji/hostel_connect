import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({Key? key}) : super(key: key);

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _hostels = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  String? _selectedHostelId;
  double _averageRating = 0;

  @override
  void initState() {
    super.initState();
    _loadHostels();
     _debugUserProfiles();
  }

  Future<void> _loadHostels() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to view your hostels')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch hostels owned by the current user
      final hostelsResponse = await _supabase
          .from('hostels')
          .select('id, name')
          .eq('owner_id', userId);

      setState(() {
        _hostels = List<Map<String, dynamic>>.from(hostelsResponse);
        _isLoading = false;
      });

      // If there are hostels, load reviews for the first one by default
      if (_hostels.isNotEmpty) {
        _selectedHostelId = _hostels.first['id'].toString();
        // Ensure we have a valid hostel ID before loading reviews
        if (_selectedHostelId != null) {
          _loadReviews();
        }
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading hostels: $error')),
      );
    }
  }

void _printProfileDebugInfo(dynamic profileResponse, String userId) {
  print('Profile response for user $userId:');
  print('Response type: ${profileResponse.runtimeType}');
  print('Response content: $profileResponse');
  
  if (profileResponse is Map) {
    profileResponse.forEach((key, value) {
      print('$key: $value (${value.runtimeType})');
    });
  }
}

Future<void> _loadReviews() async {
  if (_selectedHostelId == null) return;

  try {
    setState(() {
      _isLoading = true;
    });

    // First fetch reviews for the selected hostel without joining
    final reviewsResponse = await _supabase
        .from('reviews')
        .select('id, hostel_id, user_id, rating, comment, created_at')
        .eq('hostel_id', int.parse(_selectedHostelId!))
        .order('created_at', ascending: false);

    final reviews = List<Map<String, dynamic>>.from(reviewsResponse);
    
    // Calculate average rating
    double totalRating = 0;
for (var review in reviews) {
  // Handle both int and double types for rating
  if (review['rating'] is int) {
    totalRating += (review['rating'] as int).toDouble();
  } else if (review['rating'] is double) {
    totalRating += review['rating'] as double;
  }
}

    // Replace this section in your _loadReviews() function

// For each review, fetch the user profile separately
for (var review in reviews) {
  if (review['user_id'] != null) {
    try {
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', review['user_id'])
          .maybeSingle();
      
      // Debug the profile response
      print("Profile for user ${review['user_id']}: $profileResponse");
      
      if (profileResponse != null && profileResponse['first_name'] != null) {
        review['user_name'] = profileResponse['first_name'];
      } else {
        review['user_name'] = 'Anonymous';
        print("No profile found or first_name is null for user ${review['user_id']}");
      }
    } catch (e) {
      print("Error fetching profile for user ${review['user_id']}: $e");
      review['user_name'] = 'Anonymous';
    }
  } else {
    review['user_name'] = 'Anonymous';
  }
}
    
    setState(() {
      _reviews = reviews;
      _averageRating = reviews.isEmpty ? 0 : totalRating / reviews.length;
      _isLoading = false;
    });
  } catch (error) {
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading reviews: $error')),
    );
  }
}
  void _debugUserProfiles() async {
  try {
    // Check if we can access the profiles table
    final allProfiles = await _supabase
        .from('profiles')
        .select()
        .limit(5);
    print("Sample profiles: $allProfiles");
    
    // Check if we can join reviews with profiles
    final sampleReview = await _supabase
        .from('reviews')
        .select('id, user_id')
        .limit(1)
        .single();
    
    if (sampleReview != null && sampleReview['user_id'] != null) {
      final userId = sampleReview['user_id'];
      print("Sample review user_id: $userId");
      
      final userProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      print("Profile for sample review: $userProfile");
    } else {
      print("No reviews found or user_id is null");
    }
  } catch (e) {
    print("Debug error: $e");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hostel Reviews'),
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hostels.isEmpty
              ? const Center(child: Text('You have no hostels added yet'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hostel selector dropdown
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Hostel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                value: _selectedHostelId,
                                items: _hostels.map((hostel) {
                                  return DropdownMenuItem<String>(
                                    value: hostel['id'].toString(),
                                    child: Text(hostel['name']),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedHostelId = value;
                                  });
                                  _loadReviews();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Rating summary
                      if (_reviews.isNotEmpty) ...[
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 32,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_averageRating.toStringAsFixed(1)} / 5.0',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${_reviews.length} ${_reviews.length == 1 ? 'review' : 'reviews'})',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Reviews list
                      Expanded(
                        child: _reviews.isEmpty
                            ? Center(
                                child: Text(
                                  'No reviews for this hostel yet',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _reviews.length,
                                itemBuilder: (context, index) {
                                  final review = _reviews[index];
                                  final firstName = review['user_name'] ?? 'Anonymous';

                                  final date = DateFormat('MMM d, yyyy').format(
                                    DateTime.parse(review['created_at']),
                                  );
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    elevation: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                firstName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                date,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: List.generate(
                                              5,
                                              (i) => Icon(
                                                i < (review['rating'] as num).floor()
                                                    ? Icons.star
                                                    : i < (review['rating'] as num)
                                                        ? Icons.star_half
                                                        : Icons.star_border,
                                                color: Colors.amber,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            review['comment'] ?? 'No comment provided',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}