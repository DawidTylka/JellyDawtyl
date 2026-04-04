import 'package:flutter/material.dart';
import 'dart:io';
import '../l10n/app_localizations.dart';
import 'player_screen.dart';
import '../services/download_service.dart';
import '../widgets/ad_banner_widget.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<FileSystemEntity> _items = [];
  Directory? _currentFolder;
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _selectedIndices.clear();
      _isSelectionMode = false;
    });

    try {
      String dirPath = await DownloadService().getDirectoryPath();
      Directory? baseDir;

      if (dirPath.isNotEmpty) {
        baseDir = Directory(dirPath);
        if (!baseDir.existsSync()) {
          baseDir.createSync(recursive: true);
        }
      }

      if (baseDir != null && baseDir.existsSync()) {
        if (_currentFolder == null) {
          _items = baseDir.listSync().whereType<Directory>().toList();
        } else {
          _items = _currentFolder!
              .listSync()
              .where((e) => e is File && e.path.toLowerCase().endsWith('.mp4'))
              .toList();
        }

        _items.sort((a, b) => a.path.compareTo(b.path));
      } else {
        _items = [];
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Błąd ładowania danych: $e");
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIndices.add(index);
        _isSelectionMode = true;
      }
    });
  }

  void _deleteSelected(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text("Usuń ${_selectedIndices.length} elementów"),
        content: const Text(
          "Czy na pewno chcesz trwale usunąć zaznaczone treści?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Anuluj"),
          ),
          TextButton(
            onPressed: () async {
              List<int> sorted = _selectedIndices.toList()
                ..sort((a, b) => b.compareTo(a));

              for (int i in sorted) {
                try {
                  final entity = _items[i];
                  if (entity.existsSync()) {
                    await entity.delete(recursive: true);
                  }
                } catch (e) {
                  debugPrint("Nie udało się usunąć: ${e.toString()}");
                }
              }

              if (mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text(
              "Usuń",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String title = _currentFolder == null
        ? l10n.offlineFiles
        : _currentFolder!.path.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _isSelectionMode
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
            : Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          _isSelectionMode ? "Zaznaczono: ${_selectedIndices.length}" : title,
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedIndices.clear();
                }),
              )
            : (_currentFolder != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() => _currentFolder = null);
                        _loadData();
                      },
                    )
                  : null),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _deleteSelected(l10n),
            )
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : _items.isEmpty
          ? _buildEmptyState(l10n)
          : (_currentFolder == null ? _buildFolderGrid() : _buildFileList()),

      bottomNavigationBar: const AdBannerWidget(),
    );
  }

  Widget _buildThumbnail(File? thumbnailFile, File? coverFile) {
    if (thumbnailFile?.existsSync() ?? false) {
      try {
        final size = thumbnailFile!.lengthSync();
        if (size > 1000) {
          return Container(
            width: 100,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: FileImage(thumbnailFile),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {
                  try {
                    thumbnailFile.deleteSync();
                  } catch (e) {
                    debugPrint("Nie udało się usunąć: $e");
                  }
                },
              ),
            ),
          );
        } else {
          try {
            thumbnailFile.deleteSync();
          } catch (e) {
            debugPrint("Nie udało się usunąć małego thumbnail: $e");
          }
        }
      } catch (e) {
        try {
          if (thumbnailFile!.existsSync()) thumbnailFile.deleteSync();
        } catch (e) {
          debugPrint("Nie udało się usunąć: $e");
        }
      }
    }

    if (coverFile?.existsSync() ?? false) {
      try {
        final size = coverFile!.lengthSync();
        if (size > 1000) {
          return Container(
            width: 100,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: FileImage(coverFile),
                fit: BoxFit.cover,
              ),
            ),
          );
        } else {
          try {
            coverFile.deleteSync();
          } catch (e) {
            debugPrint("Nie udało się usunąć małego cover: $e");
          }
        }
      } catch (e) {
        try {
          if (coverFile!.existsSync()) coverFile.deleteSync();
        } catch (e) {
          debugPrint("Nie udało się usunąć: $e");
        }
      }
    }

    return const SizedBox(
      width: 60,
      height: 40,
      child: Icon(Icons.video_library, color: Colors.white24),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.download_for_offline_outlined,
            size: 80,
            color: Colors.white10,
          ),
          const SizedBox(height: 16),
          const Text(
            "Brak pobranych treści",
            style: TextStyle(color: Colors.white24, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1300
            ? 5
            : width >= 1000
            ? 4
            : width >= 700
            ? 3
            : 2;
        final childAspectRatio = width >= 1000 ? 0.82 : 0.7;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final folder = _items[index] as Directory;
            final folderName = folder.path.split(Platform.pathSeparator).last;
            final coverFile = File('${folder.path}/folder.jpg');
            final isSelected = _selectedIndices.contains(index);

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(index);
                  } else {
                    setState(() => _currentFolder = folder);
                    _loadData();
                  }
                },
                onLongPress: () => _toggleSelection(index),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                              image: coverFile.existsSync()
                                  ? DecorationImage(
                                      image: FileImage(coverFile),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: !coverFile.existsSync()
                                ? const Icon(
                                    Icons.movie_filter,
                                    size: 50,
                                    color: Colors.white10,
                                  )
                                : null,
                          ),
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      folderName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final file = _items[index] as File;
        final fileName = file.path.split(Platform.pathSeparator).last;
        final isSelected = _selectedIndices.contains(index);
        final size = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
        final thumbnailPath =
            '${file.path.substring(0, file.path.length - 4)}.jpg';
        final thumbnailFile = File(thumbnailPath);
        final seriesCoverFile = File(
          '${_currentFolder?.path ?? ''}/folder.jpg',
        );

        return ListTile(
          selected: isSelected,
          selectedTileColor: Colors.white10,
          leading: isSelected
              ? const Icon(Icons.check_circle, color: Colors.greenAccent)
              : _buildThumbnail(
                  thumbnailFile.existsSync() ? thumbnailFile : null,
                  seriesCoverFile.existsSync() ? seriesCoverFile : null,
                ),
          title: Text(
            fileName.replaceAll('.mp4', '').replaceAll('_', ' '),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: Text(
            "$size MB",
            style: const TextStyle(color: Colors.grey),
          ),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(index);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                    url: file.path,
                    title: fileName.replaceAll('.mp4', '').replaceAll('_', ' '),
                    isOffline: true,
                    itemId: '',
                  ),
                ),
              );
            }
          },
          onLongPress: () => _toggleSelection(index),
          trailing: _isSelectionMode
              ? null
              : const Icon(Icons.play_arrow, color: Colors.white54),
        );
      },
    );
  }
}
