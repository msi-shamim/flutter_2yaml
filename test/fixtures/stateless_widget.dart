import 'package:flutter/material.dart';

class WelcomeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const WelcomeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onTap, child: const Text('Get Started')),
          ],
        ),
      ),
    );
  }
}
