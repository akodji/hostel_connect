import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  // Singleton instance
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  // Stream controller for connectivity status
  final _connectivityStreamController = StreamController<bool>.broadcast();
  
  // Public stream that other widgets can listen to
  Stream<bool> get connectivityStream => _connectivityStreamController.stream;
  
  // Current connectivity status
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  // Connectivity instance
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;

  // Initialize the service
  Future<void> initialize() async {
    // Get initial connectivity status
    await _updateConnectionStatus();
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) async {
      await _handleConnectivityChange(result);
    });
  }

  // Update connection status based on connectivity result
  Future<void> _updateConnectionStatus() async {
    try {
      final result = await _connectivity.checkConnectivity();
      await _handleConnectivityChange(result);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get connectivity status: $e');
      }
      _isConnected = false;
      _connectivityStreamController.add(_isConnected);
    }
  }

  // Handle connectivity change
  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    // Check for actual internet connectivity, not just wifi/mobile connection
    if (result == ConnectivityResult.none) {
      _isConnected = false;
    } else {
      // Additional check can be added here to verify actual internet connectivity
      // For example, by pinging a known server
      _isConnected = true;
    }
    
    // Broadcast the change
    _connectivityStreamController.add(_isConnected);
  }

  // Manual check for connectivity
  Future<bool> checkConnectivity() async {
    await _updateConnectionStatus();
    return _isConnected;
  }

  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityStreamController.close();
  }
}