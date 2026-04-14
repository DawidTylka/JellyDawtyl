import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../../l10n/app_localizations.dart'; // Upewnij się, że ścieżka się zgadza
import '../player_view_model.dart'; // Upewnij się, że ścieżka się zgadza
import 'dart:io';

class PlayerSettingsSheet extends StatelessWidget {
  final PlayerViewModel viewModel;

  const PlayerSettingsSheet({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.settings,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const Divider(color: Colors.white24),

        // --- JAKOŚĆ WIDEO ---
        ExpansionTile(
          leading: const Icon(Icons.high_quality, color: Colors.white70),
          title: Text(l10n.videoQuality, style: const TextStyle(color: Colors.white)),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          children: viewModel.isOffline
              ? _buildOfflineQualityOptions(context)
              : _buildOnlineQualityOptions(context),
        ),

        // --- ŚCIEŻKI AUDIO ---
        ExpansionTile(
          leading: const Icon(Icons.audiotrack, color: Colors.white70),
          title: Text(l10n.audioTrack, style: const TextStyle(color: Colors.white)),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          children: _buildAudioOptions(context, l10n),
        ),

        // --- NAPISY ---
        ExpansionTile(
          leading: const Icon(Icons.subtitles, color: Colors.white70),
          title: Text(l10n.subtitles, style: const TextStyle(color: Colors.white)),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          children: _buildSubtitleOptions(context, l10n),
        ),
      ],
    );
  }

  // ==========================================
  // WIDŻETY JAKOŚCI
  // ==========================================
  List<Widget> _buildOnlineQualityOptions(BuildContext context) {
    final options = [
      {'label': 'Oryginał (Direct Play)', 'width': null, 'bitrate': null},
      {'label': '1080p (10 Mbps)', 'width': 1920, 'bitrate': 10000000},
      {'label': '720p (4 Mbps)', 'width': 1280, 'bitrate': 4000000},
      {'label': '480p (1.5 Mbps)', 'width': 854, 'bitrate': 1500000},
      {'label': '360p (720 kbps)', 'width': 640, 'bitrate': 720000},
    ];

    return options.map((q) {
      final w = q['width'] as int?;
      final b = q['bitrate'] as int?;
      final isSelected = viewModel.selectedWidth == w;

      return ListTile(
        title: Text(
          q['label'] as String,
          style: TextStyle(color: isSelected ? Colors.deepPurpleAccent : Colors.white70),
        ),
        trailing: isSelected ? const Icon(Icons.check, color: Colors.deepPurpleAccent) : null,
        onTap: () {
          viewModel.changeOnlineQuality(w, b);
          Navigator.pop(context);
        },
      );
    }).toList();
  }

  List<Widget> _buildOfflineQualityOptions(BuildContext context) {
    return viewModel.player.state.tracks.video.map((t) {
      final isSelected = viewModel.player.state.track.video == t;
      String label = t.id == 'auto' ? 'Automatyczna' : t.id == 'no' ? 'Wyłącz wideo' : '${t.w ?? '?'}x${t.h ?? '?'}';
      
      return ListTile(
        title: Text(label, style: TextStyle(color: isSelected ? Colors.deepPurpleAccent : Colors.white70)),
        trailing: isSelected ? const Icon(Icons.check, color: Colors.deepPurpleAccent) : null,
        onTap: () {
          viewModel.player.setVideoTrack(t);
          Navigator.pop(context);
        },
      );
    }).toList();
  }

  // ==========================================
  // WIDŻETY AUDIO
  // ==========================================
  List<Widget> _buildAudioOptions(BuildContext context, AppLocalizations l10n) {
    if (viewModel.isOffline) {
      return viewModel.player.state.tracks.audio.map((t) {
        final isSelected = viewModel.player.state.track.audio == t;
        String label = t.id == 'auto' ? 'Automatyczna' : t.id == 'no' ? l10n.off : (t.title ?? t.language ?? 'Audio ${t.id}');
        
        return ListTile(
          title: Text(label, style: TextStyle(color: isSelected ? Colors.deepPurpleAccent : Colors.white70)),
          trailing: isSelected ? const Icon(Icons.check, color: Colors.deepPurpleAccent) : null,
          onTap: () {
            viewModel.setAudioTrack(t, isJellyfinIndex: false);
            Navigator.pop(context);
          },
        );
      }).toList();
    } else {
      return viewModel.jellyfinAudioStreams.map((audio) {
        final idx = audio['Index'];
        final isSelected = viewModel.selectedAudioIndex == idx;
        final label = audio['DisplayTitle'] ?? audio['Language'] ?? 'Audio $idx';

        return ListTile(
          title: Text(label, style: TextStyle(color: isSelected ? Colors.deepPurpleAccent : Colors.white70)),
          trailing: isSelected ? const Icon(Icons.check, color: Colors.deepPurpleAccent) : null,
          onTap: () {
            viewModel.setAudioTrack(idx, isJellyfinIndex: true);
            Navigator.pop(context);
          },
        );
      }).toList();
    }
  }

  // ==========================================
  // WIDŻETY NAPISÓW
  // ==========================================
  List<Widget> _buildSubtitleOptions(BuildContext context, AppLocalizations l10n) {
    List<Widget> options = [];

    if (viewModel.isOffline) {
      // Wyłączone
      final isOffSelected = viewModel.currentExternalSubtitlePath == null && viewModel.player.state.track.subtitle.id == 'no';
      options.add(_buildSubTile(context, l10n.off, isOffSelected, () => viewModel.setSubtitleTrack(SubtitleTrack.no())));

      // Wbudowane
      for (var t in viewModel.player.state.tracks.subtitle.where((t) => t.id != 'no' && t.id != 'auto')) {
        final isSelected = viewModel.currentExternalSubtitlePath == null && viewModel.player.state.track.subtitle == t;
        options.add(_buildSubTile(context, t.title ?? t.language ?? 'Wbudowane ${t.id}', isSelected, () => viewModel.setSubtitleTrack(t)));
      }

      // Zewnętrzne (Lokalne SRT)
      for (var file in viewModel.localSubtitleFiles) {
        // Przywrócona logika wyciągania języka z nazwy pliku!
        final fileName = file.path.split(Platform.pathSeparator).last;
        final parts = fileName.split('.');
        final label = parts.length >= 3
            ? "Napisy (${parts[parts.length - 2].toUpperCase()})"
            : "Napisy Zewnętrzne";

        final isSelected = viewModel.currentExternalSubtitlePath == file.path;
        options.add(_buildSubTile(context, label, isSelected, () => viewModel.setSubtitleTrack(null, externalPath: file.path)));
      }
    } else {
      // Wyłączone Online
      options.add(_buildSubTile(context, l10n.off, viewModel.selectedSubtitleIndex == null, () => viewModel.setSubtitleTrack(null, isJellyfinIndex: true)));

      // Online z Jellyfin API
      for (var sub in viewModel.jellyfinSubtitleStreams) {
        final idx = sub['Index'];
        final isSelected = viewModel.selectedSubtitleIndex == idx;
        final label = sub['DisplayTitle'] ?? sub['Language'] ?? 'Napisy $idx';
        options.add(_buildSubTile(context, label, isSelected, () => viewModel.setSubtitleTrack(idx, isJellyfinIndex: true)));
      }
    }
    return options;
  }

  Widget _buildSubTile(BuildContext context, String label, bool isSelected, VoidCallback action) {
    return ListTile(
      title: Text(label, style: TextStyle(color: isSelected ? Colors.deepPurpleAccent : Colors.white70)),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.deepPurpleAccent) : null,
      onTap: () {
        action();
        Navigator.pop(context);
      },
    );
  }
}