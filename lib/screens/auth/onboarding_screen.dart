import 'package:flutter/material.dart';
import 'package:hostel_connect/screens/auth/login_screen.dart';
import 'package:hostel_connect/screens/auth_wrapper.dart'; // Import AuthWrapper
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<OnboardingContent> _contents = [
    OnboardingContent(
      title: "Find Your Perfect Hostel",
      image: "lib/assets/41e75691.jpg",
      description: "Browse through a wide selection of hostels available on campus.",
    ),
    OnboardingContent(
      title: "Book Seamlessly",
      image: "lib/assets/pexels-photo-7368294.jpeg",
      description: "Select your preferred room type and book with just a few taps.",
    ),
    
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: _contents.length,
                itemBuilder: (context, index) {
                  return Column(
  children: [
    Expanded(
      flex: 4,
      child: Container(
        width: double.infinity,
        child: Image.asset(
          _contents[index].image,
          fit: BoxFit.cover,
        ),
      ),
    ),
    const SizedBox(height: 20),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          Text(
            _contents[index].title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324054),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            _contents[index].description,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF324054),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  ],
);

                },
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 30.0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _contents.length,
                      (index) => buildDot(index),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Row(
                      children: [
                        _currentPage != 0
                            ? Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF4A6FE3),
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: Color(0xFF4A6FE3)),
                                    ),
                                  ),
                                  child: const Text("Previous"),
                                ),
                              )
                            : const SizedBox(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_currentPage == _contents.length - 1) {
                                // Mark that the app has been launched before
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('has_launched_before', true);
                                
                                // Navigate to auth wrapper
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AuthWrapper(),
                                  ),
                                );
                              } else {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A6FE3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _currentPage == _contents.length - 1 ? "Get Started" : "Next",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDot(int index) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      height: 10,
      width: _currentPage == index ? 25 : 10,
      decoration: BoxDecoration(
        color: _currentPage == index ? const Color(0xFF4A6FE3) : const Color(0xFFD4D4D4),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class OnboardingContent {
  final String title;
  final String image;
  final String description;

  OnboardingContent({
    required this.title,
    required this.image,
    required this.description,
  });
}