import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PlayerLoadingView extends StatelessWidget {
  const PlayerLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.8, end: 1.2),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: SvgPicture.asset('assets/logo.svg', width: 80, height: 80),
      ),
    );
  }
}

class PlayerErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onClose;

  const PlayerErrorView({super.key, required this.error, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 64),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onClose, child: const Text("Zamknij")),
          ],
        ),
      ),
    );
  }
}