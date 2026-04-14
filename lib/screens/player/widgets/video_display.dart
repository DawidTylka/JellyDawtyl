import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import '../player_view_model.dart';

class PlayerVideoDisplay extends StatelessWidget {
  final PlayerViewModel viewModel;
  final String title;
  final VoidCallback onSettingsPressed;

  const PlayerVideoDisplay({
    super.key,
    required this.viewModel,
    required this.title,
    required this.onSettingsPressed,
  });

  // Wydzielony design górnego paska dla przejrzystości
  MaterialVideoControlsThemeData _buildControlsTheme() {
    return MaterialVideoControlsThemeData(
      topButtonBarMargin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      topButtonBar: [
        const BackButton(color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white, size: 28),
          onPressed: () {
            SimplePip().enterPipMode();
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white, size: 28),
          onPressed: onSettingsPressed,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // PipWidget automatycznie wykrywa stan systemu
    return PipWidget(
      // 1. WIDOK W MAŁYM OKIENKU (PiP)
      pipBuilder: (context) {
        return Video(
          controller: viewModel.controller,
          controls: NoVideoControls, // Wyłączamy wszystkie przyciski w PiP!
          fit: BoxFit.contain,
        );
      },
      
      // 2. WIDOK NORMALNY (Pełny ekran)
      builder: (context) {
        return Stack(
          fit: StackFit.expand,
          children: [
            MaterialVideoControlsTheme(
              normal: _buildControlsTheme(),
              fullscreen: _buildControlsTheme(),
              child: Video(
                controller: viewModel.controller,
                controls: MaterialVideoControls,
                fit: BoxFit.contain,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () {
                      final target = viewModel.player.state.position - const Duration(seconds: 10);
                      viewModel.player.seek(target < Duration.zero ? Duration.zero : target);
                    },
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () {
                      final target = viewModel.player.state.position + const Duration(seconds: 10);
                      final total = viewModel.player.state.duration;
                      viewModel.player.seek(target > total ? total : target);
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}