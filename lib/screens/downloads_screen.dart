import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../l10n/app_localizations.dart';
import 'player/player_screen.dart';
import '../services/download_service.dart';
import '../services/playback_sync_service.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/responsive_grid_layout.dart';
import '../widgets/media_grid_card.dart';
import '../widgets/episode_card.dart';
import '../models/episode.dart';
import '../utils/html_description.dart';

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
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<FileSystemEntity> get _visibleItems {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((entity) {
      if (entity is Directory) {
        return entity.path
            .split(Platform.pathSeparator)
            .last
            .toLowerCase()
            .contains(query);
      }
      if (entity is File) {
        final metadata = _readMetadata(entity);
        final haystack = [
          metadata?['Name'],
          metadata?['Overview'],
          metadata?['SeriesName'],
          entity.uri.pathSegments.last,
        ].whereType<String>().join(' ').toLowerCase();
        return haystack.contains(query);
      }
      return false;
    }).toList();
  }

  Map<String, dynamic>? _readMetadata(File videoFile) {
    final jsonFile = File('${videoFile.path}.json');
    if (!jsonFile.existsSync()) return null;
    try {
      final decoded = jsonDecode(jsonFile.readAsStringSync());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    PlaybackSyncService.instance.downloadedMetadataRevision.addListener(
      _onDownloadedMetadataChanged,
    );
    _loadData();
    unawaited(
      PlaybackSyncService.instance.refreshDownloadedUserData(force: true),
    );
  }

  @override
  void dispose() {
    PlaybackSyncService.instance.downloadedMetadataRevision.removeListener(
      _onDownloadedMetadataChanged,
    );
    _searchController.dispose();
    super.dispose();
  }

  void _onDownloadedMetadataChanged() {
    if (mounted) setState(() {});
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
            onPressed: () {
              List<int> sorted = _selectedIndices.toList()
                ..sort((a, b) => b.compareTo(a));
              final selectedEntities = sorted
                  .where((index) => index >= 0 && index < _visibleItems.length)
                  .map((index) => _visibleItems[index])
                  .toList();
              Navigator.of(context).pop();

              () async {
                for (final entity in selectedEntities) {
                  try {
                    if (entity.existsSync()) {
                      await entity.delete(recursive: true);
                    }
                  } catch (e) {
                    debugPrint("Nie udało się usunąć: ${e.toString()}");
                  }
                }
                if (mounted) {
                  await _loadData();
                }
              }();
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

    return PopScope(
      canPop: !_isSelectionMode && _currentFolder == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedIndices.clear();
          });
        } else if (_currentFolder != null) {
          setState(() => _currentFolder = null);
          _loadData();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _isSelectionMode
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          title: _isSelectionMode
              ? Text("Zaznaczono: ${_selectedIndices.length}")
              : _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Szukaj pobranych...',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                )
              : Text(title),
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
            else ...[
              if (_isSearching)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                )
              else
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Szukaj pobranych',
                  onPressed: () => setState(() => _isSearching = true),
                ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              )
            : _visibleItems.isEmpty
            ? _buildEmptyState(l10n)
            : (_currentFolder == null ? _buildFolderGrid() : _buildFileList()),

        bottomNavigationBar: const AdBannerWidget(),
      ),
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
    return ResponsiveGridLayout(
      itemCount: _visibleItems.length,
      itemBuilder: (context, index) {
        final folder = _visibleItems[index] as Directory;
        final folderName = folder.path.split(Platform.pathSeparator).last;
        final coverFile = File('${folder.path}/folder.jpg');
        final isSelected = _selectedIndices.contains(index);

        return MediaGridCard(
          title: folderName,
          // Używamy FileImage do ładowania z pamięci telefonu
          imageProvider: coverFile.existsSync() ? FileImage(coverFile) : null,
          fallbackIcon: Icons.folder_copy_outlined, // Ikona gdy nie ma okładki
          isSelected: isSelected,
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(index);
            } else {
              setState(() => _currentFolder = folder);
              _loadData();
            }
          },
          onLongPress: () => _toggleSelection(index),
        );
      },
    );
  }

  Widget _buildFileList() {
    final files = _visibleItems.whereType<File>().toList();
    final episodes = files
        .where((file) => _readMetadata(file)?['Type'] == 'Episode')
        .toList();
    final otherFiles = files.where((file) => !episodes.contains(file)).toList();
    final seasons = <int, List<File>>{};
    for (final file in episodes) {
      final metadata = _readMetadata(file);
      final season =
          (metadata?['ParentIndexNumber'] as num?)?.toInt() ??
          _seasonNumber(file);
      seasons.putIfAbsent(season, () => []).add(file);
    }
    for (final seasonFiles in seasons.values) {
      seasonFiles.sort(
        (a, b) => _episodeNumber(a).compareTo(_episodeNumber(b)),
      );
    }

    return ListView(
      children: [
        ...seasons.entries.map((entry) {
          final seasonFiles = entry.value;
          final watched = seasonFiles.where(_isPlayed).length;
          return ExpansionTile(
            key: PageStorageKey('offline-season-${entry.key}'),
            initiallyExpanded: true,
            collapsedBackgroundColor: Colors.white12,
            backgroundColor: Colors.white10,
            leading: const Icon(Icons.video_collection, color: Colors.white),
            title: Row(
              children: [
                Text(
                  'SEZON ${entry.key}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 10),
                _seasonBadge(watched, seasonFiles.length),
              ],
            ),
            children: seasonFiles.map((file) {
              final index = _visibleItems.indexOf(file);
              final metadata = _readMetadata(file) ?? <String, dynamic>{};
              final episode = Episode.fromJson({
                ...metadata,
                'Id': metadata['Id'] ?? '',
                'Name': metadata['Name'] ?? _displayName(file),
                'IndexNumber': metadata['IndexNumber'] ?? _episodeNumber(file),
                'ParentIndexNumber': metadata['ParentIndexNumber'] ?? entry.key,
              });
              final poster = File(
                '${file.path.substring(0, file.path.length - 4)}.jpg',
              );
              final selected = _selectedIndices.contains(index);
              return GestureDetector(
                onLongPress: () => _toggleSelection(index),
                onTap: () => _isSelectionMode
                    ? _toggleSelection(index)
                    : _playDownloaded(file, metadata),
                child: Stack(
                  children: [
                    EpisodeCard(
                      episode: episode,
                      baseUrl: '',
                      token: '',
                      userId: '',
                      isOffline: true,
                      offlineImage: poster,
                      onDownload: () => _isSelectionMode
                          ? _toggleSelection(index)
                          : _playDownloaded(file, metadata),
                    ),
                    if (selected)
                      const Positioned(
                        right: 24,
                        top: 16,
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          );
        }),
        ...otherFiles.map(_buildDownloadedMovie),
      ],
    );
  }

  Widget _seasonBadge(int watched, int total) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.deepPurpleAccent.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$watched/$total',
      style: const TextStyle(color: Colors.white70, fontSize: 12),
    ),
  );

  Widget _buildDownloadedMovie(File file) {
    final index = _visibleItems.indexOf(file);
    final metadata = _readMetadata(file) ?? <String, dynamic>{};
    final poster = File('${file.path.substring(0, file.path.length - 4)}.jpg');
    final selected = _selectedIndices.contains(index);
    return ListTile(
      selected: selected,
      leading: selected
          ? const Icon(Icons.check_circle, color: Colors.greenAccent)
          : _buildThumbnail(poster, File('${file.parent.path}/folder.jpg')),
      title: Text(metadata['Name'] as String? ?? _displayName(file)),
      subtitle: Text(
        cleanHtmlDescription(metadata['Overview'] as String?),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _isSelectionMode
          ? _toggleSelection(index)
          : _playDownloaded(file, metadata),
      onLongPress: () => _toggleSelection(index),
    );
  }

  Future<void> _playDownloaded(File file, Map<String, dynamic> metadata) async {
    if (_isSelectionMode) {
      final index = _visibleItems.indexOf(file);
      if (index >= 0) _toggleSelection(index);
      return;
    }
    final userData = metadata['UserData'] as Map<String, dynamic>?;
    final positionMs =
        ((userData?['PlaybackPositionTicks'] as num?)?.toInt() ?? 0) ~/ 10000;
    final durationMs =
        ((metadata['RunTimeTicks'] as num?)?.toInt() ?? 0) ~/ 10000;
    final isPlayed =
        userData?['Played'] == true ||
        (durationMs > 0 && positionMs / durationMs >= 0.95);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          url: file.path,
          title: metadata['Name'] as String? ?? _displayName(file),
          isOffline: true,
          itemId: metadata['Id'] as String? ?? '',
          startPositionMs: positionMs > 0 && !isPlayed ? positionMs : null,
        ),
      ),
    );
    await _loadData();
  }

  bool _isPlayed(File file) {
    final metadata = _readMetadata(file);
    final userData = metadata?['UserData'] as Map<String, dynamic>?;
    if (userData?['Played'] == true) return true;
    final durationMs =
        ((metadata?['RunTimeTicks'] as num?)?.toInt() ?? 0) ~/ 10000;
    final positionMs =
        ((userData?['PlaybackPositionTicks'] as num?)?.toInt() ?? 0) ~/ 10000;
    return durationMs > 0 && positionMs / durationMs >= 0.95;
  }

  int _seasonNumber(File file) =>
      int.tryParse(RegExp(r'_S(\d+)E').firstMatch(file.path)?.group(1) ?? '') ??
      1;

  int _episodeNumber(File file) =>
      int.tryParse(
        RegExp(r'_S\d+E(\d+)').firstMatch(file.path)?.group(1) ?? '',
      ) ??
      0;

  String _displayName(File file) => file.uri.pathSegments.last
      .replaceAll(RegExp(r'\.mp4$', caseSensitive: false), '')
      .replaceAll('_', ' ');
}
