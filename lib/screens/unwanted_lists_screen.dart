import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/movie.dart';
import '../services/unwanted_api.dart';
import '../utils/jellyfin_auth.dart';
import '../widgets/message_view.dart';
import '../widgets/unwanted_actions.dart';
import 'item_navigation.dart';

/// "Moje listy" of jellyfin-plugin-unwanted: Na później, Uśpione and
/// Nieulubione, with the action that takes an item back off each list.
class UnwantedListsScreen extends StatefulWidget {
  final String baseUrl;
  final String token;
  final String userId;

  const UnwantedListsScreen({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.userId,
  });

  @override
  State<UnwantedListsScreen> createState() => _UnwantedListsScreenState();
}

class _UnwantedListsScreenState extends State<UnwantedListsScreen> {
  final _api = UnwantedApi();
  List<UnwantedListEntry>? _entries;
  bool _failed = false;

  static const _tabs = [
    UnwantedListKind.watchLater,
    UnwantedListKind.snoozed,
    UnwantedListKind.unwanted,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await _api.fetchLists(widget.baseUrl, widget.token);
      entries.sort(
        (a, b) => (b.added ?? DateTime(0)).compareTo(a.added ?? DateTime(0)),
      );
      if (mounted) {
        setState(() {
          _entries = entries;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _tabLabel(AppLocalizations l10n, UnwantedListKind kind) {
    switch (kind) {
      case UnwantedListKind.watchLater:
        return l10n.unwantedWatchLater;
      case UnwantedListKind.snoozed:
        return l10n.unwantedSnoozedList;
      case UnwantedListKind.unwanted:
        return l10n.unwantedNotInterested;
    }
  }

  IconData _tabIcon(UnwantedListKind kind) {
    switch (kind) {
      case UnwantedListKind.watchLater:
        return Icons.watch_later_outlined;
      case UnwantedListKind.snoozed:
        return Icons.snooze;
      case UnwantedListKind.unwanted:
        return Icons.thumb_down_outlined;
    }
  }

  String _emptyText(AppLocalizations l10n, UnwantedListKind kind) {
    switch (kind) {
      case UnwantedListKind.watchLater:
        return l10n.unwantedEmptyWatchLater;
      case UnwantedListKind.snoozed:
        return l10n.unwantedEmptySnoozed;
      case UnwantedListKind.unwanted:
        return l10n.unwantedEmptyUnwanted;
    }
  }

  Future<void> _takeOff(UnwantedListEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _entries = _entries!.where((e) => e != entry).toList());
    try {
      switch (entry.kind) {
        case UnwantedListKind.watchLater:
          await _api.setWatchLater(
            widget.baseUrl,
            widget.token,
            entry.itemId,
            false,
          );
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.unwantedWatchLaterRemoved(entry.name))),
          );
        case UnwantedListKind.snoozed:
          await _api.wake(widget.baseUrl, widget.token, entry.itemId);
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.unwantedWoken(entry.name))),
          );
        case UnwantedListKind.unwanted:
          await _api.setUnwanted(
            widget.baseUrl,
            widget.token,
            entry.itemId,
            false,
          );
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.unwantedRestored(entry.name))),
          );
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.unwantedError)));
      await _load();
    }
  }

  Future<void> _open(UnwantedListEntry entry) async {
    final item = Movie(
      id: entry.itemId,
      name: entry.name,
      type: entry.type ?? 'Series',
    );
    await openItemDetails(
      context,
      item,
      baseUrl: widget.baseUrl,
      token: widget.token,
      userId: widget.userId,
    );
    if (mounted) _load();
  }

  String _subtitle(BuildContext context, UnwantedListEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    final parts = <String>[
      if (entry.productionYear != null) '${entry.productionYear}',
      if (entry.kind == UnwantedListKind.snoozed)
        describeSnooze(
          context,
          until: entry.snoozeUntil,
          untilNewEpisode: entry.untilNewEpisode,
        )
      else if (entry.added != null)
        l10n.unwantedAddedOn(formatShortDate(context, entry.added!)),
    ];
    return parts.join(' · ');
  }

  Widget _buildList(BuildContext context, UnwantedListKind kind) {
    final l10n = AppLocalizations.of(context)!;
    final entries = (_entries ?? const <UnwantedListEntry>[])
        .where((e) => e.kind == kind)
        .toList();
    if (entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: MessageView(icon: _tabIcon(kind), title: _emptyText(l10n, kind)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: entries.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            onTap: () => _open(entry),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 44,
                height: 66,
                child: entry.hasPrimaryImage
                    ? CachedNetworkImage(
                        imageUrl:
                            '${widget.baseUrl}/Items/${entry.itemId}/Images/Primary?fillWidth=120&quality=80',
                        httpHeaders: jellyfinAuthHeaders(widget.token),
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _placeholder(entry),
                      )
                    : _placeholder(entry),
              ),
            ),
            title: Text(
              entry.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _subtitle(context, entry),
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: IconButton(
              tooltip: switch (kind) {
                UnwantedListKind.watchLater => l10n.unwantedRemoveWatchLater,
                UnwantedListKind.snoozed => l10n.unwantedWake,
                UnwantedListKind.unwanted => l10n.unwantedRestore,
              },
              icon: Icon(switch (kind) {
                UnwantedListKind.watchLater => Icons.bookmark_remove_outlined,
                UnwantedListKind.snoozed => Icons.alarm_on,
                UnwantedListKind.unwanted => Icons.undo,
              }),
              onPressed: () => _takeOff(entry),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder(UnwantedListEntry entry) => Container(
    color: Colors.grey[900],
    child: Icon(
      entry.type == 'Movie' ? Icons.movie_outlined : Icons.tv,
      color: Colors.white24,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _entries;
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.unwantedMyLists),
          bottom: TabBar(
            tabs: [
              for (final kind in _tabs)
                Tab(
                  icon: Icon(_tabIcon(kind)),
                  text: entries == null
                      ? _tabLabel(l10n, kind)
                      : '${_tabLabel(l10n, kind)} (${entries.where((e) => e.kind == kind).length})',
                ),
            ],
          ),
        ),
        body: _failed
            ? MessageView(
                icon: Icons.cloud_off,
                title: l10n.unwantedError,
                actionLabel: l10n.retry,
                onAction: () {
                  setState(() => _failed = false);
                  _load();
                },
              )
            : entries == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [for (final kind in _tabs) _buildList(context, kind)],
              ),
      ),
    );
  }
}
