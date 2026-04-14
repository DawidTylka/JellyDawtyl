import 'package:flutter/material.dart';

class MediaGridCard extends StatelessWidget {
  final String title;
  final ImageProvider? imageProvider;
  final IconData fallbackIcon;
  final IconData? badgeIcon;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MediaGridCard({
    super.key,
    required this.title,
    this.imageProvider,
    this.fallbackIcon = Icons.movie,
    this.badgeIcon,
    this.isSelected = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageProvider != null)
                Image(
                  image: imageProvider!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildFallback(),
                )
              else
                _buildFallback(),

              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              if (badgeIcon != null)
                Positioned(
                  top: 4, right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(badgeIcon, color: Colors.white70, size: 14),
                  ),
                ),

              if (isSelected)
                Container(
                  color: Colors.deepPurple.withValues(alpha: 0.6),
                  child: const Center(
                    child: Icon(Icons.check_circle, color: Colors.white, size: 40),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Icon(fallbackIcon, color: Colors.white24, size: 40),
      ),
    );
  }
}