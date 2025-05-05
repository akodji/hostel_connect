import 'package:flutter/material.dart';

class OfflineNotificationBanner extends StatelessWidget {
  const OfflineNotificationBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: const Color(0xFFFFF3CD),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off,
            color: Color(0xFFF0AD4E),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "You're offline. Some features may be limited.",
              style: TextStyle(
                color: const Color(0xFF856404),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // This would typically trigger a connectivity check
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Checking connection...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              "Retry",
              style: TextStyle(
                color: Color(0xFF856404),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}