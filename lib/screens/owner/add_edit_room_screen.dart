import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

final supabase = Supabase.instance.client;

class AddEditRoomScreen extends StatefulWidget {
  final Map<String, dynamic>? roomData;
  final int? hostelId;

  const AddEditRoomScreen({
    Key? key,
    this.roomData,
    this.hostelId,
  }) : super(key: key);

  @override
  _AddEditRoomScreenState createState() => _AddEditRoomScreenState();
}

class _AddEditRoomScreenState extends State<AddEditRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingHostels = true;
  bool _isAvailable = true;
  File? _imageFile;
  String? _imageUrl;
  
  int? _selectedHostelId;
  List<Map<String, dynamic>> _hostels = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    
    // Initialize existing room data if editing
    if (widget.roomData != null) {
      _nameController.text = widget.roomData?['name'] ?? '';
      _roomNumberController.text = (widget.roomData?['room_number'] ?? '').toString();
      _priceController.text = (widget.roomData?['price'] ?? '').toString();
      _capacityController.text = (widget.roomData?['capacity'] ?? '1').toString();
      _descriptionController.text = widget.roomData?['description'] ?? '';
      _isAvailable = widget.roomData?['available'] ?? true;
      _imageUrl = widget.roomData?['image_url'];
      
      if (widget.roomData?['hostel_id'] != null) {
        if (widget.roomData!['hostel_id'] is int) {
          _selectedHostelId = widget.roomData!['hostel_id'];
        } else {
          _selectedHostelId = int.tryParse(widget.roomData!['hostel_id'].toString());
        }
      }
    } else if (widget.hostelId != null) {
      _selectedHostelId = widget.hostelId;
    }
    
    _fetchHostels();
  }

  Future<void> _fetchHostels() async {
    setState(() => _isLoadingHostels = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final response = await supabase
          .from('hostels')
          .select()
          .eq('owner_id', userId)
          .order('name', ascending: true);

      setState(() {
        _hostels = List<Map<String, dynamic>>.from(response);
        _isLoadingHostels = false;
        
        if (_selectedHostelId != null) {
          bool hostelExists = false;
          for (var hostel in _hostels) {
            int hostelId = hostel['id'] is int 
                ? hostel['id'] 
                : int.tryParse(hostel['id'].toString()) ?? -1;
                
            if (hostelId == _selectedHostelId) {
              hostelExists = true;
              break;
            }
          }
          
          if (!hostelExists) {
            _selectedHostelId = null;
          }
        }
        
        if (_selectedHostelId == null && _hostels.isNotEmpty) {
          var firstHostel = _hostels.first;
          _selectedHostelId = firstHostel['id'] is int 
              ? firstHostel['id'] 
              : int.tryParse(firstHostel['id'].toString());
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading hostels: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoadingHostels = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomNumberController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
                        final status = await Permission.camera.request();
                        
                        if (status.isGranted) {
                          try {
                            final pickedFile = await _imagePicker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 80,
                            );
                            
                            if (pickedFile != null) {
                              setState(() => _imageFile = File(pickedFile.path));
                            }
                          } catch (e) {
                            _showErrorSnackbar('Camera error: ${e.toString()}');
                          }
                        } else if (status.isPermanentlyDenied) {
                          _showPermissionDialog(
                            'Camera Permission',
                            'Camera permission is required to take pictures. Please enable it in app settings.'
                          );
                        } else {
                          _showErrorSnackbar('Camera permission denied');
                        }
                      },
                      child: _buildImageSourceOption(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                      ),
                    ),
                    
                    // Gallery option - updated with the new permission handling approach
                    GestureDetector(
                      onTap: () async {
                        Navigator.of(context).pop();
                        
                        // Try to access gallery without explicitly checking permission first
                        try {
                          final pickedFile = await _imagePicker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );
                          
                          if (pickedFile != null) {
                            setState(() => _imageFile = File(pickedFile.path));
                          }
                        } catch (e) {
                          // If that fails, then try with explicit permission request
                          final status = await Permission.photos.request();
                          
                          if (status.isGranted) {
                            try {
                              final pickedFile = await _imagePicker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 80,
                              );
                              
                              if (pickedFile != null) {
                                setState(() => _imageFile = File(pickedFile.path));
                              }
                            } catch (e) {
                              _showErrorSnackbar('Gallery error: ${e.toString()}');
                            }
                          } else if (status.isPermanentlyDenied) {
                            _showPermissionDialog(
                              'Gallery Permission',
                              'Photo library access is required to select images. Please enable it in app settings.'
                            );
                          } else {
                            _showErrorSnackbar('Gallery permission denied');
                          }
                        }
                      },
                      child: _buildImageSourceOption(
                        icon: Icons.photo_library,
                        label: 'Gallery',
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

  Widget _buildImageSourceOption({required IconData icon, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: const Color(0xFF4A6FE3),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showPermissionDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(content),
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

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(_imageFile!.path)}';
      final imagePath = 'hostels/$fileName';

      await supabase.storage.from('new').upload(
        imagePath,
        _imageFile!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      return supabase.storage.from('new').getPublicUrl(imagePath);
    } catch (e) {
      _showErrorSnackbar('Error uploading image: ${e.toString()}');
      return null;
    }
  }

  // New method to check if a room with the same name and number already exists
  Future<bool> _checkRoomExists() async {
    try {
      if (_selectedHostelId == null) return false;
      
      final roomName = _nameController.text.trim();
      final roomNumber = int.tryParse(_roomNumberController.text.trim()) ?? 0;
      
      // Create the query - need to handle nullable _selectedHostelId properly
      var query = supabase
          .from('rooms')
          .select('id')
          .eq('hostel_id', _selectedHostelId as int) // Cast to non-nullable int
          .eq('name', roomName)
          .eq('room_number', roomNumber);
      
      // If editing, exclude the current room from the check
      if (widget.roomData != null) {
        query = query.neq('id', widget.roomData!['id']);
      }
      
      final result = await query;
      
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking room existence: $e');
      return false;
    }
  }

  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedHostelId == null) {
      _showErrorSnackbar('Please select a hostel');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if room with same name and number already exists in the selected hostel
      if (_selectedHostelId != null) {  // Make sure hostel is selected before checking
        final roomExists = await _checkRoomExists();
        if (roomExists) {
          _showErrorSnackbar('A room with this name and number already exists in the selected hostel');
          setState(() => _isLoading = false);
          return;
        }
      }
      
      final imageUrl = await _uploadImage();

      final roomData = {
        'hostel_id': _selectedHostelId,
        'name': _nameController.text,
        'room_number': int.tryParse(_roomNumberController.text) ?? 0,
        'price': double.tryParse(_priceController.text) ?? 0,
        'capacity': int.tryParse(_capacityController.text) ?? 1,
        'description': _descriptionController.text,
        'available': _isAvailable,
        if (imageUrl != null) 'image_url': imageUrl,
      };

      if (widget.roomData != null) {
        await supabase
            .from('rooms')
            .update(roomData)
            .eq('id', widget.roomData!['id']);
        
        await _updateHostelRoomCount(_selectedHostelId!);
        
        _showSuccessSnackbar('Room updated successfully');
      } else {
        await supabase.from('rooms').insert(roomData);
        await _updateHostelRoomCount(_selectedHostelId!);
        _showSuccessSnackbar('Room added successfully');
      }

      Navigator.pop(context, true);
    } catch (e) {
      // Handle database constraint violation error specifically
      if (e is PostgrestException && e.toString().contains('duplicate key value violates unique constraint')) {
        _showErrorSnackbar('A room with this name and number already exists in the selected hostel');
      } else {
        _showErrorSnackbar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _updateHostelRoomCount(int hostelId) async {
    try {
      final result = await supabase
          .from('rooms')
          .select()
          .eq('hostel_id', hostelId)
          .eq('available', true);
      
      await supabase
          .from('hostels')
          .update({'available_rooms': result.length})
          .eq('id', hostelId);
    } catch (e) {
      debugPrint('Error updating hostel room count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.roomData != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          isEditing ? "Edit Room" : "Add Room",
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
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room Image Upload
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            image: _imageFile != null
                                ? DecorationImage(
                                    image: FileImage(_imageFile!),
                                    fit: BoxFit.cover,
                                  )
                                : _imageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_imageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: _imageFile == null && _imageUrl == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: Color(0xFF4A6FE3),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Add Room Photo",
                                      style: TextStyle(
                                        color: Color(0xFF4A6FE3),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Hostel Selection Dropdown
                    _isLoadingHostels
                      ? const Center(child: CircularProgressIndicator())
                      : _hostels.isEmpty
                          ? const Center(
                              child: Text(
                                "You don't have any hostels yet. Please add a hostel first.",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: "Select Hostel",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.home),
                              ),
                              value: _selectedHostelId,
                              items: _hostels.map((hostel) {
                                final hostelId = hostel['id'] is int 
                                  ? hostel['id'] 
                                  : int.tryParse(hostel['id'].toString());
                                  
                                return DropdownMenuItem<int>(
                                  value: hostelId,
                                  child: Text(hostel['name'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedHostelId = value);
                              },
                              validator: (value) {
                                if (value == null) return 'Please select a hostel';
                                return null;
                              },
                            ),
                    const SizedBox(height: 16),

                    // Room Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Room Name",
                        hintText: "Enter room name",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.meeting_room),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter room name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Room Number
                    TextFormField(
                      controller: _roomNumberController,
                      decoration: const InputDecoration(
                        labelText: "Room Number",
                        hintText: "Enter room number",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter room number';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Price
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: "Price per Semester (₵)",
                        hintText: "Enter price",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.monetization_on),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Capacity
                    TextFormField(
                      controller: _capacityController,
                      decoration: const InputDecoration(
                        labelText: "Capacity",
                        hintText: "Enter room capacity",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.people),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter capacity';
                        }
                        if (int.tryParse(value) == null || int.parse(value) < 1) {
                          return 'Please enter a valid capacity (minimum 1)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        hintText: "Enter room description",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Availability Switch
                    SwitchListTile(
                      title: const Text("Room Available for Booking"),
                      value: _isAvailable,
                      onChanged: (value) => setState(() => _isAvailable = value),
                      activeColor: const Color(0xFF4A6FE3),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _hostels.isEmpty ? null : _saveRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A6FE3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: Text(
                          isEditing ? "Update Room" : "Add Room",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}