import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/media_segment.dart';
import '../player_view_model.dart';

class PlayerVideoDisplay extends StatelessWidget {
  final PlayerViewModel viewModel;
  final String title;
  final bool backgroundPlaybackEnabled;
  final VoidCallback onSettingsPressed;

  const PlayerVideoDisplay({
    super.key,
    required this.viewModel,
    required this.title,
    required this.backgroundPlaybackEnabled,
    required this.onSettingsPressed,
  });

  // ListenableBuilder odświeża tylko przycisk, gdy lista odcinków się wczyta.
  // Bez poprzedniego/następnego odcinka (np. film) przycisk znika, ale
  // zostawia miejsce, żeby odtwórz/pauza był zawsze na środku.
  Widget _episodeButton({
    required IconData icon,
    required String tooltip,
    required bool Function() isEnabled,
    required Future<void> Function() onPressed,
  }) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final enabled = isEnabled();
        return Visibility(
          visible: enabled,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 40),
            tooltip: tooltip,
            onPressed: enabled ? () => onPressed() : null,
          ),
        );
      },
    );
  }

  static String _skipLabel(AppLocalizations l10n, MediaSegmentType type) =>
      switch (type) {
        MediaSegmentType.intro => l10n.skipIntro,
        MediaSegmentType.outro => l10n.skipCredits,
        MediaSegmentType.recap => l10n.skipRecap,
        MediaSegmentType.preview => l10n.skipPreview,
        MediaSegmentType.commercial => l10n.skipCommercial,
      };

  /// "Skip intro" style button, shown while a segment is playing.
  Widget _buildSkipButton(BuildContext context) {
    final segment = viewModel.activeSegment;
    if (segment == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      right: 24,
      bottom: 110,
      child: SafeArea(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          onPressed: () => viewModel.skipSegment(segment),
          icon: const Icon(Icons.fast_forward_rounded),
          label: Text(_skipLabel(l10n, segment.type)),
        ),
      ),
    );
  }

  // Wydzielony design górnego paska dla przejrzystości
  MaterialVideoControlsThemeData _buildControlsTheme(AppLocalizations l10n) {
    return MaterialVideoControlsThemeData(
      topButtonBarMargin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      seekBarMargin: const EdgeInsets.only(left: 16, right: 16, bottom: 52.0),
      seekBarHeight: 4.0, // grubsza linia
      seekBarContainerHeight: 40.0, // większy obszar dotyku
      seekBarThumbSize: 16.0, // większy uchwyt
      seekBarColor: Colors.white,
      seekBarBufferColor: Colors.greenAccent,
      seekBarPositionColor: Colors.deepPurple,
      seekBarThumbColor: Colors.deepPurple,
      // Poprzedni / odtwórz-pauza / następny na środku ekranu, jak w
      // typowych odtwarzaczach. Wbudowane przyciski media_kit działają tylko
      // dla playlist, więc odcinki obsługują własne.
      primaryButtonBar: [
        const Spacer(flex: 2),
        _episodeButton(
          icon: Icons.skip_previous,
          tooltip: l10n.previousEpisode,
          isEnabled: () => viewModel.hasPreviousEpisode,
          onPressed: viewModel.skipToPrevious,
        ),
        const Spacer(),
        const MaterialPlayOrPauseButton(iconSize: 56.0),
        const Spacer(),
        _episodeButton(
          icon: Icons.skip_next,
          tooltip: l10n.nextEpisode,
          isEnabled: () => viewModel.hasNextEpisode,
          onPressed: viewModel.skipToNext,
        ),
        const Spacer(flex: 2),
      ],
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
          icon: const Icon(
            Icons.picture_in_picture_alt,
            color: Colors.white,
            size: 28,
          ),
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
    final l10n = AppLocalizations.of(context)!;
    return PipWidget(
      // 1. WIDOK W MAŁYM OKIENKU (PiP)
      pipBuilder: (context) {
        return Video(
          controller: viewModel.controller,
          pauseUponEnteringBackgroundMode: !backgroundPlaybackEnabled,
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
                pauseUponEnteringBackgroundMode: !backgroundPlaybackEnabled,
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
                  normal: _buildControlsTheme(l10n),
                  fullscreen: _buildControlsTheme(l10n),
                  child: Video(
                    controller: viewModel.controller,
                    pauseUponEnteringBackgroundMode: !backgroundPlaybackEnabled,
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
                          final target =
                              viewModel.player.state.position -
                              const Duration(seconds: 10);
                          viewModel.player.seek(
                            target < Duration.zero ? Duration.zero : target,
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: () {
                          final target =
                              viewModel.player.state.position +
                              const Duration(seconds: 10);
                          final total = viewModel.player.state.duration;
                          viewModel.player.seek(
                            target > total ? total : target,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                _buildSkipButton(context),
              ],
            );
          },
        );
      },
    );
  }
}
