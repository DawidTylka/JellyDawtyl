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
      seekBarMargin: const EdgeInsets.only(left: 16, right: 16, bottom: 52.0),
      seekBarHeight: 4.0,          // grubsza linia
      seekBarContainerHeight: 40.0, // większy obszar dotyku
      seekBarThumbSize: 16.0,      // większy uchwyt
      seekBarColor: Colors.white,
      seekBarBufferColor: Colors.greenAccent,
      seekBarPositionColor: Colors.deepPurple,
      seekBarThumbColor: Colors.deepPurple,
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
        // ListenableBuilder odświeża tylko przyciski, reszta paska pozostaje nietknięta
        ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.skip_previous,
                    color: viewModel.hasPreviousEpisode ? Colors.white : Colors.white38,
                    size: 28,
                  ),
                  tooltip: 'Poprzedni odcinek',
                  onPressed: viewModel.hasPreviousEpisode ? () => viewModel.skipToPrevious() : null,
                ),
                IconButton(
                  icon: Icon(
                    Icons.skip_next,
                    color: viewModel.hasNextEpisode ? Colors.white : Colors.white38,
                    size: 28,
                  ),
                  tooltip: 'Następny odcinek',
                  onPressed: viewModel.hasNextEpisode ? () => viewModel.skipToNext() : null,
                ),
              ],
            );
          },
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
  @override
  Widget build(BuildContext context) {
    return PipWidget(
      // 1. WIDOK W MAŁYM OKIENKU (PiP)
      pipBuilder: (context) {
        return Video(
          controller: viewModel.controller,
          controls: NoVideoControls,
          fit: BoxFit.contain,
          subtitleViewConfiguration: const SubtitleViewConfiguration(
            visible: false, 
            padding: EdgeInsets.zero,
          ),
        );
      },
      
      // 2. WIDOK NORMALNY (Pełny ekran)
      builder: (context) {
        // LayoutBuilder pozwala nam reagować na drastyczne zmiany rozmiaru okna w czasie rzeczywistym
        return LayoutBuilder(
          builder: (context, constraints) {
            
            // MAGICZNY WARUNEK: Jeśli wysokość okna spada poniżej 250px 
            // (np. podczas animacji minimalizowania do PiP), natychmiast wywalamy 
            // cały interfejs z przyciskami. Dzięki temu Flutter nie ma na czym 
            // wywalić błędu "bottom overflowed".
            if (constraints.maxHeight < 250 || constraints.maxWidth < 250) {
              return Video(
                controller: viewModel.controller,
                controls: NoVideoControls,
                fit: BoxFit.contain,
                subtitleViewConfiguration: const SubtitleViewConfiguration(
                  visible: false, 
                  padding: EdgeInsets.zero,
                ),
              );
            }

            // Normalny widok z kontrolkami (gdy ekran jest odpowiednio duży)
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
                    subtitleViewConfiguration: const SubtitleViewConfiguration(
                      style: TextStyle(
                        fontSize: 50.0,
                        color: Colors.white,
                        backgroundColor: Colors.black54,
                      ),
                    ),
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
      },
    );
  }
}