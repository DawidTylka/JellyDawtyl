import 'package:flutter/material.dart';

import '../services/download_service.dart';

typedef QualitySelected =
    void Function(int? maxWidth, int? bitrate, String qualityLabel);

/// Bottom sheet with the download qualities available for [mediaInfo].
Future<void> showQualityPicker(
  BuildContext context, {
  required String title,
  required Map<String, dynamic>? mediaInfo,
  required QualitySelected onSelect,
}) {
  final options = DownloadService.getQualityOptions(mediaInfo);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.grey[900],
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            for (final quality in options)
              ListTile(
                leading: Icon(
                  quality['icon'] as IconData,
                  color: quality['color'] as Color,
                ),
                title: Text(
                  quality['label'] as String,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSelect(
                    quality['width'] as int?,
                    quality['bitrate'] as int?,
                    quality['qualityLabel'] as String,
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}
