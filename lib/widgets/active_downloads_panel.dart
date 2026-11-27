import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/download_service.dart';

/// Downloads in progress, so a queued season can be followed in one place.
class ActiveDownloadsPanel extends StatelessWidget {
  const ActiveDownloadsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final service = DownloadService();
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<Map<String, DownloadStatus>>(
      valueListenable: service.activeDownloads,
      builder: (context, downloads, _) {
        final active = downloads.entries
            .where((e) => !e.value.isDownloaded)
            .toList();
        if (active.isEmpty) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          color: Colors.white.withValues(alpha: 0.06),
          child: ExpansionTile(
            initiallyExpanded: active.length <= 3,
            leading: const Icon(Icons.downloading, color: Colors.greenAccent),
            title: Text(l10n.downloadsInProgress(active.length)),
            children: [
              for (final entry in active)
                ListTile(
                  dense: true,
                  title: Text(
                    service.downloadTitles[entry.key] ?? entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.value.progressText),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value:
                            entry.value.isQueued ||
                                entry.value.progressValue < 0
                            ? null
                            : entry.value.progressValue,
                        color: Colors.greenAccent,
                        backgroundColor: Colors.white10,
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.cancelDownload,
                    onPressed: () => service.cancelDownload(entry.key),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
