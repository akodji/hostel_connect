import 'package:flutter/material.dart';
import '../screens/student/hostel_detail_screen.dart';

class HostelCard extends StatelessWidget {
  final String id;
  final String name;
  final String image;
  final double rating;
  final String location;
  final int price;
  final bool available;
  final List<String>? amenities; // Optional for flexibility

  const HostelCard({
    Key? key,
    required this.id,
    required this.name,
    required this.image,
    required this.rating,
    required this.location,
    required this.price,
    required this.available,
    this.amenities,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HostelDetailScreen(hostelId: int.parse(id)),
          ),
        );
      },
      child: Container(
        width: 200, // Fixed width for horizontal list in HomeScreen
        margin: const EdgeInsets.only(right: 16), // Spacing between cards in horizontal list
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hostel Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                image,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: const Color(0xFFF1F3F6),
                    child: Icon(
                      Icons.hotel,
                      size: 40,
                      color: const Color(0xFF324054).withOpacity(0.5),
                    ),
                  );
                },
              ),
            ),

            // Hostel Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324054),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFFFFA726),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF324054),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFF6C63FF),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF324054).withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Amenities (if provided)
                  if (amenities != null && amenities!.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: amenities!.take(2).map((amenity) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F3F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            amenity,
                            style: TextStyle(
                              fontSize: 10,
                              color: const Color(0xFF324054).withOpacity(0.7),
                            ),
                          ),
                        );
                      }).toList()
                        ..addIf(
                          amenities!.length > 2,
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F3F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${amenities!.length - 2}',
                              style: TextStyle(
                                fontSize: 10,
                                color: const Color(0xFF324054).withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Price and Availability
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₵$price',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A6FE3),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: available
                              ? const Color(0xFF2DCE89).withOpacity(0.1)
                              : const Color(0xFFF75676).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          available ? 'Available' : 'Full',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: available ? const Color(0xFF2DCE89) : const Color(0xFFF75676),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to simplify adding elements conditionally to a list
extension ListExtension<T> on List<T> {
  void addIf(bool condition, T element) {
    if (condition) {
      add(element);
    }
  }
}
