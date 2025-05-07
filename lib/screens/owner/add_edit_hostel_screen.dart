import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final supabase = Supabase.instance.client;

class AddEditHostelScreen extends StatefulWidget {
  final Map<String, dynamic>? hostelData;

  const AddEditHostelScreen({
    Key? key,
    this.hostelData,
  }) : super(key: key);

  @override
  _AddEditHostelScreenState createState() => _AddEditHostelScreenState();
}

class _AddEditHostelScreenState extends State<AddEditHostelScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  File? _selectedImage;
  final _imagePicker = ImagePicker();

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _availableRoomsController = TextEditingController(text: '1');
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  String _campusLocation = 'Off Campus';
  List<String> _rules = ['No smoking inside the building', 'Quiet hours: 10 PM - 7 AM'];
  final _newRuleController = TextEditingController();
  
  Map<String, bool> _amenities = {
    'WiFi': false,
    'Study Room': false,
    'Kitchen': false,
    'Laundry': false,
    'Security': false,
    'Parking': false,
    'Water Supply': false,
    'Electricity': false,
  };

  @override
  void initState() {
    super.initState();
    _loadHostelData();
  }
  
  Future<void> _loadHostelData() async {
    if (widget.hostelData != null) {
      _nameController.text = widget.hostelData!['name'] ?? '';
      _descriptionController.text = widget.hostelData!['description'] ?? '';
      _addressController.text = widget.hostelData!['address'] ?? '';
      _locationController.text = widget.hostelData!['location'] ?? '';
      _campusLocation = widget.hostelData!['campus_location'] ?? 'Off Campus';
      _priceController.text = (widget.hostelData!['price'] ?? '').toString();
      _availableRoomsController.text = (widget.hostelData!['available_rooms'] ?? 1).toString();
      _phoneController.text = widget.hostelData!['phone'] ?? '';
      _emailController.text = widget.hostelData!['email'] ?? '';
    
      try {
        final hostelId = widget.hostelData!['id'];
        final amenitiesResponse = await supabase
            .from('hostel_amenities')
            .select('amenity')
            .eq('hostel_id', hostelId);
        
        if (amenitiesResponse != null && amenitiesResponse is List) {
          for (var item in amenitiesResponse) {
            final amenity = item['amenity'];
            if (_amenities.containsKey(amenity)) {
              setState(() {
                _amenities[amenity] = true;
              });
            }
          }
        }
        
        final rulesResponse = await supabase
            .from('hostel_rules')
            .select('rule')
            .eq('hostel_id', hostelId);
            
        if (rulesResponse != null && rulesResponse is List) {
          setState(() {
            _rules = rulesResponse.map<String>((item) => item['rule'].toString()).toList();
            if (_rules.isEmpty) {
              _rules = ['No smoking inside the building', 'Quiet hours: 10 PM - 7 AM'];
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading hostel data: $e');
      }
    }
  }

  void _addRule() {
    final newRule = _newRuleController.text.trim();
    if (newRule.isNotEmpty) {
      setState(() {
        _rules.add(newRule);
        _newRuleController.clear();
      });
    }
  }

  void _removeRule(int index) {
    setState(() {
      _rules.removeAt(index);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _availableRoomsController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _newRuleController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  Future<void> _pickImage() async {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324054),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Camera option
                  GestureDetector(
                    onTap: () async {
                      Navigator.of(context).pop();
                      
                      // Try to access camera directly first
                      try {
                        final pickedFile = await _imagePicker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                        );
                        
                        if (pickedFile != null && mounted) {
                          setState(() {
                            _selectedImage = File(pickedFile.path);
                          });
                        }
                      } catch (e) {
                        // If that fails, try with explicit permission request
                        if (mounted) {
                          final status = await Permission.camera.request();
                          
                          if (status.isGranted) {
                            try {
                              final pickedFile = await _imagePicker.pickImage(
                                source: ImageSource.camera,
                                imageQuality: 80,
                              );
                              
                              if (pickedFile != null && mounted) {
                                setState(() {
                                  _selectedImage = File(pickedFile.path);
                                });
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Camera error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } else if (status.isPermanentlyDenied) {
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) => AlertDialog(
                                  title: const Text('Camera Permission'),
                                  content: const Text(
                                    'Camera permission is required to take pictures. Please enable it in app settings.',
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                    TextButton(
                                      child: const Text('Open Settings'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        openAppSettings();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Camera permission denied'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFF4A6FE3),
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Camera',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Gallery option
                  GestureDetector(
                    onTap: () async {
                      Navigator.of(context).pop();
                      
                      // Try to access gallery directly first
                      try {
                        final pickedFile = await _imagePicker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        
                        if (pickedFile != null && mounted) {
                          setState(() {
                            _selectedImage = File(pickedFile.path);
                          });
                        }
                      } catch (e) {
                        // If that fails, try with explicit permission request
                        if (mounted) {
                          PermissionStatus status;
                          try {
                            status = await Permission.photos.request();
                          } catch (e) {
                            status = await Permission.storage.request();
                          }
                          
                          if (status.isGranted) {
                            try {
                              final pickedFile = await _imagePicker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 80,
                              );
                              
                              if (pickedFile != null && mounted) {
                                setState(() {
                                  _selectedImage = File(pickedFile.path);
                                });
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gallery error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } else if (status.isPermanentlyDenied && mounted) {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                title: const Text('Gallery Permission'),
                                content: const Text(
                                  'Photo access permission is required to select images. Please enable it in app settings.',
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text('Cancel'),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                  TextButton(
                                    child: const Text('Open Settings'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      openAppSettings();
                                    },
                                  ),
                                ],
                              ),
                            );
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gallery permission denied'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFF4A6FE3),
                          child: Icon(
                            Icons.photo_library,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Gallery',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Future<void> _saveHostel() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      String? imageUrl;
      if (_selectedImage != null) {
        final fileName = 'hostels/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('images').upload(fileName, _selectedImage!);
        imageUrl = supabase.storage.from('images').getPublicUrl(fileName);
      }

      final hostelData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
        'location': _locationController.text.trim(),
        'campus_location': _campusLocation,
        'price': int.tryParse(_priceController.text) ?? 0,
        'available_rooms': int.tryParse(_availableRoomsController.text) ?? 1,
        'owner_id': userId,
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
        if (imageUrl != null) 'image_url': imageUrl,
      };

      late int hostelId;
      
      if (widget.hostelData != null) {
        final response = await supabase
            .from('hostels')
            .update(hostelData)
            .eq('id', widget.hostelData!['id'])
            .eq('owner_id', userId)
            .select('id');
            
        if (response == null || response.isEmpty) {
          throw Exception('Failed to update hostel or you do not have permission');
        }
        hostelId = response[0]['id'];
      } else {
        final response = await supabase
            .from('hostels')
            .insert(hostelData)
            .select('id');
            
        if (response == null || response.isEmpty) {
          throw Exception('Failed to create hostel');
        }
        hostelId = response[0]['id'];
      }
      
      // Handle amenities
      if (widget.hostelData != null) {
        await supabase
            .from('hostel_amenities')
            .delete()
            .eq('hostel_id', hostelId);
      }
      
      final amenitiesData = [];
      _amenities.forEach((amenity, selected) {
        if (selected) {
          amenitiesData.add({
            'hostel_id': hostelId,
            'amenity': amenity,
          });
        }
      });
      
      if (amenitiesData.isNotEmpty) {
        await supabase.from('hostel_amenities').insert(amenitiesData);
      }
      
      // Handle rules
      if (widget.hostelData != null) {
        await supabase
            .from('hostel_rules')
            .delete()
            .eq('hostel_id', hostelId);
      }
      
      final rulesData = [];
      for (var rule in _rules) {
        if (rule.trim().isNotEmpty) {
          rulesData.add({
            'hostel_id': hostelId,
            'rule': rule.trim(),
          });
        }
      }
      
      if (rulesData.isNotEmpty) {
        await supabase.from('hostel_rules').insert(rulesData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hostel saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving hostel: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          widget.hostelData != null ? 'Edit Hostel' : 'Add New Hostel',
          style: const TextStyle(
            color: Color(0xFF324054),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF324054)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hostel Image
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(16),
                            image: _selectedImage != null
                                ? DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : widget.hostelData != null && widget.hostelData!['image_url'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(widget.hostelData!['image_url']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: _selectedImage == null &&
                                  (widget.hostelData == null || widget.hostelData!['image_url'] == null)
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Add Hostel Photo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Hostel Name
                      const Text(
                        'Hostel Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Enter hostel name',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter hostel name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Contact Information
                      const SizedBox(height: 24),
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Phone Number
                      const Text(
                        'Phone Number',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'e.g. +233 12 345 6789',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFF4A6FE3)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Email
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'e.g. owner@example.com',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          prefixIcon: const Icon(Icons.email, color: Color(0xFF4A6FE3)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an email address';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      
                      // Location
                      const SizedBox(height: 16),
                      const Text(
                        'Location Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          hintText: 'e.g. North Campus, University Road',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter location description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Address
                      const Text(
                        'Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          hintText: 'Enter full address',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter hostel address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Campus Location
                      const Text(
                        'Campus Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _campusLocation,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'On Campus', child: Text('On Campus')),
                            DropdownMenuItem(value: 'Off Campus', child: Text('Off Campus')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _campusLocation = value;
                              });
                            }
                          },
                        ),
                      ),

                      // Price
                      const SizedBox(height: 16),
                      const Text(
                        'Starting Price',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter starting price',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          prefixText: '₵ ',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter starting price';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      
                      // Available Rooms
                      const SizedBox(height: 16),
                      const Text(
                        'Available Rooms',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _availableRoomsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter number of available rooms',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter available rooms';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),

                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter hostel description',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter hostel description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Hostel Rules
                      const Text(
                        'Hostel Rules',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _rules.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 18,
                                        color: Color(0xFF4A6FE3),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _rules[index],
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () => _removeRule(index),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _newRuleController,
                                    decoration: InputDecoration(
                                      hintText: 'Add a new rule',
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _addRule,
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Color(0xFF4A6FE3),
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Amenities
                      const Text(
                        'Amenities',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF324054),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _amenities.keys.map((amenity) {
                            return FilterChip(
                              label: Text(amenity),
                              selected: _amenities[amenity]!,
                              onSelected: (selected) {
                                setState(() {
                                  _amenities[amenity] = selected;
                                });
                              },
                              selectedColor: const Color(0xFF4A6FE3).withOpacity(0.2),
                              checkmarkColor: const Color(0xFF4A6FE3),
                              backgroundColor: Colors.grey[100],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveHostel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A6FE3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            widget.hostelData != null ? 'Update Hostel' : 'Add Hostel',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}